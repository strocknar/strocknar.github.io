resource "proxmox_virtual_environment_container" "adguard" {
  node_name   = var.proxmox_node
  vm_id       = 202
  description = "AdGuard Home — split-horizon DNS"

  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "adguard"

    ip_config {
      ipv4 {
        address = "${var.adguard_ip}/${var.subnet_mask}"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_fallback]
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }
}
