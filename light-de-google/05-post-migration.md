---
---
# 05 — Post-Migration & Cancellation

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Notes, Passwords & Privacy](04-notes-passwords-privacy)

### 1. Thunderbird Configuration Checklist
1. Gmail (OAuth) + PurelyMail (IMAP, app password) accounts added on every device
2. Unified inbox enabled
3. Per-identity signatures (Account Settings → signature text, per identity; custom-domain identity default)
4. Drafts save to the server Drafts folder on every device
5. Read-state sync verified: message read on the phone shows read on desktop
6. Notification settings configured per device (quiet hours, per-account alerts)
7. Test send from the custom-domain identity passes the §2 deliverability check

### 2. Notify Contacts
Use the following template to inform your contacts of the change.

```text
Subject: Updated contact information

Please note my preferred contact address:

[Your Email Address]

I have moved my email off Google Workspace. This address is unaffected by
the change and will keep working indefinitely — there is no cutoff date.
If you have an older address for me on a different domain, please replace
it with the one above.
```

### 3. Update Business Services
Ensure the following services are updated with your new address:
- [ ] Banking and financial services
- [ ] Subscriptions and memberships
- [ ] Professional services (LinkedIn, etc.)
- [ ] Website contact forms

### 4. Verification Checklist
Verify everything before proceeding to cancellation:
- [ ] **Email:** test mail both directions works (mirrors §2 deliverability check)
- [ ] **Historical mail:** imported Workspace mailbox counts match expectations (§2 step 6)
- [ ] **Data:** Track A (Gmail sink) or Track B (homelab) verification checklist passed
- [ ] **Credentials:** Vaultwarden autofill works on every device
- [ ] **Notes:** Keep collaborator copies in place
- [ ] **Quota:** Gmail archive storage comfortably below limit (a full quota bounces inbound mail)

### 5. Cancellation
Once verification is complete:
1. **Wait 30 days** after the final verification check, re-checking weekly that the catch-all forward shows no bounces.
2. **Export final data** via Google Takeout if any last-minute changes occurred.
3. **Cancel Workspace** via Admin Console → Billing.

> **Note:** Once cancelled, Workspace mailboxes are gone — anything not already imported (§2 step 6) is unrecoverable. Your custom-domain mail keeps flowing: the Route53 MX records point at PurelyMail, and the catch-all forward is independent of Workspace.

---

[← Notes, Passwords & Privacy](04-notes-passwords-privacy)

> **Done de-Googling?** Self-host the rest of the stack — inference, home automation, media — with the [Home AI Guide →](../home-ai-guide/).
