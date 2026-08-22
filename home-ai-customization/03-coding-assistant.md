---
---
# 03 — Local Coding Assistant

[← Image Generation](02-image-generation.md) | [Next: Inference Backends →](04-inference-backends.md)

---

{% include guide-toc.html toc=site.data.customization-toc %}

## Overview

Once Phase 2 is running, `qwen3-coder:30b-a3b-q4_K_M` at ~80–100 tok/s is fast enough to be a genuinely useful day-to-day coding assistant — not just a curiosity. This section covers wiring it into two tools:

- **VSCode** via Continue.dev (chat + autocomplete) or Cline (agentic)
- **OpenCode** — an open-source terminal coding agent, the closest local equivalent to Claude Code

Both reach your Ollama VM over the LAN or through Tailscale when you're off-network. No code leaves your machine.

> **Phase 1 note:** `qwen3:8b` at 5–8 tok/s is too slow for interactive autocomplete. On Phase 1, these tools are usable for chat (chat is less latency-sensitive), but the experience is marginal. The full value of this section unlocks at Phase 2.

---

## VRAM Budget (Phase 2)

The RTX 3090 has 24GB VRAM. Running a chat model and an autocomplete model simultaneously requires fitting both:

| Model | Size | Role | Notes |
|---|---|---|---|
| `qwen3-coder:30b-a3b-q4_K_M` | ~21GB | Chat, code review, refactors | MoE architecture — only ~3B parameters active per token despite 30B total |
| `qwen2.5-coder:3b` | ~2GB | Autocomplete — 21 + 2 = 23GB ✅ | Fast single-token completions |
| `qwen3:32b-q4_K_M` | ~29GB | ⚠️ Do not use | Exceeds 24GB VRAM — spills to CPU, measured 8–9 min/response |

**Recommendation: use `qwen2.5-coder:3b` for autocomplete and `qwen3-coder:30b-a3b-q4_K_M` for chat.** Both stay resident in VRAM simultaneously with ~1GB headroom. The MoE architecture means the 30B model activates only ~3B params per token — it runs at ~80–100 tok/s fully GPU-resident.

Pull both models on the Ollama VM:

```bash
ollama pull qwen3-coder:30b-a3b-q4_K_M
ollama pull qwen2.5-coder:3b
```

---

## Performance Tuning

Two settings meaningfully affect throughput and VRAM headroom on the RTX 3090, independent of which tool you wire up below.

### Flash Attention + KV Cache Quantization (Ollama)

Add to the Ollama systemd override (same block as `OLLAMA_HOST` in [section 9.3 of the core guide](../home-ai-guide/09-ollama-open-webui.md)):

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

`OLLAMA_FLASH_ATTENTION=1` is required for `OLLAMA_KV_CACHE_TYPE` to take effect — setting the cache type alone does nothing without it. `q8_0` halves KV cache VRAM usage with minimal quality impact for normal text generation.

> **Not all models benefit equally.** Devstral Small 2 and DeepSeek-R1-Distill 14B are dense transformers whose KV cache grows linearly with context — `q8_0` saves real VRAM on these (up to ~2.5GB at 32K context on Devstral). Qwen 3.6 27B and Gemma 4 26B-A4B use hybrid attention architectures that keep KV cache small by design — quantizing it barely moves the needle for those two. See [Model Reference](06-model-reference.md) for the full VRAM-at-context breakdown.

### Flash Attention + KV Cache Quantization (llama.cpp)

llama.cpp server's `--flash-attn` flag now defaults to `auto` (enables itself automatically when supported) as of current releases — the `--flash-attn` boolean-only flag some older guides show is out of date. Add explicit KV cache quantization flags to the `llama-server` command from [Inference Backends](04-inference-backends.md):

```bash
./llama-cpp/llama-server \
  --model ~/models/qwen3-coder-30b-a3b-instruct-q4_k_m.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 32768 \
  --n-gpu-layers 99 \
  --flash-attn auto \
  -ctk q8_0 -ctv q8_0
```

`-ctk` and `-ctv` set the K and V cache quantization independently — `q8_0` for both matches Ollama's `OLLAMA_KV_CACHE_TYPE=q8_0` behavior above.

---

## Endpoint Reference

Both tools below use the same Ollama endpoints. Your Ollama VM exposes:

| Endpoint | URL | Used by |
|---|---|---|
| Native Ollama API | `http://<ollama-vm-ip>:11434` | Continue.dev (native Ollama provider) |
| OpenAI-compatible API | `http://<ollama-vm-ip>:11434/v1` | Cline, OpenCode (expect OpenAI format) |

Replace `<ollama-vm-ip>` with:
- Your LAN IP when at home (e.g. `192.168.1.x`)
- Your Tailscale IP (`100.x.x.x`) when remote — see [Remote Access with Tailscale](../home-ai-guide/12-tailscale-remote-access.md)

API key: any non-empty string (e.g. `ollama`). Ollama ignores it but most tools require a non-blank value.

---

## 3.1 VSCode — Continue.dev

Continue.dev is the recommended VSCode extension for Ollama. It handles both chat and autocomplete from a single config file, with native Ollama support (no proxy needed).

### Install

Search `Continue` in the VSCode Extensions marketplace and install it. The config file is created at `~/.continue/config.yaml` on first launch.

### Configure

Replace `~/.continue/config.yaml` with:

```yaml
models:
  - title: Qwen3 Coder 30B (Primary)
    provider: ollama
    model: qwen3-coder:30b-a3b-q4_K_M
    apiBase: http://<ollama-vm-ip>:11434
    contextLength: 262144

  - title: Qwen3 14B (Fast)
    provider: ollama
    model: qwen3:14b-q4_K_M
    apiBase: http://<ollama-vm-ip>:11434
    contextLength: 32768

tabAutocompleteModel:
  title: Qwen2.5 Coder 3B (Autocomplete)
  provider: ollama
  model: qwen2.5-coder:3b
  apiBase: http://<ollama-vm-ip>:11434
```

