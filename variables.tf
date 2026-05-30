# modules/vault-rbac/variables.tf
# Updated to accept the full role structure from v3

variable "roles" {
  description = "Role definitions from roles.tf"
  type = map(object({
    description  = string
    vault_admin  = optional(bool, false)
    secret_paths = optional(list(string), [])
    grants = map(object({
      type    = optional(string, "ssh")
      targets = list(string)
      access  = string
      ttl     = string
      max_ttl = string
    }))
  }))
}

variable "ssh_mount_path" {
  description = "Vault SSH secrets engine mount path"
  type        = string
  default     = "ssh-client-signer"
}
