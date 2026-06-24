# 11 — Upgrading & Future Expansion

[← Web Search](10-web-search.md) | [← Overview](README.md)

---

## Upgrade Ladder

### Option A — Starting with UM890 Pro Refurb

| Phase | Change | Trigger | Cost |
|---|---|---|---|
| **Phase 1** | UM890 Pro refurb + RAM + NVMe | Now | ~$940–$983 |
| **Phase 2** | Add DEG1 + RM850x + RTX 3090 (used) | 32B performance needed | +~$939–$1,089 |
| **Phase 3** | Add 2nd NVMe (2TB) for models | Storage pressure on 1TB | +~$80–100 |
| **Phase 4** | Swap to AI X1 Pro-470 barebones | Better iGPU or 3-slot NVMe needed | +~$500–550 net (sell UM890) |
| **Phase 5** | Upgrade to 64GB RAM | VM workload pressure | +~$150–200 (new kit) |
| **Phase 6** | Swap GPU to RTX 5090 or RDNA 4 | 32B speed or 70B access | TBD |

### Option B — Starting with AI X1 Pro-470

| Phase | Change | Trigger | Cost |
|---|---|---|---|
| **Phase 1** | AI X1 Pro-470 + RAM + NVMe | Now | ~$1,316–$1,359 |
| **Phase 2** | Add DEG1 + RM850x + RTX 3090 (used) | 32B performance needed | +~$939–$1,089 |
| **Phase 3** | Add 2nd NVMe (2TB) for models | Storage pressure on 1TB | +~$80–100 |
| **Phase 4** | Add 3rd NVMe (2TB) for media | External SSD inconvenience | +~$80–100 |
| **Phase 5** | Upgrade to 64GB RAM | VM workload pressure | +~$150–200 (new kit) |
| **Phase 6** | Swap GPU to RTX 5090 or RDNA 4 | 32B speed or 70B access | TBD |

---

## Option A Phase 4: Migrating from UM890 Pro to AI X1 Pro-470

The RAM and NVMe you bought for the UM890 Pro transfer directly — both machines use DDR5 SO-DIMM and M.2 2280 PCIe 4.0. No reinstallation needed; Proxmox boots from the moved NVMe unchanged.

**Migration process:**

1. Shut down UM890 Pro, power off
2. Remove RAM sticks and NVMe drive
3. Install RAM and NVMe into AI X1 Pro-470 barebones
4. Connect OCuLink from DEG1 (already assembled) to X1 Pro-470
5. Power on — Proxmox boots from the existing NVMe, all VMs intact
6. Verify RAM shows as 32GB in Proxmox, NVMe mounts correctly
7. Sell UM890 Pro barebones (no RAM/NVMe) — expect ~$200–250 return

**Net cost of the mini PC upgrade:** ~$500–550 after UM890 sale proceeds.

**What improves after migration:**
- iGPU inference: 780M → 890M (~25–30% faster for Phase 1 workloads)
- NVMe slots: 2 → 3 (room for dedicated model weight and media drives)
- RAM ceiling: 96GB → 128GB
- ROCm: 780M is more mature; 890M is catching up — expect parity within months

---

## Phase 2: Adding the eGPU

See [eGPU Setup](07-egpu-setup.md) for the complete process. Summary:

1. Assemble DEG1 with RM850x and RTX 3090 (used)
2. Power DEG1 before the UM890 Pro (or AI X1 Pro-470 if already upgraded)
3. Enable VFIO binding for RTX 3090 PCI IDs in Proxmox
4. Add RTX 3090 as PCI passthrough device to Ollama VM
5. Verify CUDA detection in Ollama VM (`nvidia-smi`)
6. Pull 32B model and confirm ~40–50 tok/s

---

## Phase 3–4: Internal NVMe Expansion

When storage prices normalize (~$80–100 for 2TB NVMe):

1. Purchase any PCIe 4.0 NVMe — the model weight/media use case only needs sequential read speed; cheap QLC (Crucial P3, WD Blue) is fine
2. Install in empty M.2 slot
3. Format and mount in Proxmox
4. Update Ollama VM's `OLLAMA_MODELS` path or Plex library path
5. Copy data from external SSD, verify, then use external SSD for backup

