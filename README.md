# modules-terraform-vault-rbac

Reusable Terraform module that converts role definitions into HashiCorp Vault SSH CA roles and policies.

## Module location

```
modules/vault-rbac/   — source for all consumers
examples/basic/       — working usage example
```

## Usage

```hcl
module "vault_rbac" {
  source = "git::https://github.com/tracker-db/modules-terraform-vault-rbac.git//modules/vault-rbac?ref=<SHA>"

  roles          = local.roles
  ssh_mount_path = "ssh-client-signer"
}
```

Pin `ref` to a full commit SHA after each merge. Never use a branch name as `ref` in production.

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
      "bastion" = {
        targets = ["bastion.lab.internal:22"]
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

Tag releases with a semver tag. Consuming repos pin to the merge commit SHA:

```bash
git tag v2.1.0
git push origin v2.1.0
```
