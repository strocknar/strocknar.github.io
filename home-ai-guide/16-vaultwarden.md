---
---
# Vaultwarden Password Manager

[← Voice Satellites](15-voice-satellites)

---

{% include guide-toc.html toc=site.data.guide-toc %}

Self-hosted, Bitwarden-compatible password server on the Docker homelab LXC. Replaces Google Password Manager / browser-saved passwords.

---

## 16.1 Deploy the Container

Deploy the container on the Docker homelab LXC (from [section 04](04-docker-homelab)):

```yaml
services:
  vaultwarden:
    image: ghcr.io/dani-garcia/vaultwarden:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      - DOMAIN=https://vaultwarden.<your-domain>
      - SIGNUPS_ALLOWED=true   # set to false after creating your account
    volumes:
      - /path/to/vaultwarden-data:/data
    ports:
      - 8222:80
```
> The image moved to ghcr.io — verify the current image and tag at https://github.com/dani-garcia/vaultwarden.

---

## 16.2 HTTPS via Nginx Proxy Manager

Configure a proxy host in Nginx Proxy Manager: `vaultwarden.<your-domain>` → `<docker-lxc-ip>:8222`.

- Enable **Websockets Support**.
- Request a **Let's Encrypt** certificate.

> **Critical:** Browsers refuse WebCrypto on plain HTTP, so HTTPS (or a Tailscale hostname with its cert flow) is required — not optional.

---

## 16.3 Tailscale-only Option

Instead of a public proxy host, you can expose the service only via the Tailscale network. See [Remote Access with Tailscale](12-tailscale-remote-access) for details.

---

## 16.4 Backups

Perform nightly copies of the `/data` directory (which contains `db.sqlite3`) using the existing backup approach used elsewhere in the guide.

---

## 16.5 Clients

- **Browser Extension:** Download from `vault.bitwarden.com` and point it at your self-hosted URL.
- **Mobile App:** Install the Bitwarden app and use the "Server URL" override.
- **Android Autofill:** Go to Settings → Passwords & accounts → Autofill service → Bitwarden.

---

## 16.6 Lock Down Signups

After importing your passwords and creating your account, disable public signups for security:

1. Set `SIGNUPS_ALLOWED=false` in the compose file.
2. Run `docker compose up -d` to apply the change.

---

[← Voice Satellites](15-voice-satellites)
