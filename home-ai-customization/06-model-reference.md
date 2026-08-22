---
---
# 06 — Model Reference

[← Mobile Agentic Access](05-mobile-agentic-access.md)

---

{% include guide-toc.html toc=site.data.customization-toc %}

## Overview

Four current-generation local models worth knowing about beyond the `qwen3-coder:30b-a3b` primary coding assistant covered in [Coding Assistant](03-coding-assistant.md). All tags, sizes, and architecture fields below were verified against Ollama's library and each model's published `config.json` — not estimated.

| Model | Exact Tag | Weights | Architecture | Context | Notes |
|---|---|---|---|---|---|
| Devstral Small 2 | `devstral-small-2:24b-instruct-2512-q4_K_M` | 15.0GB | Dense, 24B, GQA (32Q/8KV heads, head_dim 128, 40 layers) | 384K | Agentic coding/tool-use, SWE-bench Verified 65.8%, vision-capable |
| DeepSeek-R1-Distill 14B | `deepseek-r1:14b-qwen-distill-q4_K_M` | 9.0GB | Dense, 14B, GQA (40Q/8KV heads, head_dim 128, 48 layers) | 128K | Reasoning/CoT distilled from R1 into Qwen 14B base |
| Qwen 3.6 27B | `qwen3.6:27b-q4_K_M` | 17.0GB | Dense, 27.8B, hybrid linear/full attention (full attention every 4th of 64 layers; head_dim 256, 4 KV heads) | 256K | Agentic coding, "thinking preservation," repo-level reasoning |
| Gemma 4 26B-A4B | `gemma4:26b-a4b-it-q4_K_M` | 18.0GB | MoE, 3.8B active / 25.2B total, hybrid sliding(1024)/full attention (full attention every 6th of 30 layers; 128 experts, top-8 routed) | 256K | Multimodal (text+image), general reasoning/agentic — not coding-specialized |

Pull any of these on the Ollama VM:

```bash
ollama pull devstral-small-2:24b-instruct-2512-q4_K_M
ollama pull deepseek-r1:14b-qwen-distill-q4_K_M
ollama pull qwen3.6:27b-q4_K_M
ollama pull gemma4:26b-a4b-it-q4_K_M
```

---

## VRAM at Context Length

KV cache size is computed per-model from `2 × layers × kv_heads × head_dim × bytes_per_element × context_tokens`, applied only to full-attention layers for the two hybrid models (Qwen 3.6, Gemma 4) since their sliding/linear-attention layers keep effectively constant, context-independent state. A fixed ~0.4–0.6GB compute-buffer allowance (approximate, typical observed llama.cpp/Ollama overhead) is added to every total.

| Model | Weights | @8K (fp16 / q8_0) | @16K (fp16 / q8_0) | @32K (fp16 / q8_0) |
|---|---|---|---|---|
| Devstral Small 2 24B (dense) | 15.0GB | 16.6 / 16.0GB | 17.9 / 16.6GB | 20.4 / 17.9GB |
| DeepSeek-R1-Distill 14B (dense) | 9.0GB | 10.9 / 10.1GB | 12.3 / 10.9GB | 15.3 / 12.3GB |
| Qwen 3.6 27B (hybrid linear/full) | 17.0GB | 18.0 / 17.7GB | 18.5 / 18.0GB | 19.5 / 18.5GB |
| Gemma 4 26B-A4B (hybrid sliding/full, MoE) | 18.0GB | 18.8 / 18.7GB | 18.9 / 18.8GB | 19.2 / 18.9GB |

**Dense models benefit meaningfully from `q8_0` KV cache quantization at longer context.** Devstral saves up to ~2.5GB at 32K context; DeepSeek-R1-14B saves ~3GB. See [Coding Assistant § Performance Tuning](03-coding-assistant.md) for how to enable `q8_0` on Ollama and llama.cpp.

**Hybrid-attention models barely move.** Qwen 3.6 and Gemma 4's architectures keep KV cache small by design — the gap between fp16 and q8_0 is under 1GB even at 32K context. Quantizing their KV cache is not worth the (small) quality tradeoff.

---

## VRAM Budget on a 24GB RTX 3090

No forced two-model pairing here — three of these four models are 15–18GB solo, leaving little to no room for a second model on a 24GB card:

| Model | Solo VRAM (16K context, q8_0 KV) | Use case |
|---|---|---|
| Devstral Small 2 24B | ~16.6GB | Agentic coding/tool-use, best SWE-bench score of the four — good primary coding-assistant alternative to `qwen3-coder:30b-a3b` |
| DeepSeek-R1-Distill 14B | ~10.9GB | Reasoning/chain-of-thought tasks; only model here with real headroom to pair with a small autocomplete model (e.g. `qwen2.5-coder:3b`, ~2GB) |
| Qwen 3.6 27B | ~18.0GB | Agentic coding with strong repo-level reasoning; solo daily-driver |
| Gemma 4 26B-A4B | ~18.8GB | Multimodal (text+image) general reasoning/agentic; solo daily-driver, not coding-specialized |

**Recommendation:** use DeepSeek-R1-Distill 14B when you want headroom for an autocomplete model alongside it. Use Devstral Small 2 or Qwen 3.6 27B as an alternative primary coding assistant to `qwen3-coder:30b-a3b` if you want a change of pace or a second opinion on a hard problem — swap models in the Open WebUI or Continue.dev dropdown rather than running two simultaneously.

---

[← Mobile Agentic Access](05-mobile-agentic-access.md)
