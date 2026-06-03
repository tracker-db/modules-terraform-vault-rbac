terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
}

variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "http://127.0.0.1:8200"
}

locals {
  roles = {
    "platform-admin" = {
      description = "Full lab access"
      grants = {
        "bastion" = {
          targets = ["bastion.example.com:22"]
          access  = "admin"
          ttl     = "8h"
          max_ttl = "24h"
        }
      }
    }
  }
}

module "vault_rbac" {
  source = "../../modules/vault-rbac"

  roles          = local.roles
  ssh_mount_path = "ssh-client-signer"
}

output "role_policies" {
  value = module.vault_rbac.role_policy_names
}
