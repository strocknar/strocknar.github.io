---
permalink: /light-de-google/
---
# Light De-Google Guide

A pragmatic, partial exit from Google: leave Google Workspace and stop paying for it, keep a free Gmail account as a permanent mail archive and data sink, and move what's worth moving to self-hosted or privacy-respecting alternatives.

{% include guide-toc.html toc=site.data.de-google-toc %}

[Start with Section 1 →](01-overview)

---

## The "Light" Approach

The goal is to kill the Google Workspace subscription and stop using Google as your mail handler, while keeping a free Gmail account as the permanent archive and consolidated data destination. PurelyMail feeds any number of custom domains into the same archive — one unified inbox, replying from whichever address received the mail. This avoids the total friction of a "hard" exit while removing the monthly bill and reducing Google's hold on your identity. Data migration offers two tracks: a Gmail sink (no homelab needed) or a full homelab exit (Nextcloud, Immich, DAVx⁵) — see [§3](03-data-migration).

## Email Flow

```
                ┌─ sends via ─▶ PurelyMail SMTP (DKIM)
Thunderbird ────┤
                └─ reads IMAP ◀─ PurelyMail MX ──catch-all forward──▶ Gmail archive
                                                                          ▲
Workspace (transition only) ──Takeout+import/imapsync──▶ historical mail ─┘
```

## Migration Timeline

| Task | Duration | Difficulty |
|---|---|---|
| PurelyMail + DNS Cutover | 1–2 h | Low |
| Thunderbird Setup | 1–2 h | Low |
| Historical Mail Import | 1–2 days (background) | Medium |
| Data Migration (Track A or B) | 1–2 weeks | Medium |
| Notes, Passwords & Privacy | 1–2 h | Low |
| Retire Google Sign-In | 1–3 h | Low |
| Transition Period | 1–3 months | Low |
| Final Cancellation | 1 day | Low |

## Prerequisites

- Custom domain (DNS on Route53)
- PurelyMail account
- Thunderbird on your devices
- [Vaultwarden server](../home-ai-guide/16-vaultwarden) (if following the passwords path)

Once email and data are off Workspace, continue with **[Home AI Guide](../home-ai-guide/)** for the self-hosted stack that replaces Google services.
