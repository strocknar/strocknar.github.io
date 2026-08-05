---
---
# 09 — External Storage (USB SSDs)

[← Tailscale](08-tailscale-remote-access.md) | [Next: Web Search →](10-web-search.md)

---

{% include guide-toc.html %}

## Use Cases

| Drive | Contents | Passed to |
|---|---|---|
| External SSD 1 (2TB) | Ollama model weights | Ollama VM |
| External SSD 2 (2TB) | Plex media library | Plex LXC |

Internal 1TB NVMe stays clean: Proxmox OS + all VM/LXC system disks only.

---

## 9.0 Adding a Drive That Already Has Data

If your media drive is already formatted and populated — from a previous Plex install, a NAS, or another machine — **skip section 9.1 entirely**. Formatting destroys all existing data.

### Step 1 — Identify the Drive

Connect the drive. On the Proxmox host shell:

```bash
lsblk -f
```

Find the drive by size. The `FSTYPE` column shows the existing filesystem. Note the device name (e.g., `/dev/sdc`).

**Filesystem compatibility:**

| Filesystem | Status | Notes |
|---|---|---|
| `ext4` | Native | Best option — no extra packages needed |
| `exFAT` | Supported | Install `exfatprogs` first |
| `NTFS` | Supported | Install `ntfs-3g` first; write performance is slower |
| `HFS+` / `APFS` | Read-only | Linux has no full write support without commercial drivers — convert to ext4 first |

If your drive is HFS+/APFS (came from a Mac), the safest path is to copy the media off it, reformat as ext4, and copy it back before proceeding.

### Step 2 — Install Filesystem Driver (if needed)

```bash
# For exFAT drives
apt install -y exfatprogs

# For NTFS drives
apt install -y ntfs-3g
```

Skip this if the drive is already ext4.

### Step 3 — Get the UUID

```bash
blkid /dev/sdX   # substitute your actual device name
```

Note the UUID and FSTYPE. Always use UUIDs in fstab — device names like `/dev/sdc` can shift on reboot if drive order changes.

### Step 4 — Mount on Proxmox Host

```bash
mkdir -p /mnt/media
vim /etc/fstab
```

Add the appropriate line for your filesystem:

```
# ext4
UUID=<uuid>  /mnt/media  ext4  defaults,nofail  0  2

# exFAT
UUID=<uuid>  /mnt/media  exfat  defaults,nofail,uid=0,gid=0,umask=0022  0  0

# NTFS
UUID=<uuid>  /mnt/media  ntfs-3g  defaults,nofail,uid=0,gid=0,umask=0022  0  0
```

> `nofail` is critical — without it, Proxmox will fail to boot if the drive isn't connected.

```bash
mount -a
ls /mnt/media   # your media files should be visible here
```

### Step 5 — Fix File Ownership (ext4 only)

This is the most common silent failure when moving a drive between Linux systems. Plex in the LXC runs as user `plex` (uid `1000`). If the files were owned by a different uid on the old system, Plex will silently fail to read them.

```bash
ls -lan /mnt/media | head -20
```

If the uid shown is not `1000`, fix it — this takes a while on a large library:

```bash
chown -R 1000:1000 /mnt/media
```

For exFAT and NTFS drives, ownership is controlled by mount options, not file metadata. Use `uid=1000,gid=1000` in the fstab entry instead of running `chown`.

### Step 6 — Pass to Plex LXC and Add Library

Follow **section 9.5** to bind-mount `/mnt/media` into the Plex LXC, then add `/media` as a library location in the Plex web UI. Plex will scan and match your existing files against its metadata database — it does not move or re-download anything.

> **Tip:** Plex matching works best with standard naming: `Movie Title (Year)/Movie Title (Year).mkv` and `Show Name/Season XX/Show Name - SXXEXX - Title.mkv`. If the library came from a working Plex install, the filenames are presumably already correct.

### Optional — Migrate Plex Database

If the drive came from an existing Plex Media Server and you want to preserve watch history, ratings, and playlists, copy the Plex data directory from the old machine:

```bash
# On the old machine — find the Plex data directory
# Linux/LXC: /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/
# Copy it to the new Plex LXC at the same path
```

Without this, Plex re-scans the files and fetches metadata fresh — your media is all there, but watch history and custom artwork are lost.

---

## 9.1 Format External Drives (New Drives Only)

> **Skip this section if your drive already has data.** See section 9.0 above.

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

vim /etc/fstab
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
vim /etc/pve/qemu-server/101.conf
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
vim /etc/pve/lxc/201.conf
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
