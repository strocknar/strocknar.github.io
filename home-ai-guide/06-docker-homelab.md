---
---
# 06 — Docker & Homelab Services

[← Voice Stack](05-voice-stack.md) | [Next: eGPU Setup →](07-egpu-setup.md)

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

## 6.1 Create the Docker LXC

**First, download the Debian 12 template** (one-time setup):

In the Proxmox left panel: **node → local → CT Templates → Templates button** → search `debian` → select **Debian 13** → **Download**. Wait for it to complete before creating the container.

In Proxmox web UI: **Create CT** (Create Container)

| Setting | Value |
|---|---|
| CT ID | `200` |
| Hostname | `docker` |
| **Unprivileged container** | **Uncheck this box** — required for Docker and device passthrough |
| Password/Confirm Password | Make sure to remember this |
| Template | Debian 12 |
| Disk | `40GB` |
| CPU | `2 cores` |
| RAM | `6144` MB (6GB) |
| Network — Bridge | `vmbr0` |
| Network — IPv4 | Static, `192.168.50.x/24` — use `/24`, not `/32` (match your subnet) |
| Network — Gateway | Your router IP (e.g. `192.168.50.1`) |
| **DNS tab — DNS server** | `1.1.1.1` — set this explicitly or `apt` will fail to resolve hostnames |

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

## 6.2 Install Docker

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
vim /opt/homelab/docker-compose.yml
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

## 6.5 Access the Services

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
vim /etc/pve/lxc/201.conf
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

The goal: reach services by a friendly name (`ha.yourdomain.com`) on your internal network only, with valid browser-trusted HTTPS through NPM — no port forwarding, no public exposure.

This uses **DNS-01 challenge** (Let's Encrypt proves domain ownership via a DNS TXT record instead of port 80) combined with **split-horizon DNS** (your router resolves the domain to a local IP).

### Prerequisites

- A domain hosted in **AWS Route 53**
- An AWS IAM user with permissions to modify Route 53 records (created in Step 1)
- NPM running (from section 6.4)

---

### Step 1 — Create an IAM User for DNS-01

NPM needs AWS credentials that can create/delete Route 53 TXT records for the Let's Encrypt challenge.

1. In the [AWS IAM console](https://console.aws.amazon.com/iam) → **Users → Create user**
2. Name it `certbot-dns` (no console access needed)
3. After creation, go to the user → **Security credentials → Create access key** → select **Other** → create
4. Save the **Access Key ID** and **Secret Access Key** — shown once

Attach this inline policy to the user (replace `<HOSTED_ZONE_ID>` with your Route 53 hosted zone ID, found in Route 53 → Hosted zones):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ChangeResourceRecordSets",
      "Resource": "arn:aws:route53:::hostedzone/<HOSTED_ZONE_ID>"
    }
  ]
}
```

---

### Step 2 — Request a Wildcard Certificate in NPM

1. In NPM admin UI: **SSL Certificates → Add SSL Certificate → Let's Encrypt**
2. Fill in:

   | Field | Value |
   |---|---|
   | Domain Names | `*.yourdomain.com` and `yourdomain.com` |
   | Email | your email |
   | Use a DNS Challenge | ✅ Enable |
   | DNS Provider | `Route53` |
   | Credentials File Content | see below |

   Credentials content:
   ```
   dns_route53_access_key_id = AKIAIOSFODNN7EXAMPLE
   dns_route53_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   ```

3. Agree to Let's Encrypt ToS → **Save**

NPM will create a DNS TXT record in Route 53 via the AWS API to prove ownership, then issue a wildcard cert. This takes ~30 seconds.

---

### Step 3 — Add Local DNS Overrides

Your router or Pi-hole needs to resolve `*.yourdomain.com` subdomains to your NPM LXC IP instead of the public internet.

**If your router supports custom DNS records** (most Unifi, OPNsense, pfSense do):

Add an A record for each service pointing to your NPM LXC IP (e.g. `192.168.50.8`):

| Hostname | IP |
|---|---|
| `ha.yourdomain.com` | `192.168.50.8` |
| `ollama.yourdomain.com` | `192.168.50.8` |
| `portainer.yourdomain.com` | `192.168.50.8` |
| `grafana.yourdomain.com` | `192.168.50.8` |

All subdomains point to NPM — NPM routes to the correct backend based on hostname.

**If your router doesn't support custom DNS**, set up Pi-hole (runs as a Docker container in the homelab stack) and use it as your LAN's DNS server. Add local DNS records there.

---

### Step 4 — Create Proxy Hosts in NPM

In NPM admin UI: **Hosts → Proxy Hosts → Add Proxy Host**

For each service:

| Field | Value |
|---|---|
| Domain Names | `ha.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname / IP | LAN IP of the service (e.g. `192.168.50.7`) |
| Forward Port | Service port (e.g. `8123` for HA) |
| **SSL Certificate** | Select the `*.yourdomain.com` wildcard cert |
| Force SSL | ✅ Enable |
| HTTP/2 Support | ✅ Enable |

Repeat for each service. Example entries:

| Subdomain | Backend IP | Port |
|---|---|---|
| `ha.yourdomain.com` | HA VM LAN IP | `8123` |
| `ollama.yourdomain.com` | Ollama VM LAN IP | `3000` |
| `portainer.yourdomain.com` | Docker LXC IP | `9000` |
| `grafana.yourdomain.com` | Docker LXC IP | `3001` |

---

### Result

Typing `ha.yourdomain.com` in any browser on your LAN:
- Resolves to NPM via your local DNS override
- NPM proxies to HA and serves valid HTTPS with the wildcard cert
- Never leaves your network
- Full browser mic access works

---

### If using Tailscale hostnames (`.ts.net`) — Let's Encrypt will fail

Let's Encrypt can't issue certs for `.ts.net` domains (they're not publicly delegatable). Use **Tailscale's built-in HTTPS certificates** instead:

1. [Tailscale admin console](https://login.tailscale.com/admin/dns) → **DNS** → enable **HTTPS Certificates**
2. On each machine:
   ```bash
   tailscale cert <hostname>.ts.net
   ```
   Cert and key are placed in `/var/lib/tailscale/certs/`
3. In NPM: **SSL Certificates → Add Certificate → Custom** and provide the cert/key paths

---

[← Voice Stack](05-voice-stack.md) | [Next: eGPU Setup →](07-egpu-setup.md)
