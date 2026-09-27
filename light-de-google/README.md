---
layout: default
---
# Light De-Google Guide

A pragmatic, partial exit from Google: leave Google Workspace and stop paying for it, keep a free Gmail account as a relay and data sink, and move what's worth moving to self-hosted or privacy-respecting alternatives.

{% include guide-toc.html toc=site.data.de-google-toc %}

[Start with Section 1 →](01-overview.md)

---

## The "Light" Approach

The goal of a "light" de-googling is to kill the Google Workspace subscription and stop using Google as your primary mail host, while keeping a free Gmail account as a relay and consolidated data destination. This avoids the total friction of a "hard" exit while removing the monthly bill and reducing Google's hold on your professional identity.

## Email Flow

```
Google Workspace ──routes──▶ generic Gmail ──forwards──▶ PurelyMail
                                     ▲                          │
                                     │ OAuth (read)             │ IMAP/SMTP
                                  Spark Mail ◀─────sends via────┘
                                       (through PurelyMail when domain matches)
```

## Migration Timeline

| Task | Duration | Difficulty |
|---|---|---|
| Spark Mail Setup | 1–2 h | Low |
| Email Forwarding | 1 day | Low |
| Data Migration | 1–2 weeks | Medium |
| Notes, Passwords & Privacy | 1–2 h | Low |
| Transition Period | 1–3 months | Low |
| Final Cancellation | 1 day | Low |

## Prerequisites

- Custom domain
- PurelyMail account
- [Vaultwarden server](../home-ai-guide/16-vaultwarden.md) (if following the passwords path)

Once email and data are off Workspace, continue with **[Home AI Guide](../home-ai-guide/)** for the self-hosted stack that replaces Google services.
