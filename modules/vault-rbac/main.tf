# modules/vault-rbac/main.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Vault RBAC Module
#
# Input:  roles map from roles.tf
# Output: Vault SSH CA roles + policies
#
# For each ROLE, this module creates:
#   1. One Vault SSH CA role per unique RESOURCE in the role's grants
#   2. One Vault policy per ROLE that bundles access to its resources
#
# The SSH CA roles are deduplicated — if two roles both grant access
# to "utility-servers", only one SSH CA role is created. The policy
# for each role just references the shared SSH CA role.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  # Access level → SSH user mapping
  access_config = {
    admin = {
      allowed_users      = "root,deploy"
      default_user       = "root"
      allowed_extensions = "permit-pty,permit-port-forwarding,permit-agent-forwarding"
    }
    read = {
      allowed_users      = "deploy"
      default_user       = "deploy"
      allowed_extensions = "permit-pty"
    }
  }

  # ── Step 1: Flatten all grants across all roles into unique resources ──
  # A resource like "utility-servers" may appear in multiple roles
  # with different access levels. We take the HIGHEST access level
  # (admin > read) for the SSH CA role, since the POLICY controls
  # who can actually use it.
  #
  # Intermediate: list of {resource, access, ttl, max_ttl} per grant
  all_grants_flat = flatten([
    for role_name, role in var.roles : [
      for resource_name, grant in role.grants : {
        resource_name = resource_name
        access        = grant.access
        ttl           = grant.ttl
        max_ttl       = grant.max_ttl
        targets       = grant.targets
      }
    ]
  ])

  # Deduplicate: one SSH CA role per resource
  # If multiple roles reference the same resource with different access,
  # the CA role allows BOTH users (admin includes read).
  # The policy narrows it down.
  unique_resources = {
    for grant in local.all_grants_flat : grant.resource_name => grant...
  }

  # For each unique resource, determine the CA role config
  # Use the most permissive access level (admin trumps read)
  ssh_ca_roles = {
    for resource_name, grants in local.unique_resources : resource_name => {
      # If ANY role grants admin to this resource, the CA role allows admin users
      access  = contains([for g in grants : g.access], "admin") ? "admin" : "read"
      ttl     = grants[0].ttl
      max_ttl = grants[0].max_ttl
      targets = distinct(flatten([for g in grants : g.targets]))
    }
  }

  # ── Step 2: Build per-role policy HCL ──
  role_policies = {
    for role_name, role in var.roles : role_name => join("\n\n", concat(
      [
        # Header comment
        "# Policy for role: ${role_name}",
        "# ${role.description}",
        "",
        # Self-service token operations
        <<-EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "${var.ssh_mount_path}/config/ca" {
  capabilities = ["read"]
}
        EOT
      ],
      [
        for resource_name, grant in role.grants :
        <<-EOT
# Access: ${resource_name} (${grant.access})
path "${var.ssh_mount_path}/sign/ssh-${resource_name}" {
  capabilities = ["create", "update"]
}
        EOT
      ]
    ))
  }
}

# ──────────────────────────────────────────────
# Vault SSH CA Roles — one per unique resource
# ──────────────────────────────────────────────

resource "vault_ssh_secret_backend_role" "resources" {
  for_each = local.ssh_ca_roles

  backend  = var.ssh_mount_path
  name     = "ssh-${each.key}"
  key_type = "ca"

  allow_user_certificates = true
  allowed_users           = local.access_config[each.value.access].allowed_users
  default_user            = local.access_config[each.value.access].default_user
  allowed_extensions      = local.access_config[each.value.access].allowed_extensions
  ttl                = each.value.ttl
  max_ttl            = each.value.max_ttl

  default_extensions = {
    permit-pty = ""
  }

  algorithm_signer = "rsa-sha2-256"
}

# ──────────────────────────────────────────────
# Vault Policies — one per role
# ──────────────────────────────────────────────

resource "vault_policy" "roles" {
  for_each = local.role_policies

  name   = "ssh-role-${each.key}"
  policy = each.value
}
