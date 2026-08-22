---
---
# 05 — Nginx Proxy Manager

[← Docker & Homelab Services](04-docker-homelab.md) | [Next: Plex LXC →](06-plex-lxc.md)

---

{% include guide-toc.html toc=site.data.guide-toc %}

The goal: reach services by a friendly name (`ha.yourdomain.com`) on your internal network only, with valid browser-trusted HTTPS through NPM — no port forwarding, no public exposure.

This uses **DNS-01 challenge** (Let's Encrypt proves domain ownership via a DNS TXT record instead of port 80) combined with **split-horizon DNS** (AdGuard Home resolves the domain to a local IP — configured in section 3.1).

## Prerequisites

- A domain hosted in **AWS Route 53**
- An AWS IAM user with permissions to modify Route 53 records (created in Step 1 below)
- NPM running (from section 3.5)
- AdGuard Home running with DNS rewrites configured (from section 3.1)

---

## 5.1 Create an IAM User for DNS-01

NPM needs AWS credentials that can create/delete Route 53 TXT records for the Let's Encrypt challenge.

1. In the [AWS IAM console](https://console.aws.amazon.com/iam) → **Users → Create user**
2. Name it `certbot-dns` (no console access needed)
3. After creation, go to the user → **Security credentials → Create access key** → select **Other** → create
4. Save the **Access Key ID** and **Secret Access Key** — shown once

Attach this inline policy to the user (replace `<HOSTED_ZONE_ID>` with your Route 53 hosted zone ID, found in Route 53 → Hosted zones):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ChangeResourceRecordSets",
      "Resource": "arn:aws:route53:::hostedzone/<HOSTED_ZONE_ID>",
      "Condition": {
        "ForAllValues:StringEquals": {
          "route53:ChangeResourceRecordSetsRecordTypes": ["TXT"]
        }
      }
    }
  ]
}
```

---

## 5.2 Request a Wildcard Certificate in NPM

1. In NPM admin UI: **SSL Certificates → Add SSL Certificate → Let's Encrypt**
2. Fill in:

   | Field | Value |
   |---|---|
   | Domain Names | `*.yourdomain.com` and `yourdomain.com` |
   | Email | your email |
   | Use a DNS Challenge | ✅ Enable |
   | DNS Provider | `Route53` |
   | Credentials File Content | see below |

   Credentials content:
   ```
   dns_route53_access_key_id = AKIAIOSFODNN7EXAMPLE
   dns_route53_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   ```

3. Agree to Let's Encrypt ToS → **Save**

NPM will create a DNS TXT record in Route 53 via the AWS API to prove ownership, then issue a wildcard cert. This takes ~30 seconds.

---

## 5.3 Create Proxy Hosts in NPM

> Local DNS rewrites are already handled by AdGuard Home (section 3.1). No additional DNS configuration is needed here.

In NPM admin UI: **Hosts → Proxy Hosts → Add Proxy Host**

For each service:

| Field | Value |
|---|---|
| Domain Names | `ha.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname / IP | LAN IP of the service (e.g. `192.168.50.7`) |
| Forward Port | Service port (e.g. `8123` for HA) |
| **Websockets Support** | ✅ Enable — required for HA, Portainer, and Grafana |
| **SSL Certificate** | Select the `*.yourdomain.com` wildcard cert |
| Force SSL | ✅ Enable |
| HTTP/2 Support | ✅ Enable |

Repeat for each service. Example entries:

| Subdomain | Backend IP | Port |
|---|---|---|
| `ha.yourdomain.com` | HA VM LAN IP (see section 8) | `8123` |
| `ollama.yourdomain.com` | Ollama VM LAN IP (see section 9) | `3000` |
| `portainer.yourdomain.com` | Docker LXC IP | `9000` |
| `grafana.yourdomain.com` | Docker LXC IP | `3001` |

---

## Result

Typing `ha.yourdomain.com` in any browser on your LAN:
- Resolves to NPM via AdGuard DNS rewrite
- NPM proxies to HA and serves valid HTTPS with the wildcard cert
- Never leaves your network
- Full browser mic access works (HTTPS required for microphone in mobile browsers)

---

[← Docker & Homelab Services](04-docker-homelab.md) | [Next: Plex LXC →](06-plex-lxc.md)
