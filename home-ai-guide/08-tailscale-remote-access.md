# 08 — Remote Access with Tailscale

[← eGPU Setup](07-egpu-setup.md) | [Next: External Storage →](09-external-storage.md)

---

## How Tailscale Works

Tailscale builds an encrypted WireGuard mesh network between your devices. Once installed, your phone and home server share a private `100.x.x.x` address space.

**Data traffic flows directly peer-to-peer** — Tailscale's servers are not in the path. They only handle the initial key exchange (control plane). If a direct connection fails (rare on cellular), traffic routes through Tailscale's DERP relay servers — still end-to-end encrypted, Tailscale cannot read it.

**Free tier:** Up to 100 devices, no bandwidth limits. Sufficient for personal home use indefinitely.

---

## 8.1 Create a Tailscale Account

Sign up at `tailscale.com`. Use a Google, GitHub, or Microsoft account — no separate password needed.

---

## 8.2 Install Tailscale on Proxmox Host

In the Proxmox shell:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

A URL will appear — open it in a browser to authenticate the device. After auth, your Proxmox host appears in the Tailscale admin console with a `100.x.x.x` address.

Enable Tailscale on boot:

```bash
systemctl enable tailscaled
```

---

## 8.3 Install Tailscale on Your Phone

- **iOS:** App Store → search "Tailscale"
- **Android:** Play Store → search "Tailscale"

Open the app and sign in with the same account you used in step 8.1.

Both devices now appear in your Tailscale network. Your phone can reach Proxmox at its `100.x.x.x` address from anywhere — home WiFi, cellular, hotel WiFi.

---

## 8.4 Access Services Remotely

From your phone browser, use the Tailscale IP of the Proxmox host:

| Service | URL via Tailscale |
|---|---|
| Proxmox web UI | `https://100.x.x.x:8006` |
| Home Assistant | `http://100.x.x.x:8123` (if HA on Proxmox host's network) |
| Open WebUI | `http://<ollama-vm-tailscale-ip>:3000` |

> **Note:** Each VM/LXC needs its own Tailscale install to get its own Tailscale IP. Alternatively, install Tailscale only on the Proxmox host and use Nginx Proxy Manager to reverse-proxy all services through the host's Tailscale IP.

### Simpler: Install Tailscale on Proxmox Host Only + NPM Routing

In Nginx Proxy Manager (running in the Docker LXC), create proxy entries accessible at the Proxmox host's Tailscale IP:

| Internal address | Proxied as |
|---|---|
| `<ollama-vm-ip>:3000` | `100.x.x.x:3000` |
| `<haos-vm-ip>:8123` | `100.x.x.x:8123` |
| `<docker-lxc-ip>:3001` | `100.x.x.x:3001` |

This way you only manage one Tailscale device (Proxmox host) and NPM routes traffic to the right VM/LXC internally.

---

## 8.5 Enable Subnet Routes (Optional)

If you want your phone to access all devices on your home LAN (not just Proxmox) via Tailscale, enable subnet routing:

```bash
# On Proxmox host
tailscale up --advertise-routes=192.168.1.0/24
```

In the Tailscale admin console: approve the subnet route for this device.

Your phone can now reach any device on your home network at `192.168.1.x` while on Tailscale — useful for HA companion app, Proxmox web UI, NAS, etc.

---

## 8.6 Open WebUI on Mobile

Open WebUI has a mobile-friendly interface. From your phone browser:

```
http://<tailscale-ip>:3000
```

For a native app experience:
- **iOS:** Add to Home Screen (Safari → Share → Add to Home Screen)
- **Android:** Install as PWA (Chrome → menu → Add to Home Screen)

This creates a home screen icon that opens Open WebUI in fullscreen, indistinguishable from a native app.

---

## 8.7 Home Assistant Companion App

The official HA Companion App (iOS/Android) works over Tailscale:

1. Install **Home Assistant** from App Store/Play Store
2. App will auto-discover HA on your local network when home
3. For remote access: **Settings → Companion App → Add Server Manually**
   - External URL: `http://<haos-tailscale-ip>:8123`
4. The app switches between local and Tailscale automatically

---

## 8.8 Tailscale Admin Console

At `login.tailscale.com/admin`:

- View all connected devices and their Tailscale IPs
- Disable a device if a phone is lost or stolen
- Set up MagicDNS (human-readable names like `proxmox` instead of `100.x.x.x`)

### Enable MagicDNS

In the Tailscale admin console: **DNS → Enable MagicDNS**

Your devices get hostnames like:
- `proxmox.your-tailnet.ts.net`
- Accessible as just `proxmox` on devices in your network

---

## Security Notes

- Tailscale uses WireGuard, a modern audited VPN protocol
- Each device has a unique key pair — a compromised phone can be revoked instantly from the admin console without affecting other devices
- No ports are open on your router — Tailscale uses outbound connections only
- Your LLM prompts and responses travel encrypted in the WireGuard tunnel, peer-to-peer, not through Tailscale's servers

---

[← eGPU Setup](07-egpu-setup.md) | [Next: External Storage →](09-external-storage.md)
