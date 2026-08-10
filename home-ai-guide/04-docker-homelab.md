---
---
# 04 — Docker & Homelab Services

[← External Storage](03-external-storage.md) | [Next: Nginx Proxy Manager →](05-nginx-proxy-manager.md)

---

{% include guide-toc.html %}

## Architecture

All homelab services run in a **privileged LXC container** on Proxmox, with Docker inside it. This gives clean isolation from HA and Ollama while keeping overhead minimal.

```
Proxmox LXC (Docker host)
├── Portainer          (Docker management UI)
├── Nginx Proxy Manager (reverse proxy + HTTPS)
├── Grafana            (monitoring dashboards)
├── Prometheus         (metrics collection)
└── SearXNG            (self-hosted web search — see section 10)
```

---

## 4.0 Template Download

**First, download the Debian 13 template** (one-time setup):

In the Proxmox left panel: **node → local → CT Templates → Templates button** → search `debian` → select **Debian 13** → **Download**. Wait for it to complete before creating the container.

---

## 4.1 AdGuard Home — Split-Horizon DNS

AdGuard Home runs in its own LXC to provide two things: network-wide ad blocking, and local DNS rewrites that make `*.yourdomain.com` resolve to Nginx Proxy Manager on your LAN (and over Tailscale — see [section 12](12-tailscale-remote-access.md)).

**Why AdGuard gets its own LXC:** DNS is infrastructure. You don't want a Docker stack restart to take down name resolution for every device on your LAN.

### Create AdGuard LXC (CT 202)

In Proxmox web UI: **Create CT**

| Setting | Value |
|---|---|
| CT ID | `202` |
| Hostname | `adguard` |
| Unprivileged container | ✅ Yes (default) |
| Template | Debian 13 |
| Disk | `8GB` |
| CPU | `1 core` |
| RAM | `512` MB |
| Network — Bridge | `vmbr0` |
| Network — IPv4 | Static, `<adguard-lxc-ip>/24` — choose a free IP on your LAN and note it |
| Network — Gateway | Your router IP |
| DNS tab — DNS server | `1.1.1.1` (temporary — you'll switch this to AdGuard itself once it's running) |
| Start at boot | ✅ Yes |

Start the LXC.

### Install AdGuard Home

In the AdGuard LXC console:

```bash
apt update && apt install -y curl
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
```

Enable AdGuard Home to start automatically on boot:

```bash
systemctl enable AdGuardHome
```

The installer registers AdGuard Home as a systemd service and starts it automatically.

Access the setup wizard at `http://<adguard-lxc-ip>:3000` from any browser on your LAN.

In the wizard:
1. Accept the default listen interfaces
2. Set an admin username and password
3. Set upstream DNS servers: `1.1.1.1` and `8.8.8.8`
4. Complete setup

After setup, the web UI moves to port 80: `http://<adguard-lxc-ip>`

### Enable Default Blocklists

In the AdGuard web UI: **Filters → DNS Blocklists → Add blocklist**

Select the pre-populated **AdGuard DNS filter** entry and enable it. Click **Apply**.

### Add DNS Rewrites

This is how `*.yourdomain.com` resolves to NPM on your LAN instead of the public internet.

In the AdGuard web UI: **Filters → DNS Rewrites → Add DNS rewrite**

Add one entry per service. All entries point to `<npm-lxc-ip>` — the static IP you will assign to the Docker LXC in section 4.2:

| Domain | Answer |
|---|---|
| `ha.yourdomain.com` | `<npm-lxc-ip>` |
| `ollama.yourdomain.com` | `<npm-lxc-ip>` |
| `portainer.yourdomain.com` | `<npm-lxc-ip>` |
| `grafana.yourdomain.com` | `<npm-lxc-ip>` |

> All subdomains point to NPM's IP. NPM routes to the correct backend based on the hostname in the request.

Add more entries here as you add services. Or, you can use a wildcard like `*.home.yourdomain.com` to catch everything.

### Configure ASUS ZenWiFi XD6

Log into the router admin UI → **Advanced Settings → LAN → DHCP Server** tab

Set:
- **DNS Server 1:** `<adguard-lxc-ip>`
- **DNS Server 2:** `1.1.1.1` (fallback if AdGuard is unreachable)

