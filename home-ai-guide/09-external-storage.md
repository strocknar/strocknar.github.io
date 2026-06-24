# 09 — External Storage (USB SSDs)

[← Tailscale](08-tailscale-remote-access.md) | [Next: Web Search →](10-web-search.md)

---

## Use Cases

| Drive | Contents | Passed to |
|---|---|---|
| External SSD 1 (2TB) | Ollama model weights | Ollama VM |
| External SSD 2 (2TB) | Plex media library | Plex LXC |

Internal 1TB NVMe stays clean: Proxmox OS + all VM/LXC system disks only.

---

## 9.1 Format External Drives

Connect both SSDs to the UM890 Pro's USB ports. In the Proxmox shell:

```bash
# List connected drives
lsblk

# Identify your external SSDs (e.g., /dev/sdb, /dev/sdc)
# WARNING: confirm the correct device before formatting

# Format drive 1 (models)
mkfs.ext4 -L models /dev/sdb

# Format drive 2 (media)
mkfs.ext4 -L media /dev/sdc
```

---

## 9.2 Get Drive UUIDs

Use UUIDs rather than device names (`/dev/sdb`) — device names can change between reboots, UUIDs never do:

```bash
blkid /dev/sdb
blkid /dev/sdc
```

Note the UUID for each drive.

---

## 9.3 Mount on Proxmox Host

```bash
mkdir -p /mnt/models /mnt/media

nano /etc/fstab
```

Add:

```
UUID=<models-drive-uuid>  /mnt/models  ext4  defaults,nofail  0  2
UUID=<media-drive-uuid>   /mnt/media   ext4  defaults,nofail  0  2
```

> `nofail` is critical — without it, Proxmox will fail to boot if a drive isn't connected.

Mount immediately without rebooting:

```bash
mount -a
```

Verify:

```bash
df -h | grep mnt
```

---

## 9.4 Pass Models Drive to Ollama VM

In Proxmox web UI — shut down the Ollama VM, then:

**VM 101 → Hardware → Add → Directory**

Or use bind mount via config file (more reliable):

```bash
# On Proxmox host
nano /etc/pve/qemu-server/101.conf
```

Add a VirtIO disk pointing to the external drive:

```bash
# Alternatively, add as a bind mount in the VM via virtiofs
# Simplest method: add as a second disk
qm set 101 -virtio1 /mnt/models,format=raw,size=2T
```

> The simplest approach is to mount the external drive inside the Ollama VM directly by passing the USB device through. In Proxmox web UI: **VM 101 → Hardware → Add → USB Device** → select the USB SSD by vendor/device ID.

Inside the Ollama VM, mount it:

```bash
# In Ollama VM
sudo mkdir -p /mnt/models
sudo mount /dev/sdb /mnt/models  # device name may differ — use lsblk

# Add to /etc/fstab in the VM
echo "UUID=<uuid>  /mnt/models  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
```

Configure Ollama to store models on the external drive:

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_MODELS=/mnt/models"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 9.5 Pass Media Drive to Plex LXC

In Proxmox host shell:

```bash
nano /etc/pve/lxc/201.conf
```

Add:

```
mp0: /mnt/media,mp=/media,backup=0
```

This bind-mounts `/mnt/media` on the Proxmox host into `/media` inside the Plex LXC.

Restart the Plex LXC. In Plex, add `/media` as a library location.

---

## 9.6 Handling Drive Disconnects

USB drives can disconnect unexpectedly. Configure graceful handling:

**Ollama:** If the models drive disconnects, Ollama will error on the next inference. It recovers automatically when the drive reconnects and Ollama restarts. Keep at least one small model (7B) on the internal NVMe as a fallback:

```bash
# In Ollama VM — store one model internally as fallback
OLLAMA_MODELS=~/.ollama/models ollama pull qwen3:8b-q4_K_M
```

**Plex:** Plex handles missing media directories gracefully — it just shows those items as unavailable until the drive reconnects.

---

## 9.7 Future Internal NVMe Expansion

When storage prices normalize, replacing external SSDs with internal NVMe drives is straightforward:

1. The UM890 Pro has 1 empty NVMe slot (2 slots total, 1 used for the OS drive)
2. Install new NVMe, copy data from external SSD, update fstab paths
3. External SSDs become portable backup drives

This is the natural upgrade path — no reinstallation required.

---

[← Tailscale](08-tailscale-remote-access.md) | [Next: Web Search →](10-web-search.md)
