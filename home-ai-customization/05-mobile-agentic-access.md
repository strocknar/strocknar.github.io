---
---
# 05 — Mobile Agentic Access

[← Inference Backends](04-inference-backends.md) | [Next: Model Reference →](06-model-reference.md)

---

{% include guide-toc.html toc=site.data.customization-toc %}

## Overview

You're away from your dev machine and want to run the same brainstorm → plan → execute → push workflow you use day-to-day, from your phone, without opening a laptop. Both options below are reachable over the Tailscale connection from [Remote Access with Tailscale](../home-ai-guide/12-tailscale-remote-access.md):

- **Option A — OpenCode Remote Access (Recommended):** a dedicated LXC running `opencode serve` as a persistent backend — it serves the chat UI directly, no separate frontend process needed — backed by the actual Superpowers skills engine. Brainstorming, planning, and execution all run exactly as they do on a workstation, just reachable from your phone.
- **Option B — Open WebUI custom Tools:** your existing mobile-friendly Open WebUI chat interface, given the ability to call a Python function that commits and pushes to a repo. Lighter-weight, but no skills runtime — use this for simple one-off edits, not the full brainstorm/plan workflow.

---

## 5.1 Option A — OpenCode Remote Access (Recommended)

This runs the real Superpowers brainstorming/planning/execution workflow — the same skill files used on a workstation — on a persistent server, reachable from your phone as a chat interface over Tailscale.

### Architecture

```
Phone (Tailscale client)
   |  HTTP(S) over Tailscale (100.x.x.x)
   v
Proxmox CT 204 (new, unprivileged LXC, hostname: opencode)
   |
   +-- opencode.service   (opencode serve — sessions, model calls, tool/git
   |     execution, AND the chat UI itself; there is no separate frontend
   |     process to run)
   |     - OPENCODE_SERVER_PASSWORD set (HTTP Basic auth)
   |     - Superpowers plugin installed, same as section 3.3
   |     - Model config in ~/.config/opencode/opencode.jsonc, pointed at the
   |       Ollama VM's OpenAI-compatible endpoint (same pattern as section 3.3)
   |
   +-- ~/.ssh/config + one deploy key per repo
   |
   +-- /repos/<reponame>/   (one clone per repo the agent may touch)
```

Model selection happens entirely in server-side config — the chat UI is served directly by `opencode serve` and has no separate model configuration of its own.

### Create the OpenCode LXC (CT 204)

In Proxmox web UI: **Create CT**

| Setting | Value |
|---|---|
| CT ID | `204` |
| Hostname | `opencode` |
| Unprivileged container | ✅ Yes — no hardware passthrough needed; it only talks to the Ollama VM over the network |
| Template | Debian 13 |
| Disk | `16GB` — repo clones are text/config repos, tens of MB each; this leaves headroom for the OS, OpenCode binary, and multiple clones with git history. Resizable later via `pct resize` if needed. |
| CPU | `2 cores` — OpenCode's server bootstraps multiple language servers (TypeScript, Python, etc.) per session; 1 core makes these sluggish |
| RAM | `4096` MB |
| Network — Bridge | `vmbr0` |
| Network — IPv4 | Static, `<opencode-lxc-ip>/24` |
| Network — Gateway | Your router IP |
| DNS tab — DNS server | `<adguard-lxc-ip>` |
| Start at boot | ✅ Yes |

Start the LXC.

> **Debian 13 / systemd 257:** If you see `WARN: Systemd 257 detected. You may need to enable nesting`, run this on the Proxmox host and restart the container:
> ```bash
> pct set 204 --features nesting=1
> ```

### Create a dedicated system user

```bash
useradd -m -s /usr/sbin/nologin opencode
```

The systemd service below runs as this user, not root.

### Install OpenCode and Superpowers

In the CT 204 console, install system packages as root:

```bash
apt update && apt install -y git openssh-client curl ca-certificates sudo
```

Install OpenCode itself as the `opencode` user, not root — the installer writes its binary path and `PATH` update into the invoking user's `$HOME/.bashrc`. Running it as root would put the binary on root's `PATH` only, leaving the `opencode` user with no `opencode` command:

```bash
sudo -H -u opencode bash -c 'curl -fsSL https://opencode.ai/install | bash'
sudo -H -u opencode bash -c 'grep -qxF "export PATH=\"/home/opencode/.opencode/bin:\$PATH\"" /home/opencode/.bashrc || echo "export PATH=\"/home/opencode/.opencode/bin:\$PATH\"" >> /home/opencode/.bashrc'
```