> **Note:** `qwen3:32b-q4_K_M` is not included — at 29GB it exceeds the RTX 3090's 24GB VRAM and spills layers to CPU, resulting in 8–9 minute responses. Do not add it to this config.

> **Phase 1 config:** Remove the autocomplete block entirely or point it at `qwen3:8b-q4_K_M`. The 3B autocomplete model is only worth using on Phase 2 where it responds fast enough to feel like Copilot.

### Usage

- **Chat panel** (`Cmd+L` / `Ctrl+L`): opens the chat sidebar backed by `qwen3-coder:30b-a3b`
- **Inline edit** (`Cmd+I` / `Ctrl+I`): select code, describe the change
- **Tab autocomplete**: enabled automatically once `tabAutocompleteModel` is set — appears as ghost text while you type
- **Switch model**: use the model dropdown in the chat panel to swap between the 30B coder and 14B models

---

## 3.2 VSCode — Cline (Agentic)

Cline is a VSCode extension that acts as an autonomous coding agent: it reads and writes files, runs terminal commands, and loops until a task is complete. Use it for larger tasks like multi-file refactors, scaffolding new features, or anything that requires coordinating across files.

### Install

Search `Cline` in the VSCode Extensions marketplace.

### Configure

In VSCode Settings (`Cmd+,` / `Ctrl+,`), search `Cline` and set:

| Setting | Value |
|---|---|
| API Provider | `OpenAI Compatible` |
| Base URL | `http://<ollama-vm-ip>:11434/v1` |
| API Key | `ollama` |
| Model | `qwen3-coder:30b-a3b-q4_K_M` |

Or edit `settings.json` directly:

```json
{
  "cline.apiProvider": "openai",
  "cline.openAiBaseUrl": "http://<ollama-vm-ip>:11434/v1",
  "cline.openAiApiKey": "ollama",
  "cline.openAiModelId": "qwen3-coder:30b-a3b-q4_K_M"
}
```

### Continue.dev vs. Cline

| | Continue.dev | Cline |
|---|---|---|
| Autocomplete | ✅ | ❌ |
| Chat | ✅ | ✅ |
| Reads/writes files autonomously | ❌ | ✅ |
| Runs terminal commands | ❌ | ✅ |
| Best for | Everyday chat + autocomplete | Multi-step agentic tasks |

They complement each other — install both. Continue.dev handles the everyday flow; Cline handles tasks you'd describe as "go figure this out."

---

## 3.3 OpenCode

OpenCode is an open-source terminal coding agent. It runs in your terminal, understands your project via LSP, and can edit files and run commands — the same model as Claude Code, but local and model-agnostic.

Project page: `https://opencode.ai`

### Install

```bash
curl -fsSL https://opencode.ai/install | bash
```

Or via Homebrew:

```bash
brew install opencode
```

### Configure

Create `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://<ollama-vm-ip>:11434/v1"
      },
      "models": {
        "qwen3-coder:30b-a3b-q4_K_M": {
          "name": "Qwen3 Coder 30B"
        }
      }
    }
  }
}
```

### Usage

Launch from your project root:

```bash
opencode
```

OpenCode auto-detects your project's language server (LSP) and wires it up. Select your model with `/models` inside the session.

> **Multi-agent sessions:** OpenCode supports running parallel agent sessions. On Phase 2, this works well — two concurrent requests to `qwen3-coder:30b-a3b` are within what the RTX 3090 can serve, though throughput per session drops roughly in half.

---

## Extending Agent Capabilities via MCP

The tools above give you a chat/autocomplete/agentic loop against a local model. MCP (Model Context Protocol) servers extend what that agent can *do* — pull live documentation, run project-specific workflows — without changing the model itself.

### Context7 — Live Library Documentation

Context7 is an MCP server that retrieves up-to-date, version-specific documentation and code examples for libraries, injecting them into the model's context to prevent hallucinated APIs. Setup:

```bash
npx ctx7 setup
```

This authenticates via OAuth and generates an API key. Alternatively, configure manually against `https://mcp.context7.com/mcp` with a bearer token header — the token is available from the Context7 dashboard.

**Continue.dev** (`~/.continue/config.yaml`):

```yaml
mcpServers:
  - name: Context7
    type: streamable-http
    url: https://mcp.context7.com/mcp
    env:
      BEARER_TOKEN: ${{ secrets.CONTEXT7_API_KEY }}
```

**Cline** (`cline_mcp_settings.json`):

```json
{
  "mcpServers": {
    "context7": {
      "type": "streamableHttp",
      "url": "https://mcp.context7.com/mcp",
      "headers": { "Authorization": "Bearer <API_KEY>" },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

**OpenCode** (`~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "headers": { "Authorization": "Bearer {env:CONTEXT7_API_KEY}" }
    }
  }
}
```

### Superpowers — Skills/Workflow Framework (OpenCode)

Superpowers is a skills/workflow framework (brainstorming → plan → TDD → review) — not a model or MCP server. It installs directly into OpenCode:

Tell OpenCode:
```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

This works because OpenCode ships a native plugin system that Superpowers registers against directly — no format translation needed for its existing skill files.

> **Continue.dev and Cline** have no equivalent native skills runtime as of this writing. Superpowers in this guide is an OpenCode-specific capability, not a ported one.

---

> For alternative inference backends and a full MoE model reference table, see [Inference Backends](04-inference-backends.md).

[← Image Generation](02-image-generation.md) | [Next: Inference Backends →](04-inference-backends.md)
