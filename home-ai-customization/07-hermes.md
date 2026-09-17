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

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Run through the config:
- Select Custom for the backend
- Point to `http://<ollama-ip>:11434/v1` (the OpenAI-compatible endpoint)
- Use searxng for the search
- Most everything else is just defaults (but use your best judgment)

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
User=root
WorkingDirectory=/root/.hermes

# NETWORK BIND PARAMETERS
Environment=HOST=0.0.0.0
Environment=PORT=3000

# MANDATORY AUTH CONFIGURATION (Satisfies the 0.0.0.0 gate)
Environment=HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
Environment=HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=password
# Secret ensures your web session tokens persist across systemd service restarts
Environment=HERMES_DASHBOARD_BASIC_AUTH_SECRET=generate_any_random_string_here

ExecStart=/usr/local/bin/hermes dashboard --host 0.0.0.0 --port 3000
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
    executable_path: "/usr/local/bin/opencode" # Adjust if 'which opencode' outputs differently
    default_workspace: "/root/projects"       # The baseline path to your code repos
```

---

## Using the Dashboard

1. Open your Hermes Dashboard on your phone: `http://<YOUR-HERMES-TAILSCALE-IP>:3000`

2. Log in using the Basic Auth credentials you established in your systemd file

3. Tap the Menu icon and navigate to the Skills tab

4. Look under the Autonomous AI Agents category for OpenCode CLI

5. Click Enable / Install

Now you can use the Hermes web interface as a unified control panel for both Hermes Agent and OpenCode, managing AI agents from your phone while keeping all capabilities integrated.

---

[← Model Reference](06-model-reference.md)
