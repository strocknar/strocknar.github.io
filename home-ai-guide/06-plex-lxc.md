---
---
# 06 — Plex LXC

[← Nginx Proxy Manager](05-nginx-proxy-manager.md) | [Next: Samba →](07-samba.md)

---

{% include guide-toc.html %}

> **Prerequisite:** The media drive must be mounted on the Proxmox host before continuing. See [External Storage](03-external-storage.md).

---

## 6.1 Create Plex LXC (CT 201)

Same process as the Docker LXC but:

| Setting | Value |
|---|---|
| CT ID | `201` |
| Hostname | `plex` |
| RAM | `2048` MB |
| Disk | `20GB` (media stored on external SSD — see [External Storage](03-external-storage.md)) |
| Privileged | ✅ Yes |
| Start at boot | ✅ Yes |

---

## 6.2 Pass 780M iGPU to Plex LXC

> **Phase 1 note:** In Phase 1, the 780M iGPU is passed through to the Ollama VM. The `/dev/dri/` device will not be present on the host until Phase 2 (when the RTX 3090 replaces the iGPU in VFIO binding). Skip the hardware transcoding setup for now and configure it after completing [eGPU Setup](07-egpu-setup.md).

In Proxmox host shell:

```bash
ls /dev/dri/
# Note the renderD128 and card0/card1 device names
```

Edit the Plex LXC config:

```bash
vim /etc/pve/lxc/201.conf
```

Add:

```
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

---

## 6.3 Install Plex

In the Plex LXC console:

```bash
# In Plex LXC console
apt-get install -y curl

# Add the Plex repository
# Note: Plex's signing key uses a SHA1 self-signature that Debian Trixie's
# OpenPGP verifier (sqv) rejects since 2026-02-01. Use [trusted=yes] to
# skip signature verification — the package still comes over HTTPS.
echo "deb [trusted=yes] https://downloads.plex.tv/repo/deb public main" \
  | tee /etc/apt/sources.list.d/plexmediaserver.list

apt-get update && apt-get install -y plexmediaserver
systemctl enable --now plexmediaserver
```

Access: `http://<plex-lxc-ip>:32400/web`

---

## 6.4 Pass Media Drive to Plex LXC

In Proxmox host shell:

```bash
vim /etc/pve/lxc/201.conf
```

Add:

```
mp0: /mnt/media,mp=/media,backup=0
```

This bind-mounts `/mnt/media` on the Proxmox host into `/media` inside the Plex LXC.

Restart the Plex LXC.

---

## 6.5 Fix File Ownership (ext4 only)

This is the most common silent failure when moving a drive between Linux systems. Plex in the LXC runs as user `plex` (uid `1000`). If the files were owned by a different uid on the old system, Plex will silently fail to read them.

```bash
ls -lan /mnt/media | head -20
```

If the uid shown is not `1000`, fix it — this takes a while on a large library:

```bash
chown -R 1000:1000 /mnt/media
```

For exFAT and NTFS drives, ownership is controlled by mount options, not file metadata. Use `uid=1000,gid=1000` in the fstab entry instead of running `chown`.

---

## 6.6 Add Library in Plex Web UI

In the Plex web UI, add `/media` as a library location. Plex will scan and match your existing files against its metadata database — it does not move or re-download anything.

> **Tip:** Plex matching works best with standard naming: `Movie Title (Year)/Movie Title (Year).mkv` and `Show Name/Season XX/Show Name - SXXEXX - Title.mkv`. If the library came from a working Plex install, the filenames are presumably already correct.

---

## 6.7 Migrate Plex Database (Optional)

If the drive came from an existing Plex Media Server and you want to preserve watch history, ratings, and playlists, copy the Plex data directory from the old machine:

```bash
# On the old machine — find the Plex data directory
# Linux/LXC: /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/
# Copy it to the new Plex LXC at the same path
```

Without this, Plex re-scans the files and fetches metadata fresh — your media is all there, but watch history and custom artwork are lost.

---

## 6.8 Drive Disconnect Behavior

**Plex:** Plex handles missing media directories gracefully — it just shows those items as unavailable until the drive reconnects.

---

[← Nginx Proxy Manager](05-nginx-proxy-manager.md) | [Next: Samba →](07-samba.md)
