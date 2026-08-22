# Home AI Customization

{% include guide-toc.html toc=site.data.customization-toc %}

[Start with Section 1 →](01-web-search.md)

---

A continuation of the [Home AI Guide](../home-ai-guide/) — once your core homelab, Home Assistant, and voice setup are running, this guide covers extending what your local models can do: web search, image generation, a local coding assistant, alternative inference backends, mobile agentic access, and a reference for current-generation models beyond the primary `qwen3-coder:30b-a3b` recommendation.

**Assumes Phase 2 (RTX 3090 via eGPU)** throughout — see [eGPU Setup](../home-ai-guide/11-egpu-setup.md) in the core guide if you haven't completed that yet. Phase 1 hardware (iGPU only) is not fast enough for the coding-assistant and image-generation workflows covered here.

## Sections

1. [Web Search Integration (SearXNG + Open WebUI)](01-web-search.md)
2. [Local Image Generation (ComfyUI + FLUX)](02-image-generation.md)
3. [Local Coding Assistant](03-coding-assistant.md)
4. [Inference Backends](04-inference-backends.md)
5. [Mobile Agentic Access](05-mobile-agentic-access.md)
6. [Model Reference](06-model-reference.md)
