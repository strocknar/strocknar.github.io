# 12 — Local Image Generation (ComfyUI + FLUX)

[← Upgrading](11-upgrading.md) | [← Overview](README.md)

---

## Architecture

Image generation runs in the same Ollama VM where the RTX 3090 lives. ComfyUI serves as the backend; Open WebUI connects to it for chat-integrated image generation.

```
Ollama VM (RTX 3090 passthrough)
├── Ollama        — LLM inference
└── ComfyUI       — image generation backend
    └── Open WebUI — unified chat + image interface
```

> **GPU sharing constraint:** Ollama and ComfyUI share the same 24 GB VRAM. They cannot run simultaneously at full load. In practice: Ollama unloads a model from VRAM when idle (configurable timeout), freeing VRAM for ComfyUI. For on-demand use this is seamless — for simultaneous heavy use, you'll need to manually stop one service.

---

## Model Quality Reference

| Model | VRAM | Disk | Quality | Speed (RTX 3090 est.) |
|---|---|---|---|---|
| SD 1.5 | 4–6 GB | ~2 GB | Dated — skip | ~3–5 sec |
| SDXL 1.0 | 8–10 GB | ~7 GB | Good | ~8–15 sec |
| FLUX.1 Schnell (fp8) | 16–20 GB | ~17 GB | Excellent | ~20–35 sec |
| FLUX.1 Dev (fp8) | 20–24 GB | ~24 GB | Best open-source | ~40–70 sec |

**Recommendation:** Start with FLUX.1 Schnell (fp8). It fits comfortably in 24 GB, generates high-quality images in under 40 seconds, and is licensed for personal use. FLUX.1 Dev produces marginally better results but requires a Hugging Face account to download and is slower.

---

## 12.1 Install ComfyUI

SSH into the Ollama VM:

```bash
ssh aiuser@<ollama-vm-ip>
```

Install dependencies:

```bash
sudo apt install -y git python3-pip python3-venv
```

Clone and set up ComfyUI:

```bash
cd ~
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
python3 -m venv venv
source venv/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
pip install -r requirements.txt
```

> **CUDA PyTorch:** PyTorch bundles its own CUDA runtime, so the pip wheel works regardless of your system driver version. Check `nvidia-smi` — the CUDA version shown in the top-right corner is a guide for which wheel to use: `cu124` for CUDA 12.4, `cu126` for CUDA 12.6. `ubuntu-drivers autoinstall` on Ubuntu 24.04 typically installs driver 535–545 (CUDA 12.2), which works fine with `cu124`. Available wheel indexes: `download.pytorch.org/whl/torch_stable.html`.

---

## 12.2 Download FLUX.1 Schnell (fp8)

FLUX model weights are large — store them on the external models SSD if configured ([section 9.4](09-external-storage.md)):

```bash
# Install huggingface_hub downloader
pip install huggingface_hub

# Download FLUX.1 Schnell fp8 checkpoint (~17 GB)
huggingface-cli download black-forest-labs/FLUX.1-schnell \
  flux1-schnell.safetensors \
  --local-dir ~/ComfyUI/models/checkpoints/
```

Download the required VAE and text encoders:

```bash
# VAE
huggingface-cli download black-forest-labs/FLUX.1-schnell \
  ae.safetensors \
  --local-dir ~/ComfyUI/models/vae/

# Text encoders (CLIP + T5)
huggingface-cli download comfyanonymous/flux_text_encoders \
  clip_l.safetensors t5xxl_fp8_e4m3fn.safetensors \
  --local-dir ~/ComfyUI/models/clip/
```

Total download: ~20 GB. Allow 10–30 minutes depending on connection speed.

---

## 12.3 Run ComfyUI

```bash
cd ~/ComfyUI
source venv/bin/activate
python main.py --listen 0.0.0.0 --port 8188
```

Access the ComfyUI web interface:

```
http://<ollama-vm-ip>:8188
```

### Verify GPU is Being Used

In ComfyUI terminal output, look for:

```
Using device: cuda
VAE dtype: torch.float16
```

During generation, monitor GPU usage:

```bash
# In a second terminal
watch -n 1 nvidia-smi
```

GPU memory should climb to 16–20 GB during FLUX inference.

### Run as a Systemd Service

```bash
sudo nano /etc/systemd/system/comfyui.service
```