Click **Apply**. Your router will restart its DHCP service. Reconnect your devices or wait for DHCP lease renewal (usually within a few minutes).

### Verify

From any device on your LAN:

```bash
nslookup ha.yourdomain.com <adguard-lxc-ip>
# Expected: returns <npm-lxc-ip>

nslookup google.com <adguard-lxc-ip>
# Expected: returns a public IP (upstream resolution is working)
```

---

## 4.2 Create the Docker LXC

In Proxmox web UI: **Create CT** (Create Container)

| Setting | Value |
|---|---|
| CT ID | `200` |
| Hostname | `docker` |
| **Unprivileged container** | **Uncheck this box** — required for Docker and device passthrough |
| Password/Confirm Password | Make sure to remember this |
| Template | Debian 13 |
| Disk | `40GB` |
| CPU | `2 cores` |
| RAM | `6144` MB (6GB) |
| Network — Bridge | `vmbr0` |
| Network — IPv4 | Static, `<docker-lxc-ip>/24` — use `/24`, not `/32` (match your subnet). This IP is what you entered as `<npm-lxc-ip>` in section 4.1. |
| Network — Gateway | Your router IP (e.g. `192.168.50.1`) |
| **DNS tab — DNS server** | `<adguard-lxc-ip>` — set this so the LXC resolves hostnames through AdGuard |
| Start at boot | ✅ Yes |

After creation, before starting — edit the LXC config for Docker compatibility:

```bash
# On Proxmox host shell
vim /etc/pve/lxc/200.conf
```

Add these lines:

```
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

Start the LXC.

---

## 4.3 Install Docker

In the Docker LXC shell (Proxmox web UI: **LXC 200 → Console**):

Username: root
Password: <entered in previous step>

```bash
apt update && apt install -y curl
curl -fsSL https://get.docker.com | sh
```

Verify:

```bash
docker run hello-world
```

Enable Docker to start automatically on boot:

```bash
systemctl enable docker
```

---

## 4.4 Create Docker Compose Directory

```bash
mkdir -p /opt/homelab
cd /opt/homelab
```

---

## 4.5 Deploy the Stack

Create the compose file:

```bash
vim /opt/homelab/docker-compose.yml
```

> You may have to install vim at this point with `apt-get install -y vim`
> Vim may auto-indent. You can use `:set paste` to temporarily disable that

```yaml
networks:
  homelab:
    driver: bridge

volumes:
  portainer_data:
  grafana_data:
  prometheus_data:
  npm_data:
  npm_letsencrypt:
  npm_db:

services:

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - homelab

  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: always
    ports:
      - "80:80"
      - "443:443"
      - "81:81"   # NPM admin UI
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
    networks:
      - homelab

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - homelab

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=changeme
      - GF_SERVER_ROOT_URL=https://grafana.yourdomain.com
      - GF_SERVER_DOMAIN=grafana.yourdomain.com
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - homelab
```

Create minimal Prometheus config:

```bash
vim /opt/homelab/prometheus.yml
```

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['<proxmox-host-ip>:9100']  # node_exporter on Proxmox host
```

Start the stack:

```bash
cd /opt/homelab
docker compose up -d
```

---

## 4.6 Access the Services

| Service | URL | Default login |
|---|---|---|
| Portainer | `http://<docker-lxc-ip>:9000` | Create on first visit |
| NPM Admin | `http://<docker-lxc-ip>:81` | `admin@example.com` / `changeme` (or should create automatically on first access) |
| Grafana | `http://<docker-lxc-ip>:3001` | `admin` / `changeme` |
| Prometheus | `http://<docker-lxc-ip>:9090` | None |

Change all default passwords immediately.

> For Portainer, you will need a setup token to create the admin user. On the docker LXC, run `docker logs portainer` and look for `setup_token=`
> If you attempt to create the admin user and clicking "Create User" just sorta flashes, then the portainer install probably timed out (5 minutes). Run `docker restart portainer && docker logs portainer` to restart and get the new setup token.

---

[← External Storage](03-external-storage.md) | [Next: Nginx Proxy Manager →](05-nginx-proxy-manager.md)
