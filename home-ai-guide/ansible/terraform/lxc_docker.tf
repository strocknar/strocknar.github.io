resource "proxmox_virtual_environment_container" "docker" {
  node_name   = var.proxmox_node
  vm_id       = 200
  description = "Docker host — Portainer, NPM, Grafana, Prometheus, SearXNG"

  unprivileged  = false
  start_on_boot = true

  features {
    nesting = true
  }

  initialization {
    hostname = "docker"

    ip_config {
      ipv4 {
        address = "${var.docker_ip}/${var.subnet_mask}"
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
    dedicated = 6144
  }

  disk {
    datastore_id = "local-lvm"
    size         = 40
  }

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }
}
