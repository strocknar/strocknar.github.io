# 07 — eGPU Setup (RX 7900 XTX via OCuLink)

[← Docker & Homelab](06-docker-homelab.md) | [Next: Tailscale →](08-tailscale-remote-access.md)

---

## GPU Options

This guide uses the RX 7900 XTX as the primary GPU. The RTX 3090 (used) is a legitimate alternative — see the comparison below before purchasing.

### RX 7900 XTX vs RTX 3090

| | RX 7900 XTX (new) | RTX 3090 (used) |
|---|---|---|
| Price | ~$1,029–$1,050 | ~$700–850 |
| VRAM | 24 GB GDDR6 | 24 GB GDDR6X |
| Memory bandwidth | ~960 GB/s | ~936 GB/s |
| 32B tok/s | ~45–55 | ~40–50 |
| Ecosystem | ROCm | **CUDA — best in class** |
| Ollama stability | ⚠️ ROCm maintenance | ✅ Just works |
| ComfyUI custom nodes | ⚠️ Many CUDA-only | ✅ Native |
| Warranty | ✅ New | ❌ None (used) |
| Age | Current gen | 2020 (6 years) |

**Why NVIDIA + Proxmox works cleanly despite the Linux eGPU reputation:**
Proxmox binds the eGPU to `vfio-pci` at the hypervisor level before any GPU driver loads. The Ollama VM sees it as a native PCIe device — NVIDIA drivers inside the VM behave identically to bare metal. The unreliable Linux eGPU experience is a bare-metal problem only.

The 780M iGPU binds to `amdgpu` on the Proxmox host (for Plex). The RTX 3090 binds to `vfio-pci` and passes through to the Ollama VM where only the `nvidia` driver runs. The two drivers never coexist on the same OS layer.

**Choose RX 7900 XTX if:** you want new hardware with a warranty and are comfortable maintaining ROCm.  
**Choose RTX 3090 if:** you find a clean used unit from a reputable seller at $700–800 and want CUDA's superior ecosystem for Ollama and ComfyUI.

> If using an RTX 3090, substitute `nvidia-smi` for `rocm-smi`, skip the ROCm install steps, and install NVIDIA drivers in the Ollama VM instead. The Proxmox VFIO passthrough steps are identical for both GPUs.

---

## Prerequisites

- DEG1 dock assembled with PSU and GPU installed ([Hardware Assembly §3](01-hardware-assembly.md))
- Proxmox IOMMU configured ([Proxmox Installation §2.5](02-proxmox-installation.md))
- Proxmox rebooted with IOMMU active

---

## 7.1 Identify the GPU's PCI IDs

Power on the DEG1 before the UM890 Pro (always). In the Proxmox shell:

```bash
lspci -nn | grep -i amd
```

You will see two AMD entries — the 780M iGPU and the 7900 XTX. Identify the XTX by its device name. Note the PCI ID in brackets, e.g.:

```
01:00.0 VGA compatible controller [0300]: Advanced Micro Devices [AMD/ATI] Navi 31 [1002:744c]
01:00.1 Audio device [0403]: Advanced Micro Devices [AMD/ATI] Navi 31 HDMI/DP Audio [1002:ab30]
```

Your IDs will be: `1002:744c` and `1002:ab30` (these are the standard 7900 XTX IDs — confirm yours match).

---

## 7.2 Bind the XTX to VFIO (Not the iGPU)

Create a targeted VFIO binding using the XTX's specific device IDs:

```bash
nano /etc/modprobe.d/vfio.conf
```

```
options vfio-pci ids=1002:744c,1002:ab30
```

> Use the IDs from step 7.1. This binds only the XTX to VFIO, leaving the 780M iGPU available for Proxmox and the Plex LXC.

Update initramfs and reboot:

```bash
update-initramfs -u -k all
reboot
```

After reboot, verify the XTX is bound to vfio-pci:

```bash
lspci -nnk | grep -A3 "Navi 31"
```

Look for `Kernel driver in use: vfio-pci`

---

## 7.3 Add XTX to Ollama VM

In Proxmox web UI — **shut down the Ollama VM first**, then:

**VM 101 (ollama) → Hardware → Add → PCI Device**

| Setting | Value |
|---|---|
| Raw device | Select the XTX from the list |
| All Functions | ✅ Checked (captures both video and audio PCI functions) |
| ROM-Bar | ✅ Checked |
| PCI-Express | ✅ Checked |

Start the Ollama VM.

---

## 7.4 Verify GPU in Ollama VM

SSH into the Ollama VM:

```bash
ssh aiuser@<ollama-vm-ip>
lspci | grep -i amd
```

The 7900 XTX should appear. Verify ROCm sees it:

```bash
rocm-smi
```

Expected: XTX listed with 24GB VRAM, GPU utilization at 0%.

---

## 7.5 Configure Ollama for ROCm

Ollama's ROCm build auto-detects AMD GPUs. Verify it is using the GPU:

```bash
ollama run qwen2.5-coder:7b "say hello"
```

In a second terminal, watch GPU usage:

```bash
watch -n 1 rocm-smi
```

GPU memory usage should climb to ~4.5GB for 7B and GPU utilization should spike during inference.

If Ollama falls back to CPU despite the GPU being visible, set the device explicitly:

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
```

> `HSA_OVERRIDE_GFX_VERSION` may be needed if ROCm doesn't auto-detect the XTX's GFX version. `11.0.0` covers RDNA 3 (gfx1100).

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 7.6 Pull and Test 32B Model

```bash
ollama pull qwen2.5-coder:32b
ollama run qwen2.5-coder:32b "explain the difference between a mutex and a semaphore"
```

Expected performance: **~45–55 tok/s** with the model fully loaded in 24GB VRAM.

Monitor in real time:

```bash
# In second terminal
watch -n 1 rocm-smi
```

GPU memory should show ~19–20GB allocated for the 32B model.

---

## 7.7 ROCm Troubleshooting

**GPU detected but inference runs on CPU:**
```bash
# Check if amdgpu module loaded in VM
lsmod | grep amdgpu

# If missing, install amdgpu kernel module
sudo amdgpu-install --usecase=rocm
sudo reboot
```

**"HSA_STATUS_ERROR_INVALID_ISA" error:**
```bash
# Add to /etc/systemd/system/ollama.service.d/override.conf
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
```

**GPU not visible in VM at all:**
- Confirm IOMMU group — the XTX must be in its own group or with only its own audio function
- Check that vfio-pci is bound (step 7.2)
- Confirm PCI-Express is checked in VM hardware settings

**Check IOMMU group isolation:**
```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done | grep "Navi 31"
```

Both XTX entries (video + audio) should be in the same group with no other devices. If other devices share the group, passthrough may fail — this is an AMD platform IOMMU grouping issue. Some boards allow ACS override patches; research for your specific Proxmox version.

---

## Performance After eGPU

| Model | VRAM used | tok/s |
|---|---|---|
| 7B Q4_K_M | ~4.5 GB | ~80–100 |
| 13B Q4_K_M | ~8.5 GB | ~55–70 |
| 32B Q4_K_M | ~19 GB | ~45–55 |

---

[← Docker & Homelab](06-docker-homelab.md) | [Next: Tailscale →](08-tailscale-remote-access.md)
