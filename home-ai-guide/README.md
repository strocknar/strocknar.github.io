# Home AI & Homelab Build Guide

A complete start-to-finish guide for building a local AI system with Home Assistant, local LLM inference, and a self-hosted homelab stack.

## Hardware

### Option A — Budget Start (UM890 Pro Refurb)

| Component | Model | Price |
|---|---|---|
| Mini PC | Minisforum UM890 Pro refurb (Ryzen 9 8945HS) | $383 |
| RAM | Crucial 32GB Dual Channel DDR5-5600 (2×16GB) | $382–$390 |
| NVMe | WD Black SN770 1TB | $175–$210 |
| **Phase 1 Total** | | **$940–$983** |
| eGPU Dock | Minisforum DEG1 (OCuLink PCIe 4.0 x4) | $109 |
| PSU | Corsair RM850x 850W ATX | $129.99 |
| GPU | RX 7900 XTX 24GB (new) **or** RTX 3090 24GB (used) | $700–$1,050 |
| **Full Build Total** | | **$1,879–$2,272** |

> RAM and NVMe move directly to the AI X1 Pro-470 if you upgrade later — no components stranded.

### Option B — Full Build (AI X1 Pro-470)

| Component | Model | Price |
|---|---|---|
| Mini PC | Minisforum AI X1 Pro-470 (Ryzen AI 9 HX470) | $759 |
| RAM | Crucial 32GB Dual Channel DDR5-5600 (2×16GB) | $382–$390 |
| NVMe | WD Black SN770 1TB | $175–$210 |
| eGPU Dock | Minisforum DEG1 (OCuLink PCIe 4.0 x4) | $109 |
| PSU | Corsair RM850x 850W ATX | $129.99 |
| GPU | RX 7900 XTX 24GB (new) **or** RTX 3090 24GB (used) | $700–$1,050 |
| **Total** | | **$2,255–$2,648** |

> **Phase 1 (no eGPU):** $1,316–$1,359 — fully functional for HA and 7B–13B LLM inference  
> **Phase 2:** Add eGPU stack when ready (+$1,268–$1,289)

## Sections

1. [Hardware Assembly](01-hardware-assembly.md)
2. [Proxmox Installation](02-proxmox-installation.md)
3. [Home Assistant VM](03-home-assistant-vm.md)
4. [Ollama + Open WebUI](04-ollama-open-webui.md)
5. [Home Assistant Voice Stack](05-voice-stack.md)
6. [Docker & Homelab Services](06-docker-homelab.md)
7. [eGPU Setup](07-egpu-setup.md)
8. [Remote Access with Tailscale](08-tailscale-remote-access.md)
9. [Storage: External SSDs](09-external-storage.md)
10. [Web Search Integration](10-web-search.md)
11. [Upgrading & Future Expansion](11-upgrading.md)
12. [Local Image Generation (ComfyUI + FLUX)](12-image-generation.md)
13. [Devices & Home Assistant Compatibility](13-devices.md)

## Architecture Overview

```
Proxmox VE (bare metal, Debian-based)
├── VM:  Home Assistant OS        (4GB RAM, 32GB disk, iGPU for voice)
├── VM:  Ollama + Open WebUI      (14GB RAM, RX 7900 XTX passthrough)
│   └── ComfyUI                   (image generation, shares RX 7900 XTX)
├── LXC: Docker host              (6GB RAM, homelab containers)
│   ├── SearXNG                   (web search)
│   ├── Grafana                   (monitoring)
│   ├── Nginx Proxy Manager       (reverse proxy + HTTPS)
│   └── Portainer                 (Docker management UI)
├── LXC: Plex Media Server        (2GB RAM, iGPU for transcoding)
└── Tailscale                     (installed on Proxmox host)
```

## Quick Reference

- **Proxmox web UI:** `https://<host-ip>:8006`
- **Home Assistant:** `http://<haos-vm-ip>:8123`
- **Open WebUI:** `http://<ollama-vm-ip>:3000`
- **Portainer:** `http://<docker-lxc-ip>:9000`
- **Grafana:** `http://<docker-lxc-ip>:3001`

## LLM Performance Reference

| Phase | Hardware | GPU | 7B tok/s | 13B tok/s | 32B tok/s |
|---|---|---|---|---|---|
| Phase 1 (Option A) | UM890 Pro | 780M iGPU | ~15–18 | ~8–10 | ~3–5 |
| Phase 1 (Option B) | AI X1 Pro-470 | 890M iGPU | ~20–25 | ~10–14 | ~3–5 |
| Phase 2 — AMD | + RX 7900 XTX | eGPU | ~80+ | ~60+ | ~45–55 |
| Phase 2 — NVIDIA | + RTX 3090 (used) | eGPU | ~75–90 | ~55–65 | ~40–50 |

> See [eGPU Setup](07-egpu-setup.md) for a full GPU comparison including RTX 3090 vs RX 7900 XTX tradeoffs under Proxmox.
