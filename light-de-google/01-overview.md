---
---
# Overview & Strategy

{% include guide-toc.html toc=site.data.de-google-toc %}

## What you're eliminating vs. keeping

- **Eliminate:** Workspace subscription, Google as mail host for your domain, Chrome Password Manager, Google search/browser default.
- **Keep:** one free Gmail account as relay + data sink (Drive/Photos land there), Google account itself for Android device requirements.

## Email Flow

```
Google Workspace ──routes──▶ generic Gmail ──forwards──▶ PurelyMail
                                     ▲                          │
                                     │ OAuth (read)             │ IMAP/SMTP
                                  Spark Mail ◀─────sends via────┘
                                       (through PurelyMail when domain matches)
```

## Migration Matrix

| Google Service | Alternative |
|---|---|
| Workspace email | Generic Gmail relay → Spark + PurelyMail |
| Drive files | Share + server-side copy (or MultCloud) |
| Photos | Partner Sharing → save copies (or MultCloud) |
| Contacts / Calendar | Takeout `.vcf`/`.ics` → import to Gmail |
| Docs/Sheets/Slides | Takeout export (formats + limitations in §3) |
| Keep | Collaborator share → re-link account |
| Chrome Passwords | Vaultwarden (self-hosted; see [home-ai-guide §16](../home-ai-guide/16-vaultwarden)) |
| Google Search / Chrome | DuckDuckGo (search + Private Browser) |

## Effort & Timeline

| Task | Duration | Difficulty |
|---|---|---|
| Spark Mail Setup | 1–2 h | Low |
| Email Forwarding | 1 day | Low |
| Data Migration | 1–2 weeks | Medium |
| Notes, Passwords & Privacy | 1–2 h | Low |
| Transition Period | 1–3 months | Low |
| Final Cancellation | 1 day | Low |

*Note: Data migration dominates and can run in the background.*

## Order of Operations

1. **Email routing first** (it's reversible).
2. **Data second**.
3. **Credentials/notes third**.
4. **Cancellation last** (30-day soak).
