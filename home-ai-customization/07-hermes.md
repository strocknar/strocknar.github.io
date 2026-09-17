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
# Set your preferred working directory (usually where your hermes configurations live)
WorkingDirectory=/root/.hermes
# Environment variables for custom hosting options
Environment=HOST=0.0.0.0
Environment=PORT=3000
# Update the binary path below if yours differs
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
```

## Check

Navigate to http://<YOUR-HERMES-TAILSCALE-IP>:3000

Add to NPM