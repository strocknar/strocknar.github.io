variable "ubuntu_cloud_image" {
  type    = string
  default = "local:0/ubuntu-24.04-minimal-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_vm" "ollama" {
  node_name = var.proxmox_node
  vm_id     = 101
  name      = "ollama"

  machine    = "q35"
  boot_order = ["scsi0"]
  on_boot    = true

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    interface    = "scsi0"
    size         = 60
    datastore_id = "local-lvm"
    import_from  = var.ubuntu_cloud_image
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ollama_ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.adguard_ip]
    }

    user_account {
      username = "ubuntu"
      keys     = []
    }
  }

  # Phase 1: iGPU passthrough; Phase 2: RTX 3090
  dynamic "hostpci" {
    for_each = var.phase == 1 ? [var.igpu_pci_id] : (var.phase == 2 ? [var.rtx3090_pci_id] : [])
    content {
      device = "hostpci0"
      id     = hostpci.value
      pcie   = true
      rombar = true
    }
  }

  operating_system {
    type = "l26"
  }
}
