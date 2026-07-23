---
---
# 07 — eGPU Setup (RTX 3090 via OCuLink)

[← Docker & Homelab](06-docker-homelab.md) | [Next: Tailscale →](08-tailscale-remote-access.md)

---

{% include guide-toc.html %}

## Overview

This guide migrates from Phase 1 (780M iGPU in Ollama VM) to Phase 2 (RTX 3090 via OCuLink eGPU dock). The process:

1. Update Proxmox VFIO binding to claim the RTX 3090 (releases iGPU back to host)
2. Destroy and rebuild the Ollama VM with NVIDIA drivers
3. Add RTX 3090 as PCI passthrough to the new VM
4. Verify CUDA and Ollama GPU detection

The iGPU automatically returns to the Proxmox host when its VFIO binding is removed — Plex hardware transcoding becomes available after the reboot in step 7.2.

---

## Prerequisites

- DEG1 dock assembled with RM850x PSU and RTX 3090 installed ([Hardware Assembly §3](01-hardware-assembly.md))
- Proxmox IOMMU configured ([Proxmox Installation §2.5](02-proxmox-installation.md))
- Phase 1 Ollama VM running and confirmed working
- All VMs and LXCs in a known-good state (take a Proxmox snapshot if desired)

---

## 7.1 Identify the RTX 3090 PCI IDs

Power on the DEG1 before the UM890 Pro (always). In the Proxmox shell:

```bash
lspci -nn | grep -i nvidia
```

You will see two NVIDIA entries — the RTX 3090 video and audio functions. Note the PCI IDs in brackets:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3090] [10de:2204]
01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef]
```

Standard RTX 3090 IDs are `10de:2204` and `10de:1aef` — confirm yours match.

---

## 7.2 Update VFIO Binding to RTX 3090

Edit `/etc/modprobe.d/vfio.conf` (created in [Proxmox Installation §2.5](02-proxmox-installation.md)):

```bash
vim /etc/modprobe.d/vfio.conf
```

Replace the iGPU IDs with the RTX 3090 IDs:

```
options vfio-pci ids=10de:2204,10de:1aef
```

Update initramfs and reboot:

```bash
update-initramfs -u -k all
reboot
```

After reboot, verify the RTX 3090 is bound to vfio-pci:

```bash
lspci -nnk | grep -A3 "GA102"
```

Look for `Kernel driver in use: vfio-pci`

The 780M iGPU is now free — verify it's claimed by amdgpu on the host:

```bash
lspci -nnk | grep -A3 "Hawk Point"
```

Look for `Kernel driver in use: amdgpu`. Plex hardware transcoding is now available.

---

## 7.3 Rebuild the Ollama VM

The Phase 1 VM has ROCm installed. Rather than converting it, destroy and recreate it cleanly with the NVIDIA stack.

**Shut down VM 101 first**, then in Proxmox web UI:

**VM 101 → More → Destroy**

Create a new VM 101 with identical specs:

In Proxmox web UI: **Create VM**

| Setting | Value |
|---|---|
| VM ID | `101` |
| Name | `ollama` |
| OS | Ubuntu 24.04 Server (re-use the ISO already downloaded, or re-download) |
| Machine | `q35` |
| CPU | 4 cores |
| RAM | `14336` MB (14GB) |
| Disk | `60GB` (on local-lvm) |
| Network | `vmbr0` |

After creating — **before starting** — add the RTX 3090 as a PCI passthrough device:

**VM 101 → Hardware → Add → PCI Device**

| Setting | Value |
|---|---|
| Raw device | Select the RTX 3090 (identified by `10de:2204`) |
| All Functions | ✅ Checked |
| ROM-Bar | ✅ Checked |
| PCI-Express | ✅ Checked |

Start the VM and install Ubuntu 24.04 Server (minimal install, OpenSSH enabled, hostname `ollama`, user `aiuser`).

---

## 7.4 Install NVIDIA Drivers

SSH into the new Ollama VM:

```bash
ssh aiuser@<ollama-vm-ip>
```

Install NVIDIA drivers:

```bash
sudo apt update
sudo ubuntu-drivers autoinstall
sudo reboot
```

After reboot, verify the RTX 3090 is detected:

```bash
nvidia-smi
```

Expected output: RTX 3090 listed with 24576 MiB VRAM, driver version, CUDA version.

---

## 7.5 Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Configure Ollama to listen on all interfaces (required for Open WebUI and Home Assistant):

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify Ollama detects the GPU:

```bash
ollama run qwen3:8b-q4_K_M "say hello"
```

In a second terminal:

```bash
watch -n 1 nvidia-smi
```

GPU memory usage should climb during inference. If Ollama falls back to CPU despite nvidia-smi showing the GPU, check Ollama logs:

```bash
journalctl -u ollama -n 50
```

---

## 7.6 Install Open WebUI

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker aiuser
# Log out and back in

# Run Open WebUI
docker run -d \
  --name open-webui \
  --restart always \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://localhost:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

---

## 7.7 Pull and Test 32B Model

```bash
ollama pull qwen3-coder:30b-a3b-q4_K_M
ollama run qwen3-coder:30b-a3b-q4_K_M "explain the difference between a mutex and a semaphore"
```

Expected performance: **~40–50 tok/s** with the model fully loaded in 24GB VRAM.

Monitor in real time:

```bash
watch -n 1 nvidia-smi
```

GPU memory should show ~19–20GB allocated for the 32B model.

---

## Performance Reference

| Model | VRAM used | tok/s |
|---|---|---|
| 7B Q4_K_M | ~4.5 GB | ~75–90 |
| 14B Q4_K_M | ~9 GB | ~55–65 |
| 32B Q4_K_M | ~19 GB | ~40–50 |

---

## Troubleshooting

**RTX 3090 not visible in VM:**
- Confirm `lspci -nnk | grep -A3 "GA102"` shows `vfio-pci` on the host
- Confirm All Functions and PCI-Express are checked in VM hardware settings
- Check IOMMU group — both RTX 3090 entries must be in the same group with no other devices

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done | grep "GA102"
```

**"NVRM: GPU-XXXXX lost" in dmesg:**
OCuLink connection issue. Power off everything, reseat the OCuLink cable, power DEG1 first then the mini PC.

**nvidia-smi shows GPU but Ollama uses CPU:**
```bash
journalctl -u ollama -n 50 | grep -i cuda
# If CUDA library not found:
sudo apt install nvidia-cuda-toolkit
sudo systemctl restart ollama
```

**iGPU not returning to host after reboot:**
Confirm `/etc/modprobe.d/vfio.conf` no longer contains the iGPU IDs. Run `update-initramfs -u -k all` and reboot again.

---

[← Docker & Homelab](06-docker-homelab.md) | [Next: Tailscale →](08-tailscale-remote-access.md)
