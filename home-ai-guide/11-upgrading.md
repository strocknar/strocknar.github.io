---
---
# 11 — Upgrading & Future Expansion

[← Web Search](10-web-search.md) | [← Overview](README.md)

---

{% include guide-toc.html %}

## Upgrade Ladder

### Option A — Starting with UM890 Pro Refurb

| Phase | Change | Trigger | Cost |
|---|---|---|---|
| **Phase 1** | UM890 Pro refurb + NVMe | Now | ~$558–$593 |
| **Phase 2** | Add DEG1 + RM850x + RTX 3090 (used) | 32B performance needed | +~$939–$1,089 |
| **Phase 3** | Add 2nd NVMe (2TB) for models | Storage pressure on 1TB | +~$80–100 |
| **Phase 4** | Swap to AI X1 Pro-470 (32GB+1TB bundle) | Better iGPU or 3-slot NVMe needed | ~$759 (sale) / $949 (regular) |
| **Phase 5** | Swap GPU to RTX 5090 | 70B access or coding speed | ~$4,100 |

> **RAM note:** The UM890 Pro and AI X1 Pro-470 use **soldered LPDDR5X memory** — not user-replaceable. There is no RAM upgrade path for these mini PCs. The RAM lines have been removed from the upgrade ladder; Phase 1 costs reflect the UM890 Pro refurb + NVMe only.

### Option B — Starting with AI X1 Pro-470

| Phase | Change | Trigger | Cost |
|---|---|---|---|
| **Phase 1** | AI X1 Pro-470 (32GB+1TB bundle) | Now | ~$759 (sale) / $949 (regular) |
| **Phase 2** | Add DEG1 + RM850x + RTX 3090 (used) | 32B performance needed | +~$939–$1,089 |
| **Phase 3** | Add 2nd NVMe (2TB) for models | Storage pressure on 1TB | +~$80–100 |
| **Phase 4** | Add 3rd NVMe (2TB) for media | External SSD inconvenience | +~$80–100 |
| **Phase 5** | Swap GPU to RTX 5090 | 70B access or coding speed | ~$4,100 |

> **No barebones option:** Minisforum sells the AI X1 Pro-470 only in configured bundles (32GB RAM + 1TB SSD). The $759 sale price (ending ~July 26, 2026) vs $949 regular includes RAM and NVMe — no additional storage/RAM purchase needed.

---

## Option A Phase 4: Migrating from UM890 Pro to AI X1 Pro-470

> **Memory note:** Both the UM890 Pro and the AI X1 Pro-470 use **soldered LPDDR5X** — there are no SO-DIMM slots. RAM cannot be moved or upgraded. The NVMe drive transfers, but not RAM.

The AI X1 Pro-470 is sold only as a complete bundle (32GB LPDDR5X + 1TB NVMe included). Your UM890 Pro NVMe drive can be installed as a second drive or used for backup; Proxmox will need to be reinstalled (or cloned) onto the new internal NVMe.

**Migration process:**

1. Back up all Proxmox VMs (vzdump to external SSD)
2. Shut down UM890 Pro, power off
3. Remove the NVMe drive (optional — the AI X1 Pro-470 includes its own 1TB NVMe)
4. Set up AI X1 Pro-470: install Proxmox fresh on the included NVMe, restore VMs from backup
5. Connect OCuLink from DEG1 (already assembled) to X1 Pro-470
6. Sell UM890 Pro — expect ~$200–250 return

**Net cost of the mini PC upgrade:** ~$509–749 after UM890 sale proceeds (using sale price $759 vs regular $949).

**What improves after migration:**
- iGPU inference: 780M → 890M (~25–30% faster for Phase 1 workloads)
- NVMe slots: 2 → 3 (room for dedicated model weight and media drives)
- ROCm: 780M is more mature; 890M is catching up — expect parity within months

---

## Phase 2: Adding the eGPU

See [eGPU Setup](07-egpu-setup.md) for the complete process. Summary:

1. Assemble DEG1 with RM850x and RTX 3090 (used)
2. Power DEG1 before the UM890 Pro (or AI X1 Pro-470 if already upgraded)
3. Enable VFIO binding for RTX 3090 PCI IDs in Proxmox
4. Add RTX 3090 as PCI passthrough device to Ollama VM
5. Verify CUDA detection in Ollama VM (`nvidia-smi`)
6. Pull 32B model and confirm ~25–35 tok/s

---

## Phase 3–4: Internal NVMe Expansion

When storage prices normalize (~$80–100 for 2TB NVMe):

1. Purchase any PCIe 4.0 NVMe — the model weight/media use case only needs sequential read speed; cheap QLC (Crucial P3, WD Blue) is fine
2. Install in empty M.2 slot
3. Format and mount in Proxmox
4. Update Ollama VM's `OLLAMA_MODELS` path or Plex library path
5. Copy data from external SSD, verify, then use external SSD for backup

---

## Monitoring Memory Pressure

Since both the UM890 Pro and AI X1 Pro-470 use **soldered LPDDR5X** (not user-replaceable), there is no RAM upgrade path. Monitor usage to ensure you stay within the 32GB budget:

```bash
# Current usage check — run in Proxmox shell
free -h
# Check per-VM usage
qm status 100 --verbose  # HA VM
qm status 101 --verbose  # Ollama VM
```

If free memory drops consistently below 4GB, reduce VM RAM allocations (HA rarely needs more than 4–6GB; the Ollama VM's limit is more relevant).

---

## Phase 6: GPU Swap

The DEG1 enclosure and RM850x PSU are reused for any future GPU. The swap process:

1. Power off everything
2. Remove RTX 3090 from DEG1
3. Install new GPU
4. Update VFIO binding in Proxmox with new GPU PCI IDs (steps 7.1–7.2)
5. Update Ollama VM PCI passthrough device

**Future GPU candidates:**

> Starting from an RTX 3090 baseline (24GB, 936 GB/s). The 3090 runs qwen3:32b-q4_K_M at ~25–35 tok/s — functional for coding. Upgrade only if 70B access or faster interactive speed is a hard requirement.

| GPU | VRAM | Bandwidth | Street Price (Jul 2026) | Verdict |
|---|---|---|---|---|
| RTX 4090 (used) | 24GB | 1,008 GB/s | ~$1,800 | **Skip** — same VRAM as 3090, only ~8% faster tok/s, no new model access |
| RTX 5090 | 32GB GDDR7 | 1,792 GB/s | ~$4,100 | **Recommended if upgrading** — unlocks 70B Q2_K (~26GB); all models ~2× faster |
| AMD RDNA 4 (RX 9070 XT) | 16GB | — | — | **Skip** — 16GB max in RDNA 4 lineup; no 24GB+ variant available; Ollama support experimental |
| AMD Radeon PRO W7900 | 48GB | 864 GB/s | ~$4,582 | **Not recommended** — more expensive than RTX 5090, slower bandwidth, ROCm ecosystem |

> **RTX 5090 unlocks:** qwen3:32b-q4_K_M at ~50–70 tok/s (2× faster than 3090), and 70B Q2_K (~26GB) fits in 32GB for the first time. The RTX 4090 is a dead-end upgrade — skip it entirely and go directly to RTX 5090 if upgrading.

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