Install Superpowers the same way as the workstation setup in [Coding Assistant §3.3](03-coding-assistant.md#33-opencode) — tell OpenCode to fetch and follow the install instructions, which registers Superpowers as an OpenCode plugin (not a `.opencode/skills/` directory):

Run this as the `opencode` user so the plugin installs into `/home/opencode/.config/opencode/`, matching the user the systemd service runs as. `cd` into a directory `opencode` can access first:

```bash
cd /home/opencode
sudo -H -u opencode /home/opencode/.opencode/bin/opencode
```

Then ask opencode to install superpowers:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

### Configure the model backend

The Superpowers install step above already created `/home/opencode/.config/opencode/opencode.jsonc` with a `plugin` key. OpenCode's global config loader picks exactly one file from that directory — `opencode.jsonc` if it exists, else `opencode.json`, else `config.json` — it does **not** merge multiple global config files together. Add the provider/model config into the *same* `opencode.jsonc` rather than creating a separate `opencode.json`, or the model config will be silently ignored:

```bash
sudo -H -u opencode vim /home/opencode/.config/opencode/opencode.jsonc
```

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"],
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
        },
        "devstral-small-2:24b-instruct-2512-q4_K_M": {
          "name": "Devstral Small 2 24B"
        },
        "deepseek-r1:14b-qwen-distill-q4_K_M": {
          "name": "DeepSeek-R1-Distill 14B"
        },
        "qwen3.6:27b-q4_K_M": {
          "name": "Qwen 3.6 27B"
        },
        "gemma4:26b-a4b-it-q4_K_M": {
          "name": "Gemma 4 26B-A4B"
        }
      }
    }
  },
  "model": "ollama/qwen3-coder:30b-a3b-q4_K_M"
}
```

Keep the `plugin` line exactly as the installer wrote it — this edit only adds the `provider` and `model` keys alongside it. Every model listed under `provider.ollama.models` becomes selectable in the chat UI's `/models` picker — the top-level `model` field only sets which one loads by default at startup. The four alternates above are covered in [Model Reference](06-model-reference.md); pull whichever ones you plan to use on the Ollama VM first (`ollama pull <tag>`), or trim this list to just the models you've actually pulled.

Replace `<ollama-vm-ip>` with your Ollama VM's LAN IP, same as [Coding Assistant](03-coding-assistant.md#endpoint-reference).

```bash
chown -R opencode:opencode /home/opencode/.config
```

### Set up the systemd service

`opencode serve` is both the backend and the chat UI — it holds session state, calls the configured model, executes tool calls including git operations against the cloned repos, **and** serves the chat interface your phone connects to directly. There is no separate frontend process to run.

The install script places the binary at `/home/opencode/.opencode/bin/opencode` — use that path in `ExecStart` below. `which` won't confirm this for you: Debian's default `~/.bashrc` starts with an interactive-only guard (`case $- in *i*) ;; *) return;; esac`) that returns before the `PATH` line added above ever runs, for both a bare `sudo -u opencode which opencode` and a non-interactive login shell like `bash -lc`. Check the file exists at the known path directly instead:

```bash
sudo -H -u opencode test -x /home/opencode/.opencode/bin/opencode && echo "found"
```

```bash
vim /etc/systemd/system/opencode.service
```

```ini
[Unit]
Description=OpenCode remote agent server
After=network-online.target
Wants=network-online.target

[Service]
Environment="HOME=/home/opencode"
Environment='OPENCODE_SERVER_PASSWORD=<your-password>'
ExecStart=/home/opencode/.opencode/bin/opencode serve --hostname 0.0.0.0 --port 4096
Restart=on-failure
User=opencode

[Install]
WantedBy=multi-user.target
```

`After=network-online.target` (not the weaker `network.target`) matters here — the Superpowers plugin install fetches over the network on first start, and `network.target` doesn't guarantee a routable address yet.

The password lives in plaintext in this unit file — restrict its permissions:

```bash
chmod 600 /etc/systemd/system/opencode.service
```

Enable and start it:

```bash
systemctl daemon-reload
systemctl enable --now opencode
```

Verify it's running:

```bash
systemctl status opencode
```

### Set up per-repo deploy keys

Least-privilege pattern: one SSH deploy key per repo, so a compromise of CT 204 exposes write access only to the repos explicitly cloned there — not every repo you own.

**On your workstation** (not CT 204), generate one key per repo you want the agent to access:

```bash
ssh-keygen -t ed25519 -f ~/deploy_key_<reponame> -N "" -C "opencode-deploy-<reponame>"
```

Add the **public** key to that repo's GitHub **Settings → Deploy keys → Add deploy key**, with **Write access** checked. Repeat per repo.

**Copy each private key onto CT 204**, e.g.:

```bash
scp ~/deploy_key_<reponame> root@<opencode-lxc-ip>:/home/opencode/.ssh/deploy_key_<reponame>
```

**On CT 204**, create an SSH config alias per repo so git resolves the correct key without collisions:

```bash
vim /home/opencode/.ssh/config
```

```
Host github.com-<reponame>
  HostName github.com
  User git
  IdentityFile /home/opencode/.ssh/deploy_key_<reponame>
  IdentitiesOnly yes