---

## Phase 5: RAM Upgrade to 64GB

When you have concrete VM workloads that need more than 32GB:

```bash
# Current usage check — run in Proxmox shell
free -h
# Check per-VM usage
qm status 100 --verbose  # HA VM
qm status 101 --verbose  # Ollama VM
```

If free memory is consistently below 4GB, upgrade time.

**Process:**
1. Shut down all VMs
2. Power off the mini PC
3. Replace both SO-DIMM sticks with 2× 32GB DDR5-5600 kit (~$150–200 at normalized prices)
4. Power on, verify Proxmox shows 64GB
5. Increase Ollama VM RAM allocation: **VM 101 → Hardware → Memory → 24576 MB (24GB)**

---

## Phase 6: GPU Swap

The DEG1 enclosure and RM850x PSU are reused for any future GPU. The swap process:

1. Power off everything
2. Remove RTX 3090 from DEG1
3. Install new GPU
4. Update VFIO binding in Proxmox with new GPU PCI IDs (steps 7.1–7.2)
5. Update Ollama VM PCI passthrough device

**Future GPU candidates:**

> Starting from an RTX 3090 baseline. The 3090 handles 32B comfortably; upgrade when 70B fully-in-VRAM is a hard requirement.

| GPU | VRAM | Notes |
|---|---|---|
| RTX 5090 | 32GB | ~$2,000+; strong 32B; offloads ~11GB for 70B; CUDA |
| AMD RDNA 4 (RX 9070 XT+) | 16GB | 32B offloads; wait for 24GB+ RDNA 4 variant |
| AMD Radeon PRO W7900 | 48GB | 70B fits fully; ~$3,500 — only if 70B is a hard requirement |

---

## Adding More VMs/Services

Proxmox scales cleanly. Common additions:

**Nextcloud LXC** — self-hosted file sync/cloud storage:
```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/nextcloud.sh)"
```

**Jellyfin** — open-source Plex alternative (no account required):
```yaml
# Add to docker-compose.yml
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: always
    ports:
      - "8096:8096"
    volumes:
      - /media:/media:ro
      - jellyfin_config:/config
```

**n8n** — workflow automation (good HA + LLM integration):
```yaml
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
```

---

## Monitoring Your Stack

Install node_exporter on the Proxmox host to feed Grafana dashboards:

```bash
# On Proxmox host
apt install prometheus-node-exporter
systemctl enable --now prometheus-node-exporter
```

In Prometheus config (on Docker LXC), update the node target to `<proxmox-ip>:9100`.

In Grafana, import dashboard ID `1860` (Node Exporter Full) for a complete system overview covering CPU, RAM, disk I/O, and network across all VMs.

---

## Backup Strategy

| What | How | Where | Frequency |
|---|---|---|---|
| HA config | HA built-in backup | Local + optionally external SSD | Weekly |
| Proxmox VMs | Proxmox Backup Server or vzdump | External SSD or NAS | Weekly |
| Docker volumes | `docker run --volumes-from` backup script | External SSD | Weekly |
| Model weights | Re-pullable from Ollama registry | No backup needed — `ollama pull` restores |

For Proxmox VM backups to external SSD:

In Proxmox web UI: **Datacenter → Backup → Add**
- Storage: select your external SSD mount point (add it as a backup storage target first)
- Schedule: weekly
- VMs: select all

---

## Keeping Software Current

```bash
# Proxmox host updates
apt update && apt full-upgrade -y

# Ollama updates (in Ollama VM)
curl -fsSL https://ollama.com/install.sh | sh

# Docker service updates (in Docker LXC)
cd /opt/homelab
docker compose pull
docker compose up -d

# Open WebUI updates (in Ollama VM)
docker pull ghcr.io/open-webui/open-webui:main
docker stop open-webui && docker rm open-webui
# Re-run the docker run command from section 4.5
```

> If an Ollama update breaks GPU detection, check the Ollama GitHub releases page for CUDA regression notes before upgrading. `nvidia-smi` should continue to show the RTX 3090 — Ollama CUDA issues are typically a library path problem resolvable with `sudo apt install --reinstall nvidia-cuda-toolkit`.

---

[← Web Search](10-web-search.md) | [← Overview](README.md)
