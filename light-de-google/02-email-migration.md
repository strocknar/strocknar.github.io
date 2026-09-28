---
---
# 02 — Email Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)

1. **Create the free Gmail archive account** — Chrome → [accounts.google.com/SignUp](https://accounts.google.com/SignUp). Pick a name you can live with: this becomes the permanent archive for mail, files, photos, and contacts. Save the credentials in your password manager (§4).

2. **Create the PurelyMail account** — sign up at [purelymail.com](https://purelymail.com), add **each** custom domain you want on this inbox (one account holds multiple domains; their subdomain works too if you have none).
   > **Android:** do this in Chrome; the dashboard is desktop-oriented but works on mobile.
   > **Why storage doesn't matter:** PurelyMail routing rules are permanent redirects — mail is sent on to the destination (your Gmail archive) instead of being delivered to a local mailbox, so nothing accumulates in PurelyMail. PurelyMail publishes no hard storage limits (soft limits apply to unusually heavy usage); confirm current pricing at [purelymail.com/pricing](https://purelymail.com/pricing).

3. **Create the catch-all forwarding rule** — PurelyMail dashboard → **Routing rules** page in the account management portal → for **each domain**, one catch-all rule forwarding everything to `yourname.archive@gmail.com`. Routing rules match all incoming mail for the domain regardless of whether a corresponding user account exists, so no per-address mailboxes are needed.

4. **Gmail archive prep** — the archive is **read-side only**: the catch-all forward fills it, and Thunderbird does all the sending (step 8). Gmail's "Send mail as" feature for third-party addresses (a custom domain on PurelyMail SMTP is exactly that) is being removed in January 2027 — don't build on it. Do prep the account itself: enable 2-Step Verification and create an app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — the `imapsync` fast path in step 7 requires it.

5. **Verify forwarding BEFORE touching DNS** — send a test message to your PurelyMail **subdomain address** (`you@yourname.purelymail.com`). The custom domain's MX still points at Workspace, so a test to the custom domain cannot reach PurelyMail yet. Confirm the test lands in Gmail.

6. **DNS cutover at Route53 (per domain)**
   > **WARNING:** only after step 5 passes. Wrong records = mail loss or outbound spam-flagging. Each domain's Route53 zone gets its own record set:
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

7. **Import historical Workspace mail** — the Workspace mailbox dies at cancellation; anything not imported is gone forever. Start this early; it runs in the background.

   > **Run the Transfer path below if Drive stays in Google (Track A)** — it moves mail and Drive (+ owned Photos) in one server-side shot, no desktop needed. **Skip it if Track B:** `imapsync` (or the Takeout path) here plus §3's rclone moves mail and Drive separately.

   - **Transfer path (no desktop needed; desktop readers can follow the same steps in a browser):**
     1. **Clear the inbox of the old account** — the Transfer sub-path copies **inbox mail only**, so archived mail must move into the inbox first. In Chrome, open [mail.google.com](https://mail.google.com) signed in to the **old** account, open the ⋮ browser menu → tick **Desktop site**, then:
        1. In the search bar type `-in:inbox` and press Enter.
        2. Click **Select all conversations that match this search** above the results.
        3. Click **Move to Inbox**.
        > **Why this works:** in Gmail the inbox is just a label — "moving to inbox" costs no space and makes every message transferable. SPAM and Trash are excluded, which is what you want.
        > Large mailboxes take a while to process; the screen may sit on "Working…" for several minutes.
     2. **Run Google's transfer — mail + Drive, server-side** — Chrome → [takeout.google.com/transfer](https://takeout.google.com/transfer) signed in to the **old** account:
        > **Eligibility:** Google's docs describe this tool as Education-only; in practice it also works on paid Workspace accounts (this guide ran it on one). If the tool refuses your account, fall back to the Takeout + Thunderbird import path below in this step.
        1. Enter the new Gmail address → **Get confirmation code**. Open the code email from the **new** account (switch accounts in Chrome or use an incognito window), copy the code, paste it → **Verify**.
        2. **Check quota before starting:** the transfer copies your **entire My Drive** plus the inbox into the new account's 15GB pool. If the old account's usage ([one.google.com/storage](https://one.google.com/storage)) won't fit in the new account's free space, either delete what you don't need or add a [Google One plan](https://one.google.com/about/plans) to the **new** account first — a full quota fails the transfer (and later bounces your mail — §3's quota check).
        3. **Start transfer.** It runs server-side inside Google — up to a week for large accounts; you can cancel within the first 3 hours.
        > **What transfers:** all My Drive files (ownership moves; Docs/Sheets/Slides stay in Google format with comments intact), your owned Google Photos (added 2026 — albums come along), and inbox mail, which arrives with its labels intact plus an `Imported <date>` marker label.
        > **What doesn't:** Calendar, Contacts — §3 steps 3–4 handle those.
        > **What the transfer skips — Shared Drives and sharing edges.** The transfer copies **My Drive only**. Shared Drives are not transferred and are deleted at cancellation — copy their contents into your own My Drive before the transfer, copy them out with rclone (§3 Track B, step 2), or ask the Workspace admin for a Data export. Files **owned by other people** stay with their owners — copy out anything you rely on before cancellation. Reverse direction: files this account **owns and shares outward** keep working until cancellation, then every share link breaks — recipients need copies of anything they want to keep.
     3. **Restore the new inbox** — when the "transfer complete" email arrives in the new account: [mail.google.com](https://mail.google.com) → Desktop site on → search `in:inbox` → **Select all conversations that match this search** → **Archive**. The inbox is empty and usable; everything lives under the `Imported` label.
     4. **Verify the copy** — Transfer confirmation email received; Drive files open in the new account; the `Imported` label's message count matches the old account's All Mail count.
   - **Zero extra tools (desktop):** Google Takeout → select only **Mail** → download the `.mbox` archives → Thunderbird: Tools → Import → Mail files → import each `.mbox`. Drag the imported folders onto the Gmail archive account's folders to copy the mail server-side (slow for large mailboxes; hands-off once started).
   - **Legacy:** Gmail's "Check mail from other accounts" (POP fetch) is being removed — new users after Q1 2026 can't enable it, and existing users lose it in January 2027. Don't rely on it for new setups.
   - **Fast path:** `imapsync` on the homelab. Requires 2FA + app passwords on **both** accounts: turn on 2-Step Verification, then create a 16-digit app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — app passwords require 2SV, and on Google Workspace the option can be disabled by your admin. Resumable by default — safe to re-run:
     ```bash
     imapsync --gmail1 --host1 imap.gmail.com --user1 you@yourdomain.com \
              --password1 "WORKSPACE-APP-PASSWORD" \
              --gmail2 --host2 imap.gmail.com --user2 yourname.archive@gmail.com \
              --password2 "GMAIL-APP-PASSWORD"
     ```

8. **Thunderbird setup (every device)** — desktop from [thunderbird.net](https://www.thunderbird.net); Android: Thunderbird for Android's stable release is on Google Play and F-Droid.
   - **Gmail account:** add with OAuth sign-in — no app password needed. It authenticates through Google's OAuth flow in your default browser; Workspace accounts behind Google Advanced Protection need an admin exception.
   - **PurelyMail account:** manual config — IMAP `imap.purelymail.com:993` SSL/TLS, SMTP `smtp.purelymail.com:465` SSL/TLS, app password (not the main password). Manual IMAP details are entered in the app's setup screen — verify the current screen labels in-app, as Mozilla's KB doesn't document them.
   - **One identity per domain address:** Account Settings → Gmail account → manage identities → add each custom-domain address (its own From; SMTP via PurelyMail). On reply, Thunderbird auto-selects the identity matching the original recipient — the "send from the address it was sent to" behavior Spark provided, with no third-party cloud.
   - **Verify read-state sync:** read a message on the phone, confirm it shows read on the desktop install. Read/deleted/starred state lives on the mail server (IMAP flags), so it syncs — no cloud middleman involved.
   - **Verify drafts** save to the server's Drafts folder on every device (Account Settings → Copies & Folders).

### Why not Spark?

Spark requires a Readdle account and routes your mail metadata — senders, subjects, snippets — through Readdle's cloud to power its smart features. That puts a third party in your mail path, the same category of problem this guide exists to remove. Its headline feature — replying from the address a message was sent to — is covered by Thunderbird's per-domain identity auto-selection (step 8). Spark remains a reasonable choice if you prefer its UX and accept the trade-off. **FairEmail** (F-Droid / Play Store) is the Android power-user alternative: direct IMAP only, hard privacy defaults by design.

## Deliverability Verification

1. Send test mail from Thunderbird (via PurelyMail SMTP) to [mail-tester.com](https://www.mail-tester.com); check the score page shows `spf=pass dkim=pass dmarc=pass`.
2. Send a message to your custom-domain address from an external account; confirm it arrives in Thunderbird via the catch-all → Gmail path.

---

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)
