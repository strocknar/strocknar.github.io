---
---
# 02 — Workspace-side Prework

{% include guide-toc.html toc=site.data.de-google-toc %}

[&larr; Overview & Strategy](./01-overview) | [Next: Migration &rarr;](03-migration)

This section covers everything you need to set up your new infrastructure *before* touching your existing Google Workspace configuration. The goal is to ensure your new email handler (PurelyMail) and archive (Gmail) are ready to receive mail and that your mail client (Thunderbird) is configured.

## 1. Create the free Gmail archive account
Chrome &rarr; [accounts.google.com/SignUp](https://accounts.google.com/SignUp). Pick a name you can live with: this becomes the permanent archive for mail, files, and photos. Save the credentials in your password manager (§4).

## 2. Create the PurelyMail account
Sign up at [purelymail.com](https://purelymail.com), add **each** custom domain you want on this inbox.
> **Android:** do this in Chrome; the dashboard is desktop-oriented but works on mobile.
> **Why storage doesn't matter:** PurelyMail routing rules are permanent redirects — mail is sent on to the destination (your Gmail archive) instead of being delivered to a local mailbox, so nothing accumulates in PurelyMail.

## 3. Create the catch-all forwarding rule
PurelyMail dashboard &rarr; **Routing rules** page in the account management portal &rarr; for **each domain**, one catch-all rule forwarding everything to `yourname.archive@gmail.com`. Routing rules match all incoming mail for the domain regardless of whether a corresponding user account exists.

## 4. Gmail archive prep
The archive is **read-side only**: the catch-all forward fills it, and Thunderbird does all the sending (step 8). Gmail's "Send mail as" feature for third-party addresses is being removed in January 2027 — don't build on it. Do prep the account itself: enable 2-Step Verification and create an app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — the `imapsync` fast path in step 7 requires it.

## 5. Verify forwarding BEFORE touching DNS
Send a test message to your PurelyMail **subdomain address** (`you@yourname.purelymail.com`). The custom domain's MX still points at Workspace, so a test to the custom domain cannot reach Pureint yet. Confirm the test lands in Gmail.

## 6. DNS cutover at Route53 (per domain)
> **WARNING:** only after step 5 passes. Wrong records = mail loss or outbound spam-flagging. Each domain's Route53 zone gets its own record set:
> - **MX:** `@` &rarr; `mailserver.purelymail.com`, priority `50`
> - **SPF:** TXT at `@` &rarr; `v=spf1 include:_spf.purelymail.com ~all`
> - **DKIM:** three rotating CNAME keys — add all three at Route53:
>   - `purelymail1._domainkey` &rarr; `key1.dkimroot.purelymail.com`
>   - `purelymail2._domainkey` &rarr; `key2.dkimroot.purelymail.com`
>   - `purelymail3._domainkey` &rarr; `key3.dkimroot.purelymail.com`
> - **DMARC:** minimum TXT at `_dmarc` &rarr; `v=DMARC1; p=none;` — or use PurelyMail's DMARC CNAME: `_dmarc` &rarr; `dmarcroot.purelymail.com`.
>
> **Rollback:** MX changes are reversible within the record TTL — a botched cutover loses nothing.

## 7. Thunderbird setup (every device)
Desktop from [thunderbird.net](https://www.thunderbird.net); Android: Thunderbird for Android's stable release is on Google Play and F4Droid.
- **Gmail account:** add with OAuth sign-in — no app password needed.
- **PurelyMail account:** manual config — IMAP `imap.purelymail.com:993` SSL/TLS, SMTP `smtp.purelymail.com:465` SSL/TLS, app password (not the main password). Manual IMAP details are entered in the app's setup screen.
- **One identity per domain address:** Account Settings &rarr; Gmail account &rarr; manage identities &rarr; add each custom-domain address (its own From; SMTP via PurelyMail). On reply, Thunderbird auto-selects the identity matching the original recipient.
- **Verify read-state sync:** read a message on the phone, confirm it shows read on the desktop install.

### Why not Spark?
Spark requires a Readdle account and routes your mail metadata through Readdle's cloud. That puts a third party in your mail path, the same category of problem this guide exists to remove.

---

[&larr; Overview & Strategy](./01-overview) | [Next: Migration &rarr;](03-migration)
