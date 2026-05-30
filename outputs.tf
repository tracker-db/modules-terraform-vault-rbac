# modules/vault-rbac/outputs.tf

output "role_policy_names" {
  description = "Map of role_name → [policy_name]. Used by main.tf to assign policies to users."
  value = {
    for role_name, policy in vault_policy.roles :
    role_name => [policy.name]
  }
}

output "role_resource_map" {
  description = "Map of role_name → resources it grants access to"
  value = {
    for role_name, role in var.roles :
    role_name => {
      description = role.description
      resources = {
        for resource_name, grant in role.grants :
        resource_name => {
          access  = grant.access
          targets = grant.targets
          ttl     = grant.ttl
        }
      }
    }
  }
}

output "ssh_ca_role_names" {
  description = "All SSH CA role names created in Vault"
  value       = [for name, role in vault_ssh_secret_backend_role.resources : role.name]
}

output "principals_by_resource" {
  description = "Map of resource → targets, used to generate principals.d files"
  value = {
    for resource_name, config in local.ssh_ca_roles :
    resource_name => {
      targets = config.targets
      access  = config.access
    }
  }
}
