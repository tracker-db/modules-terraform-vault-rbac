# modules-terraform-vault-rbac

Reusable Terraform module that converts role definitions into HashiCorp Vault SSH CA roles and policies.

## Usage

```hcl
module "vault_rbac" {
  source = "git::https://github.com/tracker-db/modules-terraform-vault-rbac.git?ref=v1.0.0"

  roles          = local.roles
  ssh_mount_path = "ssh-client-signer"
}
```

## Inputs

| Name | Type | Description |
|---|---|---|
| `roles` | `map(object)` | Role definitions: role_name → { description, grants } |
| `ssh_mount_path` | `string` | Vault SSH secrets engine mount path (default: `ssh-client-signer`) |

### Role object structure

```hcl
roles = {
  "platform-admin" = {
    description = "Full admin access"
    grants = {
      "utility-servers" = {
        targets = ["vm-1.lab.internal", "vm-2.lab.internal"]
        access  = "admin"   # admin = root+deploy | read = deploy only
        ttl     = "8h"
        max_ttl = "24h"
      }
    }
  }
}
```

## Outputs

| Name | Description |
|---|---|
| `role_policy_names` | Map of role_name → [vault_policy_names] |
| `role_resource_map` | Map of role_name → resources it grants |
| `ssh_ca_role_names` | All SSH CA role names created |
| `principals_by_resource` | Map of resource → targets + access level |

## What it creates in Vault

For each **unique resource** across all roles:
- One `vault_ssh_secret_backend_role` (SSH CA signing role)

For each **role**:
- One `vault_policy` granting access to that role's resources

## Versioning

Tag releases. Consuming repos pin to tags:

```bash
git tag v1.0.0
git push origin v1.0.0
```
