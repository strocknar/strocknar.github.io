---
---
# 16 — Inference Backends

[← Coding Assistant](15-coding-assistant.md)

---

{% include guide-toc.html %}

## Overview

Ollama is the recommended inference backend for this guide — it handles model management, API serving, and GPU detection automatically. This page covers two topics for users who want to go further:

1. **Alternative MoE models** that fit within the RTX 3090's 24GB VRAM and perform comparably to `qwen3-coder:30b-a3b-q4_K_M`
2. **llama.cpp server** as an alternative inference backend — 5–15% faster throughput than Ollama using the same GGUF models with minimal setup

---

## Why MoE Models Are Fast on the RTX 3090

Standard (dense) models load all parameters for every token. A 32B Q4_K_M dense model requires ~29GB — exceeding the 3090's 24GB VRAM and forcing layers to CPU, which bottlenecks inference dramatically.

MoE (Mixture of Experts) models solve this by activating only a small subset of experts per token. `qwen3-coder:30b-a3b` has 30B total parameters but activates only ~3B per token — the rest stay dormant. This means:

- **VRAM footprint**: ~21GB (fits fully on GPU)
- **Compute per token**: equivalent to a ~3B model
- **Knowledge**: trained across all 30B parameters

Result: ~80–100 tok/s fully GPU-resident vs 8–9 minutes for a 32B dense model spilling to CPU.

---

## MoE Model Reference (RTX 3090, 24GB)

| Model | VRAM | Active Params | Context | Notes |
|---|---|---|---|---|
| `qwen3-coder:30b-a3b-q4_K_M` | ~21GB | ~3B/token | 256K | **Recommended** — primary coding assistant |
| `qwen2.5-coder:32b-instruct-q4_K_M` | ~20GB | dense | 32K | Dense model, fits in VRAM — good fallback |
| `qwen2.5-coder:14b-instruct-q4_K_M` | ~9GB | dense | 32K | Fast, leaves headroom for autocomplete model |

> **Models that do NOT fit on a single RTX 3090 (24GB):**
> - `mixtral:8x7b` (~26GB) — exceeds by 2GB
> - `mixtral:8x22b` (~80GB) — far too large
> - `deepseek-v3` (~400GB) — multi-GPU only

---

## Backend Comparison: Ollama vs llama.cpp Server

| | Ollama | llama.cpp server |
|---|---|---|
| Setup | One binary, automatic | Manual CUDA build or release binary |
| GGUF support | Native | Native |
| Throughput | Baseline | ~5–15% faster |
| Model management | Built-in (`ollama pull`) | Manual (download GGUF directly) |
| API | Ollama native + OpenAI-compat | OpenAI-compatible |
| Open WebUI | Native | Via OpenAI-compat endpoint |
| Continue.dev / Cline | Native Ollama provider or OpenAI-compat | OpenAI-compat |

**When to use llama.cpp server**: If you want every last token of throughput and don't mind managing model files manually. For most users, Ollama's convenience outweighs the 5–15% performance gap.

---

## 16.1 llama.cpp Server Setup

### Download

Get the latest CUDA release binary from the [llama.cpp releases page](https://github.com/ggml-org/llama.cpp/releases).

Look for the asset named `llama-<version>-bin-ubuntu-x64.tar.gz`. On the Ollama VM (Ubuntu, NVIDIA GPU):

```bash
# Download latest release (check releases page for current version)
RELEASE=$(curl -s https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | grep tag_name | cut -d'"' -f4)
wget "https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE}/llama-${RELEASE}-bin-ubuntu-x64.tar.gz"
tar -xzf llama-${RELEASE}-bin-ubuntu-x64.tar.gz -C llama-cpp --strip-components=1
chmod +x llama-cpp/llama-server
```

Verify CUDA is detected:
```bash
./llama-cpp/llama-server --version
```

### Download a Model

llama.cpp server uses GGUF files directly. Download from HuggingFace:

```bash
# Install huggingface-cli if needed
pip install huggingface_hub

# Download qwen3-coder 30B A3B Q4_K_M
huggingface-cli download \
  Qwen/Qwen3-Coder-30B-A3B-Instruct-GGUF \
  qwen3-coder-30b-a3b-instruct-q4_k_m.gguf \
  --local-dir ~/models
```

### Start the Server

```bash
./llama-cpp/llama-server \
  --model ~/models/qwen3-coder-30b-a3b-instruct-q4_k_m.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 32768 \
  --n-gpu-layers 99 \
  --flash-attn
```

- `--n-gpu-layers 99`: offload all layers to GPU (99 is effectively "all")
- `--flash-attn`: enables Flash Attention for faster inference
- `--host 0.0.0.0`: listens on all interfaces (required for Open WebUI and Continue.dev)

Verify the server is running:
```bash
curl http://localhost:8080/health
```

### Connect Continue.dev

llama.cpp server exposes an OpenAI-compatible API at `/v1`. Update `~/.continue/config.yaml`:

```yaml
models:
  - title: Qwen3 Coder 30B (llama.cpp)
    provider: openai
    model: qwen3-coder:30b-a3b-q4_K_M
    apiBase: http://<ollama-vm-ip>:8080/v1
    apiKey: none

tabAutocompleteModel:
  title: Qwen2.5 Coder 3B (Autocomplete)
  provider: ollama
  model: qwen2.5-coder:3b
  apiBase: http://<ollama-vm-ip>:11434
```

> The autocomplete model can still use Ollama — run both Ollama (port 11434) and llama.cpp server (port 8080) simultaneously.

### Connect Cline

In VSCode settings:

| Setting | Value |
|---|---|
| API Provider | `OpenAI Compatible` |
| Base URL | `http://<ollama-vm-ip>:8080/v1` |
| API Key | `none` |
| Model | `qwen3-coder:30b-a3b-q4_K_M` |

---

[← Coding Assistant](15-coding-assistant.md)
