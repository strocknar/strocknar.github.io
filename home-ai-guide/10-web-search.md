---
---
# 10 — Web Search Integration (SearXNG + Open WebUI)

[← External Storage](09-external-storage.md) | [Next: Upgrading →](11-upgrading.md)

---

{% include guide-toc.html %}

## Architecture

```
Open WebUI (chat interface)
    ↓ web search request
SearXNG (self-hosted meta-search — queries Google, Bing, DuckDuckGo, etc.)
    ↓ search results
Open WebUI feeds results as context to Ollama
    ↓
Ollama synthesizes an answer from retrieved content
```

Your prompts and search queries stay entirely on your network. SearXNG proxies searches anonymously — search engines see SearXNG's requests, not your IP or query history.

---

## 10.1 Deploy SearXNG

Add SearXNG to the Docker stack in the Docker LXC.

Edit `/opt/homelab/docker-compose.yml` — add to the `services:` block:

```yaml
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./searxng:/etc/searxng:rw
    environment:
      - SEARXNG_BASE_URL=http://<docker-lxc-ip>:8080/
    networks:
      - homelab
```

Create the config directory:

```bash
mkdir -p /opt/homelab/searxng
```

Create the settings file:

```bash
vim /opt/homelab/searxng/settings.yml
```

```yaml
use_default_settings: true

server:
  secret_key: "<generate-a-random-string-here>"
  limiter: false
  image_proxy: false

search:
  safe_search: 0
  autocomplete: ""
  default_lang: "en"

engines:
  - name: google
    engine: google
    shortcut: g
    disabled: false

  - name: duckduckgo
    engine: duckduckgo
    shortcut: d
    disabled: false

  - name: bing
    engine: bing
    shortcut: b
    disabled: false

  - name: wikipedia
    engine: wikipedia
    shortcut: w
    disabled: false

ui:
  static_use_hash: true
```

Generate the secret key:

```bash
openssl rand -hex 32
```

Paste the output as the `secret_key` value.

Deploy:

```bash
cd /opt/homelab
docker compose up -d searxng
```

Verify SearXNG is running:

```
http://<docker-lxc-ip>:8080
```

Try a search in the UI to confirm results appear.

---

## 10.2 Connect SearXNG to Open WebUI

In Open WebUI: **Settings (gear icon) → Web Search**

| Setting | Value |
|---|---|
| Enable Web Search | ✅ On |
| Web Search Engine | `searxng` |
| SearXNG Query URL | `http://<docker-lxc-ip>:8080/search?q=<query>&format=json` |
| Search Result Count | `5` |
| Concurrent Requests | `1` |

Save.

---

## 10.3 Using Web Search in Open WebUI

In the chat interface, click the **globe icon** (or use the `+` menu) to enable web search for a message. When enabled, Open WebUI will:

1. Send your query to SearXNG
2. Retrieve the top 5 results
3. Include the content as context in the prompt to Ollama
4. Generate a response synthesizing the retrieved information

The model cites sources inline in its response.

> **Model recommendation for web-augmented queries:** Use `qwen3:8b-q4_K_M` for general web Q&A. The 30B coding model is overkill for factual lookups and slower to respond. Switch models in the Open WebUI dropdown per task.

---

## 10.4 Web Search from Home Assistant

The Ollama conversation agent in HA can also use web search for queries it can't answer from its training data. This requires the `extended_openai_conversation` custom integration or a similar tool-use integration.

This is an advanced configuration — the basic Ollama HA integration handles home control commands well without web search. Add this only if you find the LLM frequently unable to answer questions you'd like it to handle.

Basic flow:
1. Install HACS (Home Assistant Community Store) via the HA add-on store
2. Install `extended_openai_conversation` via HACS
3. Configure it to point at your Ollama endpoint with a web search tool definition

---

## 10.5 Perplexica (Optional Alternative)

Perplexica is a full Perplexity-style interface that combines search and LLM into a single purpose-built UI. If you prefer a dedicated research tool over Open WebUI's integrated search:

```yaml
# Add to docker-compose.yml
  perplexica:
    image: itzcrazykns1337/perplexica:main
    container_name: perplexica
    restart: always
    ports:
      - "3002:3000"
    environment:
      - OLLAMA_API_URL=http://<ollama-vm-ip>:11434
      - SEARXNG_API_URL=http://searxng:8080
    depends_on:
      - searxng
    networks:
      - homelab
```

Access: `http://<docker-lxc-ip>:3002`

Perplexica and Open WebUI serve different use cases — Open WebUI is the better coding assistant interface; Perplexica is better for research-oriented web Q&A. Both can coexist.

---

[← External Storage](09-external-storage.md) | [Next: Upgrading →](11-upgrading.md)
