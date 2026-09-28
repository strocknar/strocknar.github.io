---
---
# 02 — Email Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)

1. **Create the PurelyMail account** — sign up at [purelymail.com](https://purelymail.com), add **each** custom domain you want on this inbox (one account holds multiple domains; their subdomain works too if you have none).
   > **Android:** do this in Chrome; the dashboard is desktop-oriented but works on mobile.
   > **Why storage doesn't matter:** PurelyMail routing rules are permanent redirects — mail is sent on to the destination (your Gmail archive) instead of being delivered to a local mailbox, so nothing accumulates in PurelyMail. PurelyMail publishes no hard storage limits (soft limits apply to unusually heavy usage); confirm current pricing at [purelymail.com/pricing](https://purelymail.com/pricing).

2. **Create the catch-all forwarding rule** — PurelyMail dashboard → **Routing rules** page in the account management portal → for **each domain**, one catch-all rule forwarding everything to `yourname.archive@gmail.com`. Routing rules match all incoming mail for the domain regardless of whether a corresponding user account exists, so no per-address mailboxes are needed.

3. **Gmail archive prep** — the archive is **read-side only**: the catch-all forward fills it, and Thunderbird does all the sending (step 7). Gmail's "Send mail as" feature for third-party addresses (a custom domain on PurelyMail SMTP is exactly that) is being removed in January 2027 — don't build on it. Do prep the account itself: enable 2-Step Verification and create an app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — the `imapsync` fast path in step 6 requires it.

4. **Verify forwarding BEFORE touching DNS** — send a test message to your PurelyMail **subdomain address** (`you@yourname.purelymail.com`). The custom domain's MX still points at Workspace, so a test to the custom domain cannot reach PurelyMail yet. Confirm the test lands in Gmail.

5. **DNS cutover at Route53 (per domain)**
   > **WARNING:** only after step 4 passes. Wrong records = mail loss or outbound spam-flagging. Each domain's Route53 zone gets its own record set:
   - **MX:** `@` → `mailserver.purelymail.com`, priority `50`
   - **SPF:** TXT at `@` → `v=spf1 include:_spf.purelymail.com ~all`
   - **DKIM:** three rotating CNAME keys — add all three at Route53:
     - `purelymail1._domainkey` → `key1.dkimroot.purelymail.com`
     - `purelymail2._domainkey` → `key2.dkimroot.purelymail.com`
     - `purelymail3._domainkey` → `key3.dkimroot.purelymail.com`

     Per-domain key values are shown on the **Domains** page in the PurelyMail management portal — confirm before saving.
   - **DMARC:** minimum TXT at `_dmarc` → `v=DMARC1; p=none;` — or use PurelyMail's DMARC CNAME: `_dmarc` → `dmarcroot.purelymail.com`.
   > Confirm current record values against [purelymail.com/docs/domainDocs](https://purelymail.com/docs/domainDocs) — provider requirements change, and DKIM keys rotate.
   > **Rollback:** MX changes are reversible within the record TTL — a botched cutover loses nothing.

6. **Import historical Workspace mail** — the Workspace mailbox dies at cancellation; anything not imported is gone forever. Start this early; it runs in the background.
   - **Zero extra tools:** Google Takeout → select only **Mail** → download the `.mbox` archives → Thunderbird: Tools → Import → Mail files → import each `.mbox`. Drag the imported folders onto the Gmail archive account's folders to copy the mail server-side (slow for large mailboxes; hands-off once started).
   - **Legacy:** Gmail's "Check mail from other accounts" (POP fetch) is being removed — new users after Q1 2026 can't enable it, and existing users lose it in January 2027. Don't rely on it for new setups.
   - **Fast path:** `imapsync` on the homelab. Requires 2FA + app passwords on **both** accounts: turn on 2-Step Verification, then create a 16-digit app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — app passwords require 2SV, and on Google Workspace the option can be disabled by your admin. Resumable by default — safe to re-run:
     ```bash
     imapsync --gmail1 --host1 imap.gmail.com --user1 you@yourdomain.com \
              --password1 "WORKSPACE-APP-PASSWORD" \
              --gmail2 --host2 imap.gmail.com --user2 yourname.archive@gmail.com \
              --password2 "GMAIL-APP-PASSWORD"
     ```

7. **Thunderbird setup (every device)** — desktop from [thunderbird.net](https://www.thunderbird.net); Android: Thunderbird for Android's stable release is on Google Play and F-Droid.
   - **Gmail account:** add with OAuth sign-in — no app password needed. It authenticates through Google's OAuth flow in your default browser; Workspace accounts behind Google Advanced Protection need an admin exception.
   - **PurelyMail account:** manual config — IMAP `imap.purelymail.com:993` SSL/TLS, SMTP `smtp.purelymail.com:465` SSL/TLS, app password (not the main password). Manual IMAP details are entered in the app's setup screen — verify the current screen labels in-app, as Mozilla's KB doesn't document them.
   - **One identity per domain address:** Account Settings → Gmail account → manage identities → add each custom-domain address (its own From; SMTP via PurelyMail). On reply, Thunderbird auto-selects the identity matching the original recipient — the "send from the address it was sent to" behavior Spark provided, with no third-party cloud.
   - **Verify read-state sync:** read a message on the phone, confirm it shows read on the desktop install. Read/deleted/starred state lives on the mail server (IMAP flags), so it syncs — no cloud middleman involved.
   - **Verify drafts** save to the server's Drafts folder on every device (Account Settings → Copies & Folders).

### Why not Spark?

Spark requires a Readdle account and routes your mail metadata — senders, subjects, snippets — through Readdle's cloud to power its smart features. That puts a third party in your mail path, the same category of problem this guide exists to remove. Its headline feature — replying from the address a message was sent to — is covered by Thunderbird's per-domain identity auto-selection (step 7). Spark remains a reasonable choice if you prefer its UX and accept the trade-off. **FairEmail** (F-Droid / Play Store) is the Android power-user alternative: direct IMAP only, hard privacy defaults by design.

## Deliverability Verification

1. Send test mail from Thunderbird (via PurelyMail SMTP) to [mail-tester.com](https://www.mail-tester.com); check the score page shows `spf=pass dkim=pass dmarc=pass`.
2. Send a message to your custom-domain address from an external account; confirm it arrives in Thunderbird via the catch-all → Gmail path.

---

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)
