---
---
# 05 — Mobile Agentic Access

[← Inference Backends](04-inference-backends.md) | [Next: Model Reference →](06-model-reference.md)

---

{% include guide-toc.html toc=site.data.customization-toc %}

## Overview

You're away from your dev machine and want to trigger a repo change from your phone — fix a bug, update a config, or ask a question about a codebase — without opening a laptop. Two options, both reachable over the Tailscale connection from [Remote Access with Tailscale](../home-ai-guide/12-tailscale-remote-access.md):

- **Option A — Open WebUI custom Tools:** give your existing mobile-friendly Open WebUI chat interface the ability to call a Python function, including one that commits and pushes to a repo
- **Option B — OpenHands:** a continuous-loop coding agent that can be triggered entirely from the GitHub mobile app via an issue label or `@mention` — no need to open Open WebUI at all

---

## 5.1 Option A — Open WebUI Custom Tools

Open WebUI Tools are Python functions with docstrings. The docstring becomes the tool description the model sees; the function signature becomes its callable schema. Once added, the model can call the tool mid-conversation when it decides the tool is relevant to your request.

### Authoring pattern

Tools are added in Open WebUI: **Workspace → Tools → + Create New Tool**. The minimal shape:

```python
"""
title: Example Tool
description: Demonstrates the Tools authoring pattern.
"""

class Tools:
    def __init__(self):
        pass

    def get_current_time(self) -> str:
        """
        Get the current server time.

        :return: The current time as an ISO 8601 string.
        """
        import datetime
        return datetime.datetime.now().isoformat()
```

Two things the model relies on to use this correctly:
- The class must be named `Tools`.
- Every method's docstring is what the model reads to decide whether and how to call it — write it as if explaining the function to someone who cannot see the code, including what each parameter means.

Save the tool, then enable it per-model in **Workspace → Models → [your model] → Tools**, or globally per-chat via the tools icon in the chat input bar.

---

### A real tool: git commit + push

This tool shells out to `git` inside the Open WebUI container to commit a file change and push it to a specific repo. Credential approach: an SSH deploy key scoped to a single repo, mounted read-only into the container — not a personal access token, matching the least-privilege pattern already used elsewhere in this guide (e.g. the Z-Wave USB stick being passed through to only the HA VM, not the whole host).

**Generate and scope the deploy key** (on your workstation, not the server):

```bash
ssh-keygen -t ed25519 -f ~/deploy_key_reponame -N "" -C "openwebui-deploy"
```

Add the **public** key (`deploy_key_reponame.pub`) to the target GitHub repo under **Settings → Deploy keys → Add deploy key**, with **Write access** checked.

**Mount the private key into the Open WebUI container** — update the `docker run` command from [section 9.5 of the core guide](../home-ai-guide/09-ollama-open-webui.md):

```bash
docker run -d \
  --name open-webui \
  --restart always \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://<ollama-vm-ip>:11434 \
  -v open-webui:/app/backend/data \
  -v ~/deploy_key_reponame:/root/.ssh/id_ed25519:ro \
  ghcr.io/open-webui/open-webui:main
```

The key is mounted read-only (`:ro`) — the container can use it to authenticate but cannot overwrite or exfiltrate it via a mistaken write.

**The tool** (Workspace → Tools → + Create New Tool):

```python
"""
title: Git Commit and Push
description: Commits a file change to a git repository and pushes it to the remote.
"""

import subprocess


class Tools:
    def __init__(self):
        pass

    def git_commit_and_push(
        self, repo_path: str, file_path: str, file_content: str, commit_message: str
    ) -> str:
        """
        Write content to a file in a local git repository, commit it, and push to origin.

        :param repo_path: Absolute path to the git repository on disk (e.g. /repos/my-project).
        :param file_path: Path to the file to write, relative to repo_path (e.g. src/config.yaml).
        :param file_content: The full new content to write to the file.
        :param commit_message: The commit message describing this change.
        :return: A summary of the git commands run and their output, or an error message.
        """
        full_path = f"{repo_path}/{file_path}"

        try:
            with open(full_path, "w") as f:
                f.write(file_content)
        except OSError as e:
            return f"Failed to write file: {e}"

        commands = [
            ["git", "-C", repo_path, "add", file_path],
            ["git", "-C", repo_path, "commit", "-m", commit_message],
            ["git", "-C", repo_path, "push", "origin", "HEAD"],
        ]

        output_lines = []
        for cmd in commands:
            result = subprocess.run(cmd, capture_output=True, text=True)
            output_lines.append(f"$ {' '.join(cmd)}\n{result.stdout}{result.stderr}")
            if result.returncode != 0:
                return "Command failed:\n" + "\n".join(output_lines)

        return "Success:\n" + "\n".join(output_lines)
```

**Clone the target repo into the container** (one-time, or bake it into a custom image) so `repo_path` has something to act on:

```bash
docker exec -it open-webui sh -c "mkdir -p /repos && git clone git@github.com:<you>/<reponame>.git /repos/<reponame>"
```

Git needs to trust the mounted key and know to use it for GitHub — set this once inside the container:

