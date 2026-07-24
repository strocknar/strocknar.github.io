---
---
# 04 — Ollama + Open WebUI

[← Home Assistant VM](03-home-assistant-vm.md) | [Next: Voice Stack →](05-voice-stack.md)

---

{% include guide-toc.html %}

## Architecture

Ollama (model backend) and Open WebUI (chat interface) run in a dedicated Proxmox VM. The 780M iGPU is passed through via VFIO for Phase 1, then the VM is destroyed and rebuilt with NVIDIA drivers for Phase 2.

**Phase 1 (iGPU):** The 780M iGPU is passed through to this VM from Proxmox. Ollama uses it via ROCm. With 8GB UMA, `qwen3:8b` fits fully on GPU. Generation speed is functional for Home Assistant voice responses, but too slow (~1–2 tok/s on larger models, ~5–8 tok/s on 8B) to use Open WebUI as a day-to-day ChatGPT replacement — that experience requires the eGPU.

**Phase 2 (RTX 3090):** Destroy and rebuild this VM (see [eGPU Setup](07-egpu-setup.md)). NVIDIA drivers replace ROCm. Full 32B capability at ~25–35 tok/s. Open WebUI becomes genuinely usable as a local alternative to cloud LLMs.

### Phase 1 Resource Reality

The iGPU shares system RAM as VRAM. With 32GB total:

| UMA VRAM | Ollama VM RAM | Free for HA + LXCs | GPU fits |
|---|---|---|---|
| 8GB | 8GB | ~14GB | qwen3:8b (5.2GB) — HA voice |
| 16GB | 12GB | ~2GB | qwen3:14b (9.3GB) — barely anything left |

**Phase 1 recommendation: 8GB UMA, 8GB Ollama VM RAM.** This frees ~14GB for Home Assistant, LXC services (NPM, Tailscale, etc.), and future experimentation. The tradeoff is giving up the 14B model — but on Phase 1 hardware, the 14B at interactive speed isn't meaningfully better than the 8B for HA voice tasks, and Open WebUI is too slow to be useful for either anyway.

> **Why not 14B on Phase 1?** Real-world testing: qwen3:14b-q4_K_M is tolerable but slow for HA voice. devstral (14GB) hits 1–2 tok/s with 37% CPU / 63% GPU — not enough VRAM to go fully GPU-resident. qwen3:8b hallucinates more than 14B but is fast enough for short HA commands. The 14B sweet spot is Phase 2, where it becomes genuinely fast.

> **Ollama loads through RAM:** During model load, Ollama spikes to ~model-size in system RAM before transferring weights to VRAM. 8GB VM RAM is tight for the 5.2GB 8B model but workable — especially with `OLLAMA_KEEP_ALIVE=-1` set, which means load only happens on VM reboot.

---

## 4.1 Create the Ollama VM

### Download Ubuntu ISO

In Proxmox web UI: **Datacenter → <Name> → local → ISO Images → Download from URL**

URL: `https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso`

Click `Query URL` to fill in the other fields and then click Download

### Create New VM

In Proxmox web UI: **Create VM**

| Setting | Value |
|---|---|
| VM ID | `101` |
| Name | `ollama` |
| OS | Ubuntu 24.04 Server (download ISO first — see below) |
| Machine | `q35` |
| CPU | 4 cores |
| RAM | `8192` MB (8GB) — see Phase 1 Resource Reality above |
| Disk | `60GB` (on local-lvm) |
| Network | `vmbr0` |

### Add iGPU Passthrough to VM

After creating the VM but **before starting it**, add the 780M iGPU as a PCI passthrough device:

In Proxmox web UI: **VM 101 → Hardware → Add → PCI Device**

| Setting | Value |
|---|---|
| Raw device | Select the 780M iGPU (identified by `1002:1900`) |
| All Functions | ❌ Unchecked |
| ROM-Bar | ✅ Checked |
| PCI-Express | ✅ Checked |

> **"All Functions" must be unchecked.** On the UM890 Pro, the iGPU video (`1002:1900`) and audio (`1002:1640`) land in separate IOMMU groups. Checking All Functions tells Proxmox to pass through both groups simultaneously, which violates IOMMU isolation and panics the host. The audio function is not needed for GPU compute.

> ROM-Bar and PCI-Express may be under Advanced.

Now start the VM and proceed with Ubuntu installation.

### Install Ubuntu

