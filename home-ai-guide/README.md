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
| GPU | RTX 3090 24GB (used) | ~$700–850 |
| **Full Build Total** | | **$1,879–$2,072** |

> RAM and NVMe move directly to the AI X1 Pro-470 if you upgrade later — no components stranded.

### Option B — Full Build (AI X1 Pro-470)

| Component | Model | Price |
|---|---|---|
| Mini PC | Minisforum AI X1 Pro-470 (Ryzen AI 9 HX470) | $759 (sale) / $949 (regular) |
| RAM | Crucial 32GB Dual Channel DDR5-5600 (2×16GB) | $382–$390 |
| NVMe | WD Black SN770 1TB | $175–$210 |
| eGPU Dock | Minisforum DEG1 (OCuLink PCIe 4.0 x4) | $109 |
| PSU | Corsair RM850x 850W ATX | $129.99 |
| GPU | RTX 3090 24GB (used) | ~$700–850 |
| **Total** | | **$2,255–$2,448** |

> **Phase 1 (no eGPU):** $1,316–$1,359 — fully functional for HA and 7B–14B LLM inference  
> **Phase 2:** Add eGPU stack when ready (+$939–$1,089)

## Sections

1. [Hardware Assembly](01-hardware-assembly.md)
2. [Proxmox Installation](02-proxmox-installation.md)
3. [External Storage](03-external-storage.md)
4. [Docker & Homelab Services](04-docker-homelab.md)
5. [Nginx Proxy Manager](05-nginx-proxy-manager.md)
6. [Plex LXC](06-plex-lxc.md)
7. [Samba Network Shares](07-samba.md)
8. [Home Assistant VM](08-home-assistant-vm.md)
9. [Ollama + Open WebUI](09-ollama-open-webui.md)
10. [Home Assistant Voice Stack](10-voice-stack.md)
11. [eGPU Setup](11-egpu-setup.md)
12. [Remote Access with Tailscale](12-tailscale-remote-access.md)
13. [Web Search Integration](13-web-search.md)
14. [Upgrading & Future Expansion](14-upgrading.md)
15. [Local Image Generation (ComfyUI + FLUX)](15-image-generation.md)
16. [Devices & Home Assistant Compatibility](16-devices.md)
17. [Voice Satellites](17-voice-satellites.md)
18. [Local Coding Assistant](18-coding-assistant.md)
19. [Inference Backends](19-inference-backends.md)

## Architecture Overview

```
Proxmox VE (bare metal, Debian-based)
├── VM:  Home Assistant OS        (4GB RAM, 32GB disk)
├── VM:  Ollama + Open WebUI      (14GB RAM, iGPU Phase 1 / RTX 3090 Phase 2)
│   └── ComfyUI                   (image generation, Phase 2 only)
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

| Phase | Hardware | GPU | 7B tok/s | 14B tok/s | 32B tok/s |
|---|---|---|---|---|---|
| Phase 1 (Option A) | UM890 Pro | 780M iGPU | ~15–18 | ~8–10 | ~3–5 |
| Phase 1 (Option B) | AI X1 Pro-470 | 890M iGPU | ~20–25 | ~10–14 | ~3–5 |
| Phase 2 | + RTX 3090 (used) | eGPU | ~75–90 | ~55–65 | ~25–35 |

> Phase 2 32B model is `qwen3:32b-q4_K_M` (~20GB). Tok/s is memory-bandwidth-bound on RTX 3090 (936 GB/s). See [eGPU Setup](11-egpu-setup.md) for the complete Phase 2 setup process.
