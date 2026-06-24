# 06 — Docker & Homelab Services

[← Voice Stack](05-voice-stack.md) | [Next: eGPU Setup →](07-egpu-setup.md)

---

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

## 6.1 Create the Docker LXC

In Proxmox web UI: **Create CT** (Create Container)

| Setting | Value |
|---|---|
| CT ID | `200` |
| Hostname | `docker` |
| Template | Debian 12 (download from Proxmox template list) |
| Disk | `40GB` |
| CPU | `2 cores` |
| RAM | `6144` MB (6GB) |
| Network | `vmbr0`, static IP (e.g., `192.168.1.20`) |
| **Privileged** | ✅ **Check this box** — required for Docker and device passthrough |

After creation, before starting — edit the LXC config for Docker compatibility:

```bash
# On Proxmox host shell
nano /etc/pve/lxc/200.conf
```

Add these lines:

```
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

Start the LXC.

---

## 6.2 Install Docker

In the Docker LXC shell (Proxmox web UI: **LXC 200 → Console**):

```bash
apt update && apt install -y curl
curl -fsSL https://get.docker.com | sh
```

Verify:

```bash
docker run hello-world
```

---

## 6.3 Create Docker Compose Directory

```bash
mkdir -p /opt/homelab
cd /opt/homelab
```

---

## 6.4 Deploy the Stack

Create the compose file:

```bash
nano /opt/homelab/docker-compose.yml
```

```yaml
version: "3.9"

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
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - homelab
```

Create minimal Prometheus config:

```bash
nano /opt/homelab/prometheus.yml
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

## 6.5 Access the Services

| Service | URL | Default login |
|---|---|---|
| Portainer | `http://<docker-lxc-ip>:9000` | Create on first visit |
| NPM Admin | `http://<docker-lxc-ip>:81` | `admin@example.com` / `changeme` |
| Grafana | `http://<docker-lxc-ip>:3001` | `admin` / `changeme` |
| Prometheus | `http://<docker-lxc-ip>:9090` | None |

Change all default passwords immediately.

---

## 6.6 Install Plex Media Server

Plex runs in its own LXC to keep it isolated and to allow iGPU passthrough for hardware transcoding.

### Create Plex LXC

Same process as the Docker LXC but:

| Setting | Value |
|---|---|
| CT ID | `201` |
| Hostname | `plex` |
| RAM | `2048` MB |
| Disk | `20GB` (media stored on external SSD — see [External Storage](09-external-storage.md)) |
| Privileged | ✅ Yes |

### Pass 780M iGPU to Plex LXC

> **Phase 1 note:** In Phase 1, the 780M iGPU is passed through to the Ollama VM. The `/dev/dri/` device will not be present on the host until Phase 2 (when the RTX 3090 replaces the iGPU in VFIO binding). Skip the hardware transcoding setup for now and configure it after completing [eGPU Setup](07-egpu-setup.md).

In Proxmox host shell:

```bash
ls /dev/dri/
# Note the renderD128 and card0/card1 device names
```

Edit the Plex LXC config:

```bash
nano /etc/pve/lxc/201.conf
```

Add:

```
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

### Install Plex in LXC

```bash
# In Plex LXC console
curl https://downloads.plex.tv/plex-keys/PlexSign.key | apt-key add -
echo "deb https://downloads.plex.tv/repo/deb public main" \
  > /etc/apt/sources.list.d/plexmediaserver.list
apt update && apt install -y plexmediaserver
systemctl enable --now plexmediaserver
```

Access: `http://<plex-lxc-ip>:32400/web`

---

## 6.7 Nginx Proxy Manager — HTTPS Setup

NPM provides HTTPS (Let's Encrypt) for your services. This is required for Open WebUI microphone access from a browser (browsers block mic access on non-HTTPS origins).

After setup:

1. Point a domain or subdomain at your home IP (or use Tailscale's MagicDNS)
2. In NPM admin UI: **Hosts → Proxy Hosts → Add**
3. Create entries for each service:
   - `openwebui.yourdomain.com` → `<ollama-vm-ip>:3000`
   - `ha.yourdomain.com` → `<haos-vm-ip>:8123`
4. Enable **SSL → Let's Encrypt** on each

---

[← Voice Stack](05-voice-stack.md) | [Next: eGPU Setup →](07-egpu-setup.md)
