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

### Tailscale on Proxmox Host Only + NPM Routing

**Why bother with NPM?** Raw IP:port access works, but NPM adds: HTTPS with automatic Let's Encrypt certs (required for Open WebUI microphone access in mobile browsers), clean hostnames via MagicDNS, and WebSocket support for streaming LLM responses and Home Assistant's real-time updates.

**Prerequisites:** The Docker LXC from [Section 6](06-docker-homelab.md) must be running with NPM deployed. Confirm NPM admin is accessible on your local network at `http://192.168.1.20:81` before continuing.

#### The network problem to solve

When Tailscale is installed only on the Proxmox host, the `100.x.x.x` Tailscale IP belongs exclusively to that host. Your phone can reach `100.x.x.x`, but it cannot directly reach `192.168.1.20` (the Docker LXC where NPM lives) or any other VM/LXC on your LAN. You need one of the two approaches below to bridge that gap.

---

#### Approach A — Tailscale Subnet Router (recommended)

Configure the Proxmox host to advertise your entire home LAN subnet over Tailscale. Your phone then reaches every device on `192.168.1.0/24` — including NPM in the Docker LXC — as if it were on your home network.

**On the Proxmox host:**

```bash
tailscale up --advertise-routes=192.168.1.0/24
```

**In the Tailscale admin console** (`login.tailscale.com/admin`):

1. Click your Proxmox host device
2. **Edit route settings → approve `192.168.1.0/24`**

**On your phone** in the Tailscale app:

- iOS/Android: **Settings → your tailnet → subnet routes → enable your home subnet**

Your phone can now reach `192.168.1.20:81` (NPM admin), `192.168.1.20:80/443` (NPM proxy), and every other LAN IP via Tailscale from anywhere.

---

#### Approach B — Tailscale Inside the Docker LXC

Install Tailscale directly inside the Docker LXC so NPM gets its own `100.x.x.x` Tailscale address. Traffic flows: phone → Docker LXC's Tailscale IP → NPM → target VM/LXC at its LAN IP. No subnet routing needed; only NPM-proxied services are reachable via Tailscale.

In the Docker LXC console (Proxmox web UI: **LXC 200 → Console**):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
systemctl enable tailscaled
```

Authenticate in your browser. The Docker LXC now appears as a second device in the Tailscale admin console with its own `100.x.x.x` address. Note this IP — it becomes your NPM entry point.

---

#### Configure NPM Proxy Hosts

Open NPM admin UI:

- **Approach A:** `http://192.168.1.20:81`
- **Approach B:** `http://<docker-lxc-tailscale-ip>:81`

Default credentials: `admin@example.com` / `changeme`. Change these on first login.

Go to **Hosts → Proxy Hosts → Add Proxy Host** for each service.

**Enable MagicDNS first** (needed for domain-based routing in NPM — see [section 8.8](#88-tailscale-admin-console)). MagicDNS gives your devices hostnames like `docker.tail12345.ts.net`. Use that hostname as the "Domain Name" in NPM so it can route by hostname rather than by port alone.

If you prefer port-based access without a domain, skip NPM's proxy host feature and access services directly at `<npm-ip>:<service-port>` via Tailscale after subnet routing.

---

**Open WebUI proxy host:**

| Field | Value |
|---|---|
| Domain Names | `openwebui.your-tailnet.ts.net` (your MagicDNS name) |
| Scheme | `http` |
| Forward Hostname / IP | `<ollama-vm-lan-ip>` (e.g., `192.168.1.30`) |
| Forward Port | `3000` |
| Websockets Support | ✅ **Enable** — required for streaming LLM responses |

**Home Assistant proxy host:**

| Field | Value |
|---|---|
| Domain Names | `ha.your-tailnet.ts.net` |
| Scheme | `http` |
| Forward Hostname / IP | `<haos-vm-lan-ip>` (e.g., `192.168.1.40`) |
| Forward Port | `8123` |
| Websockets Support | ✅ **Enable** — required for HA's real-time WebSocket API |

**Grafana proxy host:**

| Field | Value |
|---|---|
| Domain Names | `grafana.your-tailnet.ts.net` |
| Scheme | `http` |
| Forward Hostname / IP | `192.168.1.20` (same LXC) |
| Forward Port | `3001` |
| Websockets Support | ✅ Enable |

#### Enable HTTPS (optional but recommended for Open WebUI mic access)

For each proxy host, click **SSL → Request a new SSL Certificate → Let's Encrypt**. This requires your domain to be publicly DNS-resolvable. MagicDNS hostnames (`*.ts.net`) are publicly resolvable by design — Let's Encrypt can issue certs for them.

Enable **Force SSL** to redirect HTTP to HTTPS automatically.

#### Final access URLs (Approach A with MagicDNS)

| Service | URL |
|---|---|
| Open WebUI | `https://openwebui.your-tailnet.ts.net` |
| Home Assistant | `https://ha.your-tailnet.ts.net` |
| Grafana | `https://grafana.your-tailnet.ts.net` |
| Proxmox web UI | `https://proxmox.your-tailnet.ts.net:8006` |
| NPM admin | `http://192.168.1.20:81` (LAN only) or Approach B Tailscale IP |

This way you manage one Tailscale node (Proxmox host for Approach A, or Docker LXC for Approach B) and NPM routes all service traffic internally.

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