```bash
docker exec -it open-webui sh -c "
  git config --global user.email 'openwebui@local' &&
  git config --global user.name 'Open WebUI Agent' &&
  mkdir -p ~/.ssh &&
  ssh-keyscan github.com >> ~/.ssh/known_hosts
"
```

From your phone, in an Open WebUI chat with this tool enabled: *"Update `src/config.yaml` in `/repos/reponame` to set `debug: false`, commit it as 'disable debug logging', and push."* The model calls `git_commit_and_push` with the file's new full content, not a diff — Open WebUI tools receive whole values, not patches, so the model must have first read the file's current content (e.g. via a companion `read_file` tool, or by you pasting it into the chat) to construct the new version correctly.

> **Scope this key to one repo.** A deploy key with write access to a single repository limits the blast radius if the container is ever compromised — this is a materially different risk profile than mounting a personal SSH key or PAT with access to every repo you own.

---

## 5.2 Option B — OpenHands (Continuous-Loop Agent)

OpenHands is a self-hosted, continuous-loop coding agent: point it at a repo and an LLM backend, and it can read code, make edits, run commands, and open pull requests on its own — the strongest fit in this guide for "make a change while I'm not at my computer," because it can be triggered entirely from a GitHub comment on your phone.

### Deploy via Docker

On the Docker LXC (or any host with Docker):

```bash
docker run -d \
  --name openhands \
  --restart always \
  -p 8000:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.openhands:/root/.openhands \
  --add-host host.docker.internal:host-gateway \
  ghcr.io/all-hands-ai/openhands:latest
```

Access at `http://<docker-lxc-ip>:8000` — reachable from your phone over Tailscale, same as the rest of this guide's services.

### Connect to your local Ollama backend

In OpenHands: **Settings → LLM → see advanced settings → enable Advanced**

| Field | Value |
|---|---|
| Custom Model | `openai/qwen3-coder:30b-a3b-q4_K_M` |
| Base URL | `http://<ollama-vm-ip>:11434/v1` |
| API Key | `local-llm` (placeholder — Ollama ignores it) |

### Context length precondition — check before enabling

OpenHands requires `OLLAMA_CONTEXT_LENGTH` of at least 22000 to fit its system prompt and tool-calling overhead. Whether your Phase 2 setup has room for this depends on what's already loaded:

`qwen3-coder:30b-a3b`'s architecture (48 layers, 4 KV heads, head_dim 128) puts its KV cache cost at 96KB/token (fp16) or 48KB/token (q8_0). At 22,000 tokens of context:

| KV cache type | Cost at 22K context |
|---|---|
| fp16 (default) | ~2.1GB |
| q8_0 | ~1.0GB |

Your existing Phase 2 setup from [Coding Assistant](03-coding-assistant.md) runs `qwen3-coder:30b-a3b-q4_K_M` (21GB) + `qwen2.5-coder:3b` autocomplete (2GB) = 23GB — already close to the RTX 3090's 24GB ceiling before adding any KV cache for a 22K context window.

| Configuration | Total VRAM | Fits in 24GB? |
|---|---|---|
| 21GB weights + 2GB autocomplete + 2.1GB fp16 KV | 25.1GB | ❌ No |
| 21GB weights + 2GB autocomplete + 1.0GB q8_0 KV | 24.0GB | ⚠️ Zero headroom |
| 21GB weights + 1.0GB q8_0 KV (autocomplete unloaded) | 22.0GB | ✅ Yes, ~2GB headroom |

**Before running OpenHands sessions:**

1. Set `OLLAMA_KV_CACHE_TYPE=q8_0` (see [Performance Tuning](03-coding-assistant.md#performance-tuning))
2. Unload the autocomplete model — it isn't used by OpenHands anyway:
   ```bash
   ollama stop qwen2.5-coder:3b
   ```
3. Set `OLLAMA_CONTEXT_LENGTH=22000` in the Ollama systemd override alongside the flash-attention/KV-cache env vars

Skipping step 2 while running an OpenHands session will exceed 24GB and either fail to load or spill to CPU — re-enable the autocomplete model afterward for normal Continue.dev/Cline use.

### Trigger from your phone via GitHub

Once connected, OpenHands can respond to GitHub activity without you opening its web UI at all:

- **Label an issue `openhands`**, or open a comment starting with `@openhands` — OpenHands comments that it's working on it, then opens a pull request if it resolves the issue
- **Mention `@openhands` in a PR comment** — ask follow-up questions, request changes, or get an explanation of what it did

Both actions are standard GitHub features available in the GitHub mobile app — labeling an issue or leaving a comment from your phone is enough to kick off a fix, with no need to reach for a laptop or even open Open WebUI.

---

## 5.3 Not Recommended: Devika

Devika (a similar local-LLM-compatible coding agent) is not covered here — its own README states it is being superseded by a successor project ("Opcode") and self-describes as experimental with broken features. OpenHands is the more mature choice for this use case as of this writing.

---

[← Inference Backends](04-inference-backends.md) | [Next: Model Reference →](06-model-reference.md)
