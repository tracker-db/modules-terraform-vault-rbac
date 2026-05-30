# modules/vault-rbac/variables.tf

variable "roles" {
  description = "Role definitions from roles.tf"
  type = map(object({
    description = string
    grants = map(object({
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
