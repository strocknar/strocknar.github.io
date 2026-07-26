resource "proxmox_virtual_environment_container" "plex" {
  node_name   = var.proxmox_node
  vm_id       = 201
  description = "Plex Media Server"

  unprivileged  = false
  start_on_boot = true

  features {
    nesting = true
  }

  initialization {
    hostname = "plex"

    ip_config {
      ipv4 {
        address = "${var.plex_ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.adguard_ip]
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  dynamic "device" {
    for_each = var.phase == 2 ? [1] : []
    content {
      host_path    = "/dev/dri"
      mount_point  = "dev/dri"
      is_read_only = false
    }
  }
}
