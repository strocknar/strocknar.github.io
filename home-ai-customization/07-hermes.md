---
title: Hermes Agent Integration
description: Install and configure the Hermes Agent web dashboard for managing AI agents with OpenCode
---

[← Model Reference](06-model-reference.md)

---

# 07 — Hermes Agent Integration

Integrate the Hermes Agent web dashboard for unified AI agent management alongside your OpenCode server.

[View Hermes documentation →](https://hermes-agent.nousresearch.com/)

---

## Install on opencode server

Install Hermes on the same VM or container running OpenCode for optimal performance and minimal latency.

First, SSH into the server and give opencode a legit shell:

```
sudo usermod -s /bin/bash opencode
```

Then either become opencode, or SSH as the opencode user

```bash
# Allow opencode to use linger (required for hermes gateway)
sudo loginctl enable-linger opencode

# Becone opencode
sudo su - opencode

# Install Hermes
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Run through the config:
- Select "Custom endppoint (enter URL manually) for the provider
  - Point to `http://<ollama-ip>:11434/v1` (the OpenAI-compatible endpoint)
  - No API key
  - Select one of the available models
  - Auto detect the context length 
- Medium for the thinking (if the model can use it, otherwise disable)
- Terminal backend: Local
- Enable any platforms you want (or none and just hit Enter), then configure them
  - See the [Discord](#setting-up-discord) section for more instructions on that
- For "Tools for CLI"
  - Select Kanban and possibly context engine
- Choose the "Browser Use"
- I chose "OpenAI (Codex auth) [free]" for the image provider
- Piper for the TTS
- Use searxng for the search
- Most everything else is just defaults (but use your best judgment)

> **Known issue: conversations fill the context window.** Hermes accumulates conversation history without trimming it. On Ollama's default 32K window, an agent conversation in daily use grows to fill the window within just a few responses; from then on every turn gets cut off at the ceiling (`truncated = 1` in the Ollama logs), which Hermes reports as "reasoning consumed the entire budget" or a generic provider error. Set `OLLAMA_CONTEXT_LENGTH=65536` on the Ollama server (see [Inference Backends § Context Length Configuration](04-inference-backends.md)) — and expect to need conversation trimming eventually regardless of window size.

---

## Web Dashboard

Configure the Hermes dashboard as a systemd service:

```bash
sudo vim /etc/systemd/system/hermes-dashboard.service
```

```ini
[Unit]
Description=Hermes Agent Web Dashboard
After=network.target

[Service]
Type=simple
User=opencode
WorkingDirectory=/home/opencode/.hermes

# NETWORK BIND PARAMETERS
Environment=HOST=0.0.0.0
Environment=PORT=3000

# MANDATORY AUTH CONFIGURATION (Satisfies the 0.0.0.0 gate)
Environment=HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
Environment=HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=password
# Secret ensures your web session tokens persist across systemd service restarts
Environment=HERMES_DASHBOARD_BASIC_AUTH_SECRET=generate_any_random_string_here

ExecStart=/home/opencode/.local/bin/hermes dashboard --host 0.0.0.0 --port 3000
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hermes-dashboard

[Install]
WantedBy=multi-user.target
```

### Start the service

```bash
# Reload the systemd manager configuration
sudo systemctl daemon-reload

# Enable the service to launch automatically on boot
sudo systemctl enable hermes-dashboard.service

# Start the dashboard service right now
sudo systemctl start hermes-dashboard.service

# Check logs
sudo journalctl -u hermes-dashboard.service -n 20
```

### Verify

Navigate to `http://<YOUR-HERMES-TAILSCALE-IP>:3000`

For NPM package installation (optional):
- Add to your package.json and run `npm install`

---

## Attach to OpenCode

Configure Hermes to delegate tasks to OpenCode:

```bash
vim ~/.hermes/config.yaml
```

Scroll down to the `tools` or `mcp_servers:` section. If it doesn't exist, append the OpenCode block to enable delegation:

```yaml
tools:
  opencode:
    enabled: true
    executable_path: "/home/opencode/.opencode/bin/opencode" # Adjust if 'which opencode' outputs differently
    default_workspace: "/opt/repos"       # The baseline path to your code repos
```

---

## Using the Dashboard

1. Open your Hermes Dashboard on your phone: `http://<YOUR-HERMES-TAILSCALE-IP>:3000`
1. Log in using the Basic Auth credentials you established in your systemd file
1. Tap the Menu icon and navigate to the Skills tab
1. Look under the Autonomous AI Agents category for OpenCode CLI
1. Click Enable / Install

Now you can use the Hermes web interface as a unified control panel for both Hermes Agent and OpenCode, managing AI agents from your phone while keeping all capabilities integrated.

---

## Setting up Discord

### How to Create a Free Personal Server

1. Open Discord and look at the left sidebar (where server icons are listed).
2. Click the green "+" plus icon ("Add a Server").
3. Select Create My Own.
4. Choose For me and my friends.
5. Name the server (e.g., Hermes Control Room) and click Create.

Once created, you are automatically the Server Owner. This gives you full administrative privileges to invite the bot using the URL you generated in Step 4 of the Discord guide.

### Create the Bot

To create your initial Discord bot application, you must sign into the [Discord Developer Portal](https://discord.com/developers/applications) and register a new app container.

1. Sign In and Create Application: 
    1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and log in using your personal Discord user credentials
    2. Click the New Application button in the top-right corner
    3. Enter an Application Name like HermesAgent, accept the terms, and click Create.
2. Generate the Bot User Profile: 
    1. Click on the Bot tab in the left sidebar menu
    2. Customize your bot display name or profile image
    3. Toggle Public Bot to ON under authorization options
3. Turn on Privileged Gateway Intents: 
    1. Scroll down to the Privileged Gateway Intents section on the same page and toggle ON both Server Members Intent and Message Content Intent, then click Save Changes.
4. Copy Your Secret Token: 
    1. Find the Token area near the top of the Bot page
    2. Click Reset Token, and copy the private token string immediately before it becomes hidden forever

### Invite the Bot to Your Server

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications) and click on your Hermes application.
2. In the left sidebar, click on Installation.
3. Under the Installation Contexts section, ensure that Guild Install (this allows server installations) and User Install (this allows user DMs) are checked.
4. Look down at the Default Install Link section. Change the dropdown menu from "None" to Discord Provided Link.
5. Under Guild Install -> Scopes: Hit the dropdown and select "bot".
6. Under Permissions, select the following checkmarks:
    - View Channels (Read Messages)
    - Send Messages
    - Read Message History
7. Click the Copy button next to the generated URL at the top of the Installation page.
8. Paste this link into a new browser tab.
9. Select either your server from the dropdown list or install the application to your Account / Profile, click Continue, and then click Authorize.

---
[← Model Reference](06-model-reference.md)
