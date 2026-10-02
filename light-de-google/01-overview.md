---
---
# 01 — Overview & Strategy

{% include guide-toc.html toc=site.data.de-google-toc %}

[&larr; Overview](./) | [Next: Prework &rarr;](02-workspace-prework)

## What you're eliminating vs. keeping

- **Eliminate:** Workspace subscription, Google as mail handler for your domain, Chrome Password Manager, Google search/browser default.
- **Keep:** one free Gmail account as permanent mail archive + data sink (inbound mail, Drive/Photos, and historical Workspace mail all land there), the Google account itself for Android device requirements.

## Email Architecture

```
                ┌─ sends via ─▶ PurelyMail SMTP (DKIM)
Thunderbird ────┤
                └─ reads IMAP ◀─ PurelyMail MX ──catch-all forward──▶ Gmail archive
                                                                          ▲
Workspace (transition only) ──Takeout+import/imapsync──▶ historical mail ─┘
```

PurelyMail is pass-through MX + outbound SMTP — mail is forwarded on arrival and not stored there. The free Gmail account is the archive: inbound mail forwards to it, historical Workspace mail imports into it, and Thunderbird reads it via OAuth alongside PurelyMail via IMAP. Purelymail routing rules are permanent redirects — mail is sent on to the destination instead of being delivered to a local mailbox, so nothing accumulates in Purelymail. Purelymail publishes no hard storage limits (soft limits apply to unusually heavy usage).

This scales to **multiple custom domains**: each domain's MX points at PurelyMail, each domain gets a catch-all rule forwarding to the same Gmail archive, and Thunderbird holds one identity per address — replying to a message addressed to `you@domainB.com` automatically sends from that address.

## Historical Mail

The Workspace mailbox does **not** survive cancellation — its contents vanish when the subscription ends. Import historical mail **before** cancelling:

- **Zero extra tools (desktop):** Google Takeout (select Mail &rarr; exports `.mbox` archives) &rarr; Thunderbird's built-in Import &rarr; optionally drag the imported folders onto the Gmail archive's IMAP folders to make them server-side. Thunderbird is already this guide's required client.
- **Phone-only (no desktop, no homelab):** forward important mail to your custom-domain address (the §2 catch-all lands it in the archive) and export the rest as a Takeout `.mbox` backup — see §3 Track A step 1.
- **Fast path (homelab):** `imapsync` (app passwords on both accounts; resumable). Command in §3, Track B step 1.
- **Legacy:** Gmail's "Check mail from other accounts" (POP fetch) is being removed — readers who enabled it before Q1 2026 can use it until January 2027; new setups cannot.

## What "light" buys you — and what it doesn't

**Buys:** no Workspace bill; mail delivery for your domain no longer owned by Google; credentials out of Chrome; search/browser de-Googled.

**Doesn't buy:** your mail archive still lives on Google (that is the sink's price); Android still requires the Google account; Play Services still phones home. This is a pragmatic partial exit, not anonymity.

## Migration Matrix

| Google Service | Alternative |
|---|---|
| Workspace email | PurelyMail MX &rarr; catch-all forward &rarr; Gmail archive (any number of domains); send via PurelyMail SMTP |
| Mail client | Thunderbird, all devices ([why not Spark?](02-workspace-prework#why-not-spark)) |
| Historical Workspace mail | Desktop: Takeout + Thunderbird import · Homelab: `imapsync` (§3 Track B) · Phone-only: forward keepers + Takeout mbox backup (§3 Track A) |
| Drive files | **Track A:** Shared Folder method (§3 Track A) · **Track B:** rclone server-side &rarr; homelab |
| Photos | **Track A:** Partner Sharing (§3 Track A) · **Track B:** Takeout &rarr; `immich-go` &rarr; Immich |
| Contacts / Calendar | **Track A:** export `.vcf`/`.ics` &rarr; import to Gmail · **Track B:** Takeout &rarr; Nextcloud + DAVx⁵ |
| Docs/Sheets/Slides | Move with the §2 transfer (Track A) or your track's rclone step (§3) — stay native, no export needed; Takeout office export only if you want offline copies (§3) |
| Keep | Collaborator share &rarr; re-link account (§3, Notes section) |
| "Sign in with Google" logins | Password auth with the same custom-domain address — it survives via PurelyMail (§4, Retire Google Sign-In) |
| Shared Drives | Not in the Transfer tool — rclone or admin Data export (§3) |
| Chrome sync (bookmarks/tabs) | Sign Chrome into the generic Gmail account (§4) |
| Chrome Passwords | Vaultwarden (self-hosted; see [home-ai-guide §16](../home-ai-guide/16-vaultwarden)) |
| Voice number | Port/unlock before cancellation (§3, Other Google Services) |
| Drive app-data (WhatsApp etc.) | In-app chat transfer before cancellation (§3, Other Google Services) |
| Google Search / Chrome | DuckDuckGo (search + Private Browser) |

## Effort & Timeline

| Task | Duration | Difficulty |
|---|---|---|
| Archive account + PurelyMail + DNS Cutover | 1–2 h | Low |
| Thunderbird Setup | 1–2 h | Low |
| Historical Mail Import | 1–2 days (background) | Medium |
| Data Migration (Track A or B) | 1–2 weeks | Medium |
| Notes, Passwords & Privacy | 1–2 h | Low |
| Transition Period | 1–3 months | Low |
| Final Cancellation | 1 day | Low |

*Note: Historical mail and data migration dominate and can run in the background.*

## Order of Operations

1. **PurelyMail + catch-all first** — verify forwarding works before touching DNS (MX changes are reversible).
2. **DNS cutover at Route53.**
3. **Historical mail import** — must complete before cancellation.
4. **Data migration** — Track A or Track B (§3).
5. **Credentials/notes third.**
6. **Retire Google sign-in** — password + custom-domain address at every third-party service that used "Sign in with Google"; port Voice, export filters (§4, Retire Google Sign-In).
7. **Cancellation last** (30-day soak).

---

[&larr; Overview](./) | [Next: Prework &rarr;](02-workspace-prework)
