# 02 — Proxmox Installation

[← Hardware Assembly](01-hardware-assembly.md) | [Next: Home Assistant VM →](03-home-assistant-vm.md)

---

## Why Proxmox

Proxmox VE is a bare-metal hypervisor based on Debian. It runs Home Assistant OS as a proper VM (better than HA Supervised), passes the RX 7900 XTX through to the Ollama VM via VFIO, and manages Docker LXCs for homelab services — all from a single web UI.

---

## 2.1 Create a Bootable Proxmox USB

On another machine:

1. Download Proxmox VE ISO from `proxmox.com/downloads` (current version: 9.2-1)
2. Flash to USB drive using Balena Etcher or `dd`:

```bash
# macOS/Linux — replace /dev/sdX with your USB device
dd if=proxmox-ve_9.2-1.iso of=/dev/sdX bs=1M status=progress
```

---

## 2.2 Install Proxmox

1. Boot the UM890 Pro from the USB drive (tap `F7` or `F11` for boot menu on POST)
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

In the Proxmox web UI: **<NodeName> → Shell**

```bash
# Disable enterprise repo
echo "Enabled: false" >> /etc/apt/sources.list.d/ceph.sources
echo "Enabled: false" >> /etc/apt/sources.list.d/pve-enterprise.sources

sed -i '/Enabled/c\Enabled: false' /etc/apt/sources.list.d/ceph.sources

# Add no-subscription repo
cat << EOF > /etc/apt/sources.list.d/ceph-no-subscription.sources
Types: deb
URIs: http://proxmox.com
Suites: trixie
Components: no-subscription
Signed-By: /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg
EOF

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
```

### Bind iGPU to VFIO (Phase 1)

This reserves the 780M iGPU exclusively for the Ollama VM via passthrough. First, identify your iGPU's PCI IDs:

```bash
lspci -nn | grep -i amd
```

Look for the entry with "Hawk Point" or "Radeon 780M" — note the IDs in brackets. Standard IDs are `1002:1900` (video) and `1002:1640` (audio), but confirm yours match.

Create the targeted VFIO binding:

```bash
nano /etc/modprobe.d/vfio.conf
```

```
options vfio-pci ids=1002:1900,1002:1640
```

> Use the IDs from `lspci -nn`. This binds only the iGPU to VFIO. In Phase 2, you will replace these IDs with the RTX 3090's IDs — see [eGPU Setup](07-egpu-setup.md).

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
done | grep -E "AMD|NVIDIA" | sort -V
```

Note the PCI IDs for the 780M iGPU (format: `xxxx:xxxx`). Confirm they match what you put in `vfio.conf`.

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
