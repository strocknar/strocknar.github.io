https://hermes-agent.nousresearch.com/

Install on opencode server

## install

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Run through the config
Select Custom for the backend and point to http://<ollam-ip>:11434/v1
Use searxng for the search
most everything else is just defaults (but use your best judgment)

## Web Dashboard

sudo vim /etc/systemd/system/hermes-dashboard.service

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

```bash
# Reload the systemd manager configuration
sudo systemctl daemon-reload

# Enable the service to launch automatically on boot
sudo systemctl enable hermes-dashboard.service

# Start the dashboard service right now
sudo systemctl start hermes-dashboard.service

# check logs
sudo journalctl -u hermes-dashboard.service -n 20

```

## Check

Navigate to http://<YOUR-HERMES-TAILSCALE-IP>:3000

Add to NPM

## Attach to OpenCode

```bash
vim ~/.hermes/config.yaml
```

Scroll down to the tools: or mcp_servers: section. If it doesn't exist, append the OpenCode block to enable delegation:

```yaml
tools:
  opencode:
    enabled: true
    executable_path: "/usr/local/bin/opencode" # Adjust if 'which opencode' outputs differently
    default_workspace: "/root/projects"       # The baseline path to your code repos
```

Open your Hermes Dashboard on your phone (http://<YOUR-HERMES-TAILSCALE-IP>:3000).

Log in using the Basic Auth credentials you established in your systemd file.

Tap the Menu icon and navigate to the Skills tab.

Look under the Autonomous AI Agents category for OpenCode CLI.

Click Enable / Install. 