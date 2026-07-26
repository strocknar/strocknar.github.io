variable "haos_image" {
  type    = string
  default = "local:0/haos_ova-14.2.qcow2"
}

resource "proxmox_virtual_environment_vm" "haos" {
  node_name = var.proxmox_node
  vm_id     = 100
  name      = "haos"

  machine    = "q35"
  boot_order = ["scsi0"]
  on_boot    = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    interface    = "scsi0"
    file_id      = var.haos_image
    size         = 32
    datastore_id = "local-lvm"
    import_from  = var.haos_image
  }

  operating_system {
    type = "l26"
  }
}