Start the VM, open the console, follow the Ubuntu Server installer:
- Minimal install (no desktop)
- Enable OpenSSH server
- Set hostname: `ollama`
- Create a non-root user (e.g., `aiuser`)
- Note the VM's IP address after install

---

## 4.2 Install ROCm

SSH into the Ollama VM:

```bash
ssh aiuser@<ollama-vm-ip>
```

Add the universe repository first: 

```bash
sudo add-apt-repository universe
sudo apt update
```

Make sure to have disk space available. When installing, Ubuntu 26 by default adds storage to a LVM but only puts about half of the available space into it. 

> For my initial install of Ubuntu + ROCm + Ollama, it took about 36GB before the models.
> With 4 models + OpenWebUI container: ~92G

```bash
sudo lvdisplay
sudo lvextend -r -l +100%FREE /dev/your_vol_group/your_log_vol # e.g. /dev/ubuntu-vg/ubuntu-lv
```

Install ROCm (AMD's GPU compute stack, required for Ollama to use AMD GPUs):

```bash
# Add AMD ROCm apt repository for Ubuntu 26.04 (Resolute Raccoon)
wget https://repo.amd.com/rocm/rocm.gpg.key -O - | sudo gpg --dearmor -o /etc/apt/keyrings/amdrocm.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://repo.amd.com/rocm/packages-multi-arch/ubuntu2604 stable main" \
  | sudo tee /etc/apt/sources.list.d/amdgpu-rocm.list
sudo apt update
sudo apt install -y rocm
sudo usermod -a -G render,video aiuser
sudo usermod -a -G render,video ollama
```

> **Why apt instead of amdgpu-install?** As of ROCm 7.14.0, AMD's primary install method is the native apt package manager. The `amdgpu-install` .deb tool is now described as "legacy" in ROCm docs, and Ubuntu 26.04 is not in the amdgpu-install repo (only noble/jammy are). On Ryzen APUs with iGPU passthrough, the inbox kernel driver is used — no DKMS module is needed. ROCm userspace only is the correct install for this setup.

Log out and back in for group changes to take effect on your interactive session. The `ollama` service user change takes effect on the next service restart.

Verify ROCm sees a GPU:

```bash
rocm-smi
```

> **Phase 1 (iGPU passthrough):** The 780M (gfx1103) is RDNA 3 mobile. ROCm 7.14.0 lists gfx1103 in the compatibility matrix but without formal support guarantees — it is functional for this use case. `HSA_OVERRIDE_GFX_VERSION=11.0.0` and `OLLAMA_IGPU_ENABLE=1` are required — both are included in the service config block above. Check `https://rocm.docs.amd.com` for gfx1103 support status.

> **UMA VRAM constraint:** UMA size and VM RAM must be balanced — see the BIOS configuration section in [Hardware Assembly](01-hardware-assembly.md). With 16G UMA and the VM reduced to ~12GB RAM, `qwen3:14b` (9.3GB) fits fully on GPU. With 8G UMA and 14GB VM RAM, only `qwen3:8b` fits on GPU and the 14B falls back to CPU.

---

## 4.3 Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Verify installation:

```bash
ollama --version
```

### Configure Ollama to Listen on All Interfaces

By default Ollama only listens on localhost. Open WebUI (and HA) need to reach it:

```bash
sudo systemctl edit ollama
```

Add:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="OLLAMA_IGPU_ENABLE=1"
Environment="OLLAMA_KEEP_ALIVE=-1"
```

> `OLLAMA_KEEP_ALIVE=-1` keeps the loaded model in memory indefinitely instead of unloading after 5 minutes. On Phase 1 hardware, cold-start load times are 90 seconds to 5+ minutes depending on model size — unloading between requests makes the system feel broken. Set this from the start.

Save and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 4.4 Pull Your First Models

All are Q4_K_M quantizations — the standard Ollama default for best quality/size tradeoff.

```bash
# Phase 1: 8B is the only model that fits fully on GPU with 8GB UMA
ollama pull qwen3:8b-q4_K_M

# Phase 2: pull these after the RTX 3090 rebuild
ollama pull qwen3:14b-q4_K_M
ollama pull qwen3:32b-q4_K_M          # primary coding assistant (~20GB, ~25-35 tok/s)
ollama pull qwen3-coder:30b-a3b-q4_K_M  # alternative: MoE coding model (256K context)
```

> Models are stored in `~/.ollama/models` by default. On a 1TB drive, you have room for several models. Use `ollama rm <model>` to remove ones you're not using.

> **Qwen3 thinking mode:** Qwen3 models support an optional reasoning/chain-of-thought mode. For Home Assistant voice and quick queries, suppress it by prefixing your prompt with `/no_think`. Full thinking mode is useful for complex coding tasks but adds significant latency — on Phase 1 hardware, don't use it.

### Model Reference

| Model | Size | Phase | Notes |
|---|---|---|---|
| `qwen3:8b-q4_K_M` | ~5.2GB | 1 + 2 | HA LLM agent; hallucinates more than 14B but fast enough for short commands |
| `qwen3:14b-q4_K_M` | ~9.3GB | 2 | Sweet spot for daily use; Phase 1 speed is tolerable but not enjoyable |
| `qwen3:32b-q4_K_M` | ~20GB | 2 | **Primary coding assistant**; dense model, ~25–35 tok/s on RTX 3090 |
| `qwen3-coder:30b-a3b-q4_K_M` | ~19GB | 2 | Coding alternative (MoE, 256K context); 3B active params per token |
| `devstral:24b-small-2505-q4_K_M` | ~14GB | 2 | Pure coding agent; 1–2 tok/s on Phase 1 iGPU — unusable until RTX 3090 |

---

## 4.5 Install Open WebUI

Open WebUI provides a ChatGPT-style interface backed by your local Ollama instance.

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker aiuser
# Log out and back in

# Run Open WebUI
# Replace <ollama-vm-ip> with this VM's IP (run: hostname -I | awk '{print $1}')
docker run -d \
  --name open-webui \
  --restart always \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://<ollama-vm-ip>:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

Access from your browser:

```
http://<ollama-vm-ip>:3000
```

Create your admin account on first visit.

---

## 4.6 Test Inference

In Open WebUI, select a model from the dropdown and send a message. Verify:

- Response generates (even slowly on CPU is fine for Phase 1)
- No error messages in the UI

Check GPU utilization during inference:

```bash
# Phase 1 (iGPU via ROCm):
watch -n 1 rocm-smi

# Phase 2 (RTX 3090 via CUDA — after VM rebuild):
watch -n 1 nvidia-smi
```

GPU memory usage should increase as the model runs.

---

## 4.7 Connect Ollama to Home Assistant

In HA web UI: **Settings → Devices & Services → Add Integration → Ollama**

- **URL:** `http://<ollama-vm-ip>:11434`
- **Model:** Select `qwen3:8b-q4_K_M` (or whichever model you want HA to use — prefer the 8B for low-latency voice responses)

This enables Ollama as the conversation agent for voice commands and automations.

---

## 4.8 Customize the Model's Personality (System Prompt)

Open WebUI lets you set a persistent system prompt that applies to every conversation — the equivalent of a `~/.claude/CLAUDE.md` for your local models.

### Per-account default (recommended)

In Open WebUI: **Settings → General → System Prompt**

Paste your prompt here. It applies to all models for your account unless overridden at a lower level.

### Priority order (highest wins)

| Level | Where | Who can set |
|---|---|---|
| Per-model | Workspace → Models → System Prompt | Admin only |
| Per-account | Settings → General → System Prompt | Any user |
| Per-chat | Chat Controls sidebar | Any user |

> **Admin note:** If you set a system prompt on a model in Workspace → Models, it locks out the per-account override — users cannot change it for that model. Leave it blank in Workspace if you want users to control their own defaults.

### Alternative: Ollama Modelfile

If you want the system prompt baked into the model itself (CLI, API, and WebUI all inherit it):

```bash
# Create a Modelfile
cat > ~/Modelfile <<'EOF'
FROM qwen3:14b-q4_K_M

SYSTEM """
Your system prompt here.
"""
EOF

# Register as a named model
ollama create qwen3-14b-custom -f ~/Modelfile
```

The custom model then appears in Open WebUI's model dropdown like any other model.

---

## Useful Ollama Commands

```bash
ollama list                    # list installed models
ollama ps                      # show running models
ollama rm <model>              # delete a model
ollama pull <model>            # download a model
ollama run <model>             # interactive CLI chat
```

---

[← Home Assistant VM](03-home-assistant-vm.md) | [Next: Voice Stack →](05-voice-stack.md)