```

Repeat the `Host` block per repo. Then:

```bash
chown -R opencode:opencode /home/opencode/.ssh
chmod 700 /home/opencode/.ssh
chmod 600 /home/opencode/.ssh/deploy_key_* /home/opencode/.ssh/config
```

`chmod 700` on the directory itself matters — OpenSSH's `StrictModes` rejects a group/other-writable `~/.ssh`, and `useradd -m` typically creates the home directory `0755`.

### Clone each repo

Use `sudo -H` (not bare `sudo -u`) so `git`'s config and SSH lookups resolve against the `opencode` user's home directory, not root's:

```bash
sudo -H -u opencode mkdir -p /repos
sudo -H -u opencode git clone git@github.com-<reponame>:<you>/<reponame>.git /repos/<reponame>
```

Repeat per repo, using the matching `Host` alias from the SSH config above in the clone URL.

### Set the shared git identity

One identity for all commits across all repos, matching the pattern used for the Open WebUI git tool in [5.2](#52-option-b--open-webui-custom-tools):

```bash
sudo -H -u opencode git config --global user.email "opencode@local"
sudo -H -u opencode git config --global user.name "OpenCode Agent"
sudo -H -u opencode sh -c "mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts"
```

> Without `-H`, `sudo` preserves the invoking (root) user's `$HOME` on Debian's default `sudoers` config — these commands would silently write to `/root/.gitconfig` instead of the `opencode` user's, and later commits would fail with "Please tell me who you are."

### Connect from your phone

1. Confirm Tailscale is connected on your phone — see [Remote Access with Tailscale](../home-ai-guide/12-tailscale-remote-access.md).
2. Visit `http://<opencode-lxc-tailscale-ip>:4096` in your phone's browser.
3. Your browser shows a standard HTTP Basic auth prompt. Enter **any non-empty username** (e.g. `opencode`) and the `OPENCODE_SERVER_PASSWORD` you set above as the password — a blank username is rejected.
4. Use "Add to Home Screen" for quicker access — whether this installs as a standalone app (no browser chrome) depends on your browser and OpenCode version; confirm once connected.

Once connected, brainstorming, planning, and execution work exactly as they do through OpenCode on a workstation (see [Coding Assistant §3.3](03-coding-assistant.md#33-opencode)) — point a session at `/repos/<reponame>` and start a conversation.

**Switching models:** the chat UI reads its model list from the server config. To change the default, edit `model` in `/home/opencode/.config/opencode/opencode.jsonc` and run `systemctl restart opencode`. Any model you want selectable must also be listed under `provider.ollama.models` in that file.

> **Security:** `--hostname 0.0.0.0` binds *all* network interfaces on CT 204 — Tailscale **and** your LAN, not Tailscale alone. Nothing is port-forwarded, so it's not reachable from the internet, but any device on your LAN can reach port 4096; the `OPENCODE_SERVER_PASSWORD` (HTTP Basic auth) is the only thing standing between them and an agent that can run shell commands and push to every repo cloned under `/repos`. Treat access to this port as equivalent to shell access on CT 204 — use a long, random password, not a memorable one. If you want to restrict this to Tailscale only, install Tailscale inside CT 204 and bind its address instead of `0.0.0.0`.
>
> **Password characters:** HTTP Basic auth itself accepts any character in the password. The unit file is the actual constraint: `Environment=` values undergo systemd specifier expansion, so a literal `%` must be written as `%%` or the service fails to start. The single-quoted form above (`Environment='OPENCODE_SERVER_PASSWORD=...'`) takes the value verbatim with no backslash-escaping — safe for most generated passwords, but it can't contain a literal single quote (`'`). Easiest: generate a password from `[A-Za-z0-9]` only (e.g. `openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24`), which avoids both issues entirely.

---

## 5.2 Option B — Open WebUI Custom Tools

A lighter-weight alternative to [5.1](#51-option-a--opencode-remote-access-recommended) for simple one-off file edits that don't need the full brainstorm/plan workflow.

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

Save the tool, then enable it per-model in **Workspace → Models → \[your model\] → Tools**, or globally per-chat via the tools icon in the chat input bar.

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

[← Inference Backends](04-inference-backends.md) | [Next: Model Reference →](06-model-reference.md)