```ini
[Unit]
Description=ComfyUI Image Generation
After=network.target

[Service]
Type=simple
User=aiuser
WorkingDirectory=/home/aiuser/ComfyUI
ExecStart=/home/aiuser/ComfyUI/venv/bin/python main.py --listen 0.0.0.0 --port 8188
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now comfyui
```

---

## 12.4 Configure Ollama VRAM Release

By default Ollama holds a loaded model in VRAM until it times out. Set the timeout so VRAM is freed for ComfyUI when LLM inference is idle:

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=5m"
```

`OLLAMA_KEEP_ALIVE=5m` — Ollama releases VRAM 5 minutes after the last LLM request. Adjust to taste: `1m` for faster image gen access, `30m` if you want models to stay hot for frequent coding use.

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 12.5 Connect Open WebUI to ComfyUI

In Open WebUI: **Settings → Images**

| Setting | Value |
|---|---|
| Image Generation Engine | `ComfyUI` |
| ComfyUI Base URL | `http://localhost:8188` |
| Default Model | `flux1-schnell.safetensors` |

Save. In the chat interface, click the **image icon** (or type `/image`) to generate an image from a prompt.

Example: `/image a cyberpunk cityscape at night, neon reflections on wet pavement, photorealistic`

---

## 12.6 ComfyUI Manager (Recommended)

ComfyUI Manager adds a UI for installing custom nodes, model downloader, and workflow templates — saves significant manual configuration:

```bash
cd ~/ComfyUI/custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
```

Restart ComfyUI. A **Manager** button appears in the web UI.

Useful custom nodes to install via Manager:

| Node | Purpose |
|---|---|
| ComfyUI-GGUF | Runs GGUF-quantized models (smaller, lower VRAM) |
| ComfyUI Impact Pack | Advanced sampling, face detailing |
| ComfyUI Essentials | Quality-of-life workflow utilities |

---

## 12.7 Additional Models

Store all checkpoints on the models external SSD to avoid filling the internal NVMe:

```bash
# SDXL — good for styles FLUX doesn't handle as well
huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0 \
  sd_xl_base_1.0.safetensors \
  --local-dir ~/ComfyUI/models/checkpoints/

# FLUX.1 Dev (requires HuggingFace login — better quality than Schnell)
huggingface-cli login  # enter your HF token
huggingface-cli download black-forest-labs/FLUX.1-dev \
  flux1-dev.safetensors \
  --local-dir ~/ComfyUI/models/checkpoints/
```

### Storage Budget

| Model | Size |
|---|---|
| FLUX.1 Schnell (fp8) | ~17 GB |
| FLUX.1 Dev (fp8) | ~24 GB |
| SDXL Base | ~7 GB |
| VAE + encoders | ~5 GB |
| **Total** | **~53 GB** |

With LLM models (~30–50 GB) added, a 2TB models drive fills up. Prune models you don't use regularly with `rm ~/ComfyUI/models/checkpoints/<model>.safetensors`.

---

## 12.8 Phase 1 (No eGPU)

Image generation on the 780M iGPU before the eGPU arrives is possible but slow:

| Model | 780M iGPU speed |
|---|---|
| SD 1.5 | ~2–4 min/image |
| SDXL | ~8–15 min/image |
| FLUX.1 Schnell | Not recommended |

SD 1.5 is barely usable for experimentation. Treat image generation as a Phase 2 feature — add it after the eGPU is installed.

---

## Troubleshooting

**"CUDA out of memory" during generation:**
Ollama may still have a model loaded. Either wait for `OLLAMA_KEEP_ALIVE` timeout or force unload:
```bash
# Force Ollama to release VRAM
curl http://localhost:11434/api/generate -d '{"model":"","keep_alive":0}'
```

**ComfyUI not using GPU (running on CPU):**
```bash
# Verify CUDA PyTorch installation
cd ~/ComfyUI && source venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"
# Should print: True
```

If `False`, reinstall PyTorch with the correct CUDA version:
```bash
pip install torch --index-url https://download.pytorch.org/whl/cu124 --force-reinstall
```

**Slow generation despite GPU usage:**
Ensure Ollama has released VRAM (check `OLLAMA_KEEP_ALIVE` setting in [section 12.4](12-image-generation.md)). Confirm no other process is holding GPU memory:
```bash
nvidia-smi
```

---

[← Upgrading](11-upgrading.md) | [← Overview](README.md)
