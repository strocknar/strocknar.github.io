# 03 — Home Assistant VM

[← Proxmox Installation](02-proxmox-installation.md) | [Next: Ollama + Open WebUI →](04-ollama-open-webui.md)

---

## Why HA OS in a VM (Not Supervised)

Running Home Assistant OS in a Proxmox VM is the **officially supported** path recommended by the Home Assistant team. You get:

- Full Supervisor (add-on store, automated backups, OTA updates)
- Clean isolation from other services
- Snapshot/rollback via Proxmox if an update breaks something
- Better than HA Supervised on bare Debian

---

## 3.1 Install via Official Script

The Home Assistant team maintains an official Proxmox installation script. In the Proxmox shell:

```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/vm/haos-vm.sh)"
```

> If this script returns a 404, check `https://github.com/community-scripts/ProxmoxVE` for the current script path — filenames occasionally change between releases.

This script is maintained by the community and is the standard method used by thousands of homelab users. It creates the VM with correct settings automatically.

Follow the prompts:
- **VM ID:** Accept default (e.g., `100`)
- **Machine type:** `q35` (required for PCIe passthrough compatibility)
- **HA OS version:** Select latest stable
- **RAM:** `4096` MB (4GB)
- **CPU cores:** `2`
- **Disk size:** `32GB`
- **Bridge:** `vmbr0` (or `vmbr1` if you set up IoT VLAN)

The script downloads the HA OS image, creates the VM, and starts it.

---

## 3.2 First Boot

In Proxmox web UI, select the HA VM → **Console**.

Wait 3–5 minutes for first boot. HA OS will show its IP address on the console. From a browser:

```
http://<haos-ip>:8123
```

Complete the Home Assistant onboarding wizard:
- Create your admin account
- Set your home location
- Skip device discovery for now

---

## 3.3 Configure Static IP for HA VM

In HA web UI: **Settings → System → Network**

Set a static IP on the same subnet as Proxmox (e.g., `192.168.1.11`). Restart HA when prompted.

Update your router's DHCP reservations to lock this IP to the HA VM's MAC address for consistency.

---

## 3.4 Pass Through USB Devices (Zigbee/Z-Wave Dongles)

If you use a Zigbee coordinator (e.g., Sonoff Zigbee 3.0 USB) or Z-Wave stick, pass it through from Proxmox to the HA VM:

In Proxmox web UI: **HA VM → Hardware → Add → USB Device**

Select **Use USB Vendor/Device ID** and choose your dongle from the list. This ensures the same dongle is always passed through even if the USB port changes.

> Use Vendor/Device ID — not port — so it survives reboots regardless of which physical USB port the dongle lands on.

---

## 3.5 Install Essential Add-ons

In HA web UI: **Settings → Add-ons → Add-on Store**

Install and start these add-ons:

| Add-on | Purpose |
|---|---|
| **Mosquitto Broker** | MQTT broker for device communication |
| **File Editor** | Edit HA config files from the web UI |
| **Terminal & SSH** | Shell access to HA OS |
| **Advanced SSH & Web Terminal** | Extended SSH if needed |

---

## 3.6 Configure HA Backups to Proxmox Storage

HA OS backups can be stored on the Proxmox host via a network share or Samba add-on.

**Simple approach:** Install the **Samba share** add-on in HA, mount the share on Proxmox, and copy backups there. A full setup is out of scope here — the important thing is that HA has automated backup enabled.

**Settings → System → Backups → Automatic backups: On**

Set frequency to weekly and retain 3 copies.

---

## 3.7 Proxmox VM Snapshot (Before Major Updates)

Before updating HA OS or major integrations:

In Proxmox web UI: **HA VM → Snapshots → Take Snapshot**

Name it `pre-update-YYYY-MM-DD`. If the update breaks something, restore the snapshot in under 30 seconds.

---

## RAM Allocation Note

4GB is sufficient for Home Assistant with 20–50 devices. If you add many integrations or run heavy automations, increase to 6GB:

Proxmox web UI: **HA VM → Hardware → Memory → Edit → 6144 MB**

Shut down the VM first, make the change, restart.

---

[← Proxmox Installation](02-proxmox-installation.md) | [Next: Ollama + Open WebUI →](04-ollama-open-webui.md)
