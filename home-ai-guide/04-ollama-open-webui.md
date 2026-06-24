# 04 — Ollama + Open WebUI

[← Home Assistant VM](03-home-assistant-vm.md) | [Next: Voice Stack →](05-voice-stack.md)

---

## Architecture

Ollama (model backend) and Open WebUI (chat interface) run in a dedicated Proxmox VM. The 780M iGPU is passed through via VFIO for Phase 1, then the VM is destroyed and rebuilt with NVIDIA drivers for Phase 2.

**Phase 1 (iGPU):** The 780M iGPU is passed through to this VM from Proxmox. Ollama uses it via ROCm. Functional for 7B–14B models at ~15–18 tok/s on 7B.  
**Phase 2 (RTX 3090):** Destroy and rebuild this VM (see [eGPU Setup](07-egpu-setup.md)). NVIDIA drivers replace ROCm. Full 32B capability at ~40–50 tok/s.

---

## 4.1 Create the Ollama VM

In Proxmox web UI: **Create VM**

| Setting | Value |
|---|---|
| VM ID | `101` |
| Name | `ollama` |
| OS | Ubuntu 24.04 Server (download ISO first — see below) |
| Machine | `q35` |
| CPU | 4 cores |
| RAM | `14336` MB (14GB) |
| Disk | `60GB` (on local-lvm) |
| Network | `vmbr0` |

### Download Ubuntu ISO

In Proxmox web UI: **local storage → ISO Images → Download from URL**

URL: `https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso`

### Add iGPU Passthrough to VM

After creating the VM but **before starting it**, add the 780M iGPU as a PCI passthrough device:

In Proxmox web UI: **VM 101 → Hardware → Add → PCI Device**

| Setting | Value |
|---|---|
| Raw device | Select the 780M iGPU (identified by `1002:1900`) |
| All Functions | ✅ Checked |
| ROM-Bar | ✅ Checked |
| PCI-Express | ✅ Checked |

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

Install ROCm (AMD's GPU compute stack, required for Ollama to use AMD GPUs):

```bash
# Check https://repo.radeon.com/amdgpu-install/ for the latest version directory, then:
wget https://repo.radeon.com/amdgpu-install/<version>/ubuntu/noble/amdgpu-install_<version>-1_all.deb
sudo apt install ./amdgpu-install_<version>-1_all.deb
sudo amdgpu-install --usecase=rocm --no-dkms
sudo usermod -a -G render,video aiuser
```

Log out and back in for group changes to take effect.

Verify ROCm sees a GPU:

```bash
rocm-smi
```

> **Phase 1 (iGPU passthrough):** The 780M (gfx1103) is RDNA 3 mobile. ROCm support is functional but not tier-1. If `rocm-smi` shows no GPU or GFX version errors, set `HSA_OVERRIDE_GFX_VERSION=11.0.0` by running `sudo systemctl edit ollama` and adding `Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"` to the `[Service]` block, then `sudo systemctl daemon-reload && sudo systemctl restart ollama`. Check `https://rocm.docs.amd.com` for gfx1103 support status.

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
```

Save and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 4.4 Pull Your First Models

```bash
# 7B — fast, good for HA assistant
ollama pull qwen2.5-coder:7b

# 14B — balanced quality/speed (iGPU phase)
ollama pull qwen2.5-coder:14b

# 32B — primary coding assistant (requires eGPU for good performance)
ollama pull qwen2.5-coder:32b
```

> Models are stored in `~/.ollama/models` by default. On a 1TB drive, you have room for several models. Use `ollama rm <model>` to remove ones you're not using.

### Useful Models Reference

| Model | Size | Best for |
|---|---|---|
| `qwen2.5-coder:7b` | ~4.5GB | HA LLM agent, quick queries |
| `qwen2.5-coder:14b` | ~9GB | Daily coding, Phase 1 |
| `qwen2.5-coder:32b` | ~19GB | Primary coding assistant, Phase 2 |
| `llama3.1:8b` | ~5GB | General Q&A |
| `mistral:7b` | ~4.5GB | Fast general use |

---

## 4.5 Install Open WebUI

Open WebUI provides a ChatGPT-style interface backed by your local Ollama instance.

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
- **Model:** Select `qwen2.5-coder:7b` (or whichever model you want HA to use)

This enables Ollama as the conversation agent for voice commands and automations.

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
