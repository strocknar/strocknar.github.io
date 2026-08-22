---
---
# 07 — Samba Network Shares

[← Plex LXC](06-plex-lxc.md) | [Next: Home Assistant VM →](08-home-assistant-vm.md)

---

{% include guide-toc.html toc=site.data.guide-toc %}

A dedicated LXC for SMB network shares gives you read/write access to your media from any device on the LAN — Windows, macOS, or Linux. Keeping Samba in its own container means adding future shares is just a new bind mount and a new config stanza, with no impact on Plex or other services.

> **Prerequisite:** The media drive must be mounted on the Proxmox host at `/mnt/media` before continuing. See [External Storage](03-external-storage.md).

---

## 7.1 Create Samba LXC (CT 203)

In Proxmox web UI: **Create CT**

| Setting | Value |
|---|---|
| CT ID | `203` |
| Hostname | `samba` |
| Unprivileged container | **Uncheck this box** — required for bind mounts with correct permissions |
| Template | Debian 13 |
| Disk | `8GB` |
| CPU | `1 core` |
| RAM | `512` MB |
| Network — Bridge | `vmbr0` |
| Network — IPv4 | Static, `<samba-lxc-ip>/24` |
| Network — Gateway | Your router IP |
| DNS tab — DNS server | `<adguard-lxc-ip>` |
| Start at boot | ✅ Yes |

Start the LXC.

> **Debian 13 / systemd 257:** If you see `WARN: Systemd 257 detected. You may need to enable nesting`, run this on the Proxmox host and restart the container:
> ```bash
> pct set 203 --features nesting=1
> ```

---

## 7.2 Bind-Mount the Media Drive

Shut down the Samba LXC. On the Proxmox host shell:

```bash
vim /etc/pve/lxc/203.conf
```

Add:

```
mp0: /mnt/media,mp=/media,backup=0
```

Start the LXC. Verify the mount:

```bash
# Inside the Samba LXC console
ls /media
# Your media files should be visible here
```

---

## 7.3 Install Samba

In the Samba LXC console:

```bash
apt update && apt install -y samba
```

---

## 7.4 Configure Samba

```bash
vim /etc/samba/smb.conf
```

Replace the entire file contents with:

```ini
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   log file = /var/log/samba/log.%m
   max log size = 50
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   hosts allow = 192.168.0.0/16 127.0.0.1
   hosts deny = ALL

[media]
   path = /media
   comment = Plex Media Library
   browseable = yes
   writable = yes
   valid users = mediauser
   create mask = 0664
   directory mask = 0775
   force group = mediauser
```

> Replace `192.168.0.0/16` with your actual LAN subnet (e.g. `192.168.50.0/24`). The `hosts allow` line restricts access to your LAN — the share is not reachable from outside.

---

## 7.5 Create Samba User

```bash
# Create a system user (no login shell needed)
useradd -M -s /usr/sbin/nologin mediauser

# Set the Samba password (separate from the system password)
smbpasswd -a mediauser
```

Enter a password when prompted. This is the password you will use when connecting from your laptop.

> **NTFS drives:** `chown` is a no-op on NTFS — filesystem permissions are set entirely by the fstab mount options on the Proxmox host. Write access requires `umask=0000` in the fstab entry (see [External Storage §3.0](03-external-storage.md)). If you can authenticate but not write, the mount options are the cause — not Samba configuration.

---

## 7.6 Enable and Start Samba

```bash
systemctl enable --now smbd nmbd
```

Verify both are running:

```bash
systemctl status smbd nmbd
```

---

## 7.7 Connect from Another Device

**macOS (Finder):**
1. Finder → Go → Connect to Server (⌘K)
2. Enter: `smb://<samba-lxc-ip>/media`
3. Authenticate with username `mediauser` and the password set in 7.5

**Windows (Explorer):**
1. Open File Explorer
2. In the address bar enter: `\\<samba-lxc-ip>\media`
3. Authenticate with username `mediauser` and the password set in 7.5

**Linux:**
```bash
# Mount temporarily
sudo mount -t cifs //<samba-lxc-ip>/media /mnt/media -o username=mediauser

# Or open in file manager: smb://<samba-lxc-ip>/media
```

---

## 7.8 Adding Future Shares

To expose a new directory as a share:

1. Add a bind mount in `/etc/pve/lxc/203.conf` (e.g. `mp1: /mnt/backups,mp=/backups,backup=0`) — requires LXC restart
2. Add a new stanza to `/etc/samba/smb.conf` following the same pattern as `[media]`
3. Restart Samba: `systemctl restart smbd`

---

[← Plex LXC](06-plex-lxc.md) | [Next: Home Assistant VM →](08-home-assistant-vm.md)
