---
---
# 02 — Email Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)

1. **Set up the generic Gmail account** — create `yourname.forward@gmail.com`, enable 2FA.
   > **Note:** This account is now load-bearing — protect it accordingly.

2. **Create the PurelyMail account** — sign up at [purelymail.com](https://purelymail.com), add your custom domain (or their subdomain).
   > **Android:** do this in Chrome; the dashboard is desktop-oriented but works on mobile.

3. **Workspace routing rule** — Admin Console → Apps → Google Workspace → Gmail → Routing; rule "PurelyMail Forward" → send to `yourname.forward@gmail.com`, apply to selected users/domain.
   > **Android:** navigate admin.google.com in Chrome; menu paths may differ slightly on mobile — use desktop if available.

4. **Gmail-side forwarding** — generic Gmail → Settings → See all settings → Forwarding and POP/IMAP → add + verify the PurelyMail address → "Forward a copy".

5. **Spark Mail setup** — install ([sparkmailapp.com](https://sparkmailapp.com) / App Store / Google Play), create Spark account (Apple/Google sign-in) — this is the "Email for Sync". Add primary Gmail via **OAuth** (no app password). Add PurelyMail as "Other Mail" with an **app password** (not the main password): IMAP `imap.purelymail.com:993` SSL/TLS, SMTP `smtp.purelymail.com:465` SSL/TLS.

6. **Send-through routing** — Spark → Settings → Accounts → PurelyMail account set as send-through when the from-address matches your domain.

   **Verified Flow:**
   - **Receiving:** Workspace → Gmail (forwarding) → Spark (OAuth read)
   - **Sending:** Spark → PurelyMail SMTP → recipients

## DNS Configuration

> **WARNING:** do this before switching mail flow; wrong records = outbound mail marked spam.

- **MX:** PurelyMail incoming servers ([link docs](https://purelymail.com/docs))
- **SPF:** include `include:purelymail.com`
> Confirm current records against https://purelymail.com/docs — provider requirements change.
- **DKIM:** key generated in PurelyMail dashboard → TXT record
- **DMARC:** `v=DMARC1; p=none;` minimum

## Deliverability Verification

Send test mail from Spark (via PurelyMail SMTP) to an external address (e.g., a friend's Gmail or [mail-tester.com](https://www.mail-tester.com)), check headers show `spf=pass dkim=pass dmarc=pass`; send a test to the custom-domain address and confirm it arrives in Spark.

---

[← Overview & Strategy](01-overview) | [Next: Data Migration →](03-data-migration)
