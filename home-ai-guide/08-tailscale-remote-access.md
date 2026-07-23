---
---
# 08 — Remote Access with Tailscale

[← eGPU Setup](07-egpu-setup.md) | [Next: External Storage →](09-external-storage.md)

---

{% include guide-toc.html %}

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
```

Enable IP forwarding — required for subnet routing (section 8.4):

```bash
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ip-forward.conf
sysctl -p /etc/sysctl.d/99-ip-forward.conf
```

Bring Tailscale up and authenticate:

```bash
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

## 8.4 Configure Subnet Router

The Proxmox host advertises your entire home LAN subnet over Tailscale. Any Tailscale-connected device (your phone, laptop, etc.) can then reach every device on your LAN — NPM, AdGuard, VMs — as if it were physically home.

On the Proxmox host:

```bash
tailscale set --advertise-routes=192.168.x.x/24
```

Replace `192.168.x.x/24` with your actual home subnet.

In the **Tailscale admin console** (`login.tailscale.com/admin`):

1. Click your Proxmox host device
2. **Edit route settings → approve `192.168.x.x/24`**

Your Tailscale devices will now route LAN traffic through the Proxmox host automatically.

---

## 8.5 Configure Split DNS in Tailscale

This makes `*.yourdomain.com` resolve correctly on remote devices over Tailscale — without routing all DNS through your homelab.

In the **Tailscale admin console**: **DNS → Nameservers → Add nameserver**

| Field | Value |
|---|---|
| Nameserver IP | `<adguard-lxc-ip>` (your LAN IP — reachable via the subnet router configured in 8.4) |
| Restrict to domain | ✅ Enable |
| Domain | `yourdomain.com` |

Click **Save**.

**What this does:** Tailscale-connected remote devices send only `yourdomain.com` queries to AdGuard. All other DNS queries go directly to public resolvers. This means:

- `ha.yourdomain.com` resolves correctly from cellular or any remote network
- If your homelab is down, general internet browsing is unaffected
- Ad blocking does **not** apply to remote Tailscale devices — only `yourdomain.com` queries are routed through AdGuard

---

## 8.6 Open WebUI on Mobile

Open WebUI has a mobile-friendly interface. From your phone browser:

```
https://ollama.yourdomain.com
```

For a native app experience:
- **iOS:** Add to Home Screen (Safari → Share → Add to Home Screen)
- **Android:** Install as PWA (Chrome → menu → Add to Home Screen)

This creates a home screen icon that opens Open WebUI in fullscreen, indistinguishable from a native app.

---

## 8.7 Home Assistant Companion App

The official HA Companion App (iOS/Android) uses `ha.yourdomain.com` — the same URL whether you're home or remote. AdGuard resolves it to NPM on your LAN; Tailscale split DNS resolves it through AdGuard when you're remote. No manual switching required.

1. Install **Home Assistant** from App Store/Play Store
2. App will auto-discover HA on your local network when home
3. For remote access: **Settings → Companion App → Add Server Manually**
   - External URL: `https://ha.yourdomain.com`
4. The app uses this URL on LAN and over Tailscale — no separate internal/external URL needed

---

## 8.8 Tailscale Admin Console

At `login.tailscale.com/admin`:

- View all connected devices and their Tailscale IPs
- Disable a device if a phone is lost or stolen
- Manage subnet routes and split DNS settings (configured in sections 8.4 and 8.5)

### MagicDNS

In the Tailscale admin console: **DNS → Enable MagicDNS**

MagicDNS assigns hostnames to your Tailscale devices — for example, `proxmox.your-tailnet.ts.net`. This is useful for **direct device-to-device access**: SSH into Proxmox by name rather than memorizing a `100.x.x.x` address.

> MagicDNS is not used for homelab service access. Services use `*.yourdomain.com` via AdGuard and NPM (sections 6.1 and 6.8). MagicDNS and your custom domain coexist without conflict.

---

## Access URLs

All services use the same URL whether you're on your home LAN, home WiFi, or connected remotely via Tailscale:

| Service | URL |
|---|---|
| Home Assistant | `https://ha.yourdomain.com` |
| Open WebUI | `https://ollama.yourdomain.com` |
| Portainer | `https://portainer.yourdomain.com` |
| Grafana | `https://grafana.yourdomain.com` |
| Proxmox web UI | `https://<proxmox-host-ip>:8006` (LAN) or `http://100.x.x.x:8006` (Tailscale IP) |
| NPM admin | `http://<npm-lxc-ip>:81` (LAN only) |
| AdGuard admin | `http://<adguard-lxc-ip>` (LAN only) |

---

## Security Notes

- Tailscale uses WireGuard, a modern audited VPN protocol
- Each device has a unique key pair — a compromised phone can be revoked instantly from the admin console without affecting other devices
- No ports are open on your router — Tailscale uses outbound connections only
- Your LLM prompts and responses travel encrypted in the WireGuard tunnel, peer-to-peer, not through Tailscale's servers
- `*.yourdomain.com` is never publicly resolvable to your private IPs — Route53 is used only for cert issuance via DNS-01 challenge

---

[← eGPU Setup](07-egpu-setup.md) | [Next: External Storage →](09-external-storage.md)
