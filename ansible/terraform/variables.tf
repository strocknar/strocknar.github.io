variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

variable "gateway" {
  type = string
}

variable "dns_fallback" {
  type    = string
  default = "1.1.1.1"
}

variable "adguard_ip" { type = string }
variable "docker_ip"  { type = string }
variable "plex_ip"    { type = string }
variable "haos_ip"    { type = string }
variable "ollama_ip"  { type = string }

variable "phase" {
  type    = number
  default = 1
}

variable "igpu_pci_id" {
  type    = string
  default = "1002:1900"
}

variable "rtx3090_pci_id" {
  type    = string
  default = ""
}

variable "debian_template" {
  type    = string
  default = "local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst"
}
