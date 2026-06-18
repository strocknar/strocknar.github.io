# 02 — Proxmox Installation

[← Hardware Assembly](01-hardware-assembly.md) | [Next: Home Assistant VM →](03-home-assistant-vm.md)

---

## Why Proxmox

Proxmox VE is a bare-metal hypervisor based on Debian. It runs Home Assistant OS as a proper VM (better than HA Supervised), passes the RX 7900 XTX through to the Ollama VM via VFIO, and manages Docker LXCs for homelab services — all from a single web UI.

---

## 2.1 Create a Bootable Proxmox USB

On another machine:

1. Download Proxmox VE ISO from `proxmox.com/downloads` (current version: 8.x)
2. Flash to USB drive using Balena Etcher or `dd`:

```bash
# macOS/Linux — replace /dev/sdX with your USB device
dd if=proxmox-ve_8.x-1.iso of=/dev/sdX bs=1M status=progress
```

---

## 2.2 Install Proxmox

1. Boot the AI X1 Pro-470 from the USB drive (tap `F7` or `F11` for boot menu on POST)
2. Select **Install Proxmox VE (Graphical)**
3. Accept the EULA
4. **Target disk:** Select the WD Black SN770 1TB
5. **Location and timezone:** Set your timezone
6. **Password:** Set a strong root password — this is your hypervisor admin account
7. **Network configuration:**
   - Select the primary 2.5 GbE NIC (typically `enp2s0` or similar)
   - Set a static IP on your LAN (e.g., `192.168.1.10/24`)
   - Set your router as the gateway
   - Set a DNS server (your router IP, or `1.1.1.1`)
   - Set a hostname: e.g., `proxmox.home.arpa`
8. Review summary and click **Install**
9. Remove USB when prompted, system reboots

---

## 2.3 First Login

From any browser on your network:

```
https://192.168.1.10:8006
```

Accept the self-signed certificate warning. Login as `root` with the password you set.

---

## 2.4 Remove Enterprise Repository (No Subscription)

Proxmox defaults to an enterprise repo that requires a paid subscription. Switch to the free repo:

In the Proxmox web UI: **Node → Shell**

```bash
# Disable enterprise repo
echo "# disabled" > /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update && apt full-upgrade -y
```

Reboot after upgrade:

```bash
reboot
```

---

## 2.5 Configure IOMMU for GPU Passthrough

This enables PCIe device passthrough to VMs — required for the RX 7900 XTX to be passed to the Ollama VM.

### Edit GRUB

```bash
nano /etc/default/grub
```

Find the line:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```

Change to:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Save and update GRUB:

```bash
update-grub
```

### Load VFIO Modules

```bash
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules
```

### Blacklist AMD GPU from Host

This prevents Proxmox from claiming the RX 7900 XTX, leaving it available for VM passthrough:

```bash
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
```

> **Important:** Do NOT blacklist amdgpu if you want the 890M iGPU available on the host for Plex transcoding LXC. The blacklist here targets the external 7900 XTX only. See [eGPU Setup](07-egpu-setup.md) for the correct targeted approach using device IDs.

### Update initramfs and Reboot

```bash
update-initramfs -u -k all
reboot
```

---

## 2.6 Verify IOMMU

After reboot, in the Proxmox shell:

```bash
dmesg | grep -e DMAR -e IOMMU
```

Look for: `AMD-Vi: AMD IOMMUv2 loaded and initialized`

Check IOMMU groups:

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done | grep -i amd | sort -V
```

Note the PCI IDs for the RX 7900 XTX (format: `xxxx:xxxx`). You'll need these in [eGPU Setup](07-egpu-setup.md).

---

## 2.7 Configure Storage

In the Proxmox web UI:

**Datacenter → Storage → local-lvm**

By default Proxmox splits the disk into `local` (ISOs, backups) and `local-lvm` (VM disks). The defaults are fine for a single-disk setup.

To add external USB SSDs later, see [External Storage](09-external-storage.md).

---

## 2.8 Disable Suspend/Sleep

Since this runs 24/7 for Home Assistant:

```bash
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

---

## 2.9 (Optional) Configure a Second NIC for IoT VLAN

If you want network isolation for IoT devices (recommended for Home Assistant security):

- Assign the second 2.5 GbE port to a separate Linux bridge in Proxmox
- Proxmox web UI: **Node → Network → Create → Linux Bridge**
- Name it `vmbr1`, assign to the second NIC
- Attach the HA VM to `vmbr1` for IoT traffic and `vmbr0` for management

This is optional — skip if your router handles VLAN segmentation.

---

## Quick Reference

| Item | Value |
|---|---|
| Proxmox web UI | `https://<your-ip>:8006` |
| Default login | `root` + password you set |
| Shell access | Web UI → Node → Shell |

---

[← Hardware Assembly](01-hardware-assembly.md) | [Next: Home Assistant VM →](03-home-assistant-vm.md)
