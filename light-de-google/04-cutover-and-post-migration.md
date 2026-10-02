---
---
# 04 — Cutover and Post-migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[&larr; Migration](./03-migration)

This section covers the final steps: verifying your new setup, notifying contacts, and the final destruction of the Google Workspace account.

### 1. Thunderbird Configuration Checklist
1. Gmail (OAuth) + PurelyMail (IMAP, app password) accounts added on every device
2. Unified inbox enabled
3. Per-identity signatures (Account Settings &rarr; signature text, per identity; custom-domain identity default)
4. Drafts save to the server Drafts folder on every device
5. Read-state sync verified: message read on the phone shows read on the desktop
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
- [ ] **Historical mail:** imported Workspace mailbox counts match expectations (§3, Track B step 1 — or Track A forward/mbox)
- [ ] **Data:** §3 track steps completed — Track A: Drive/Photos copies present, contacts/calendar imported, quota checked · Track B: §3 verification checklist passed
- [ ] **Credentials:** Vaultwarden autofill works on every device
- [ ] **Notes:** Keep collaborator copies in place
- [ ] **Quota:** Gmail archive storage comfortably below limit (a full quota bounces inbound mail)
- [ ] **Sign-ins:** no third-party service still authenticates via the Workspace Google account (§4 below, Retire Google Sign-In)
- [ ] **Recovery:** the generic Gmail's recovery email is set to the custom-domain address (§4)
- [ ] **Authenticator/passkeys:** migrated off the Workspace account (§4)
- [ ] **Chrome sync:** bookmarks/tabs confirmed synced under the generic account (§4)
- [ ] **Voice:** number ported, transferred, or explicitly abandoned (§3, Other Google Services)
- [ ] **App-data:** WhatsApp/Signal chat backups transferred in-app (§3, Other Google Services)

### 5. Retire Google Sign-In
The Google account is deleted at cancellation; your email address is not — it keeps working via PurelyMail. Any third-party service you log into with **"Sign in with Google"** against the Workspace account loses its login even though the address it displays still exists. Fix each one now:

1. **Enumerate:** [myaccount.google.com](https://myaccount.google.com) &rarr; **Security** &rarr; third-party connections page (label varies, currently "Your connections to third-party apps & services"). This lists all OAuth grants, revoke anything you don't recognize while you're here.
2. **For each service you sign into with Google, in order of preference:**
   - **Password login, same address** — set a password and keep the custom-domain address as the login ID. Works precisely because the address survives; nothing about your account at that service changes.
   - **Re-link to the generic Gmail's Google account** — for services that insist on Google sign-in and offer no password option.
   - **New account** — last resort, migrate data out if the service holds any.
3. **Gmail filters:** the §2 transfer carries labels but not filters. Export filters as XML (Gmail desktop &rarr; Settings &rarr; **Filters and Blocked Addresses** &rarr; select &rarr; Export) and re-import them in the archive account (**Import filters**)
4. **Google Voice:** if the Workspace account holds a Voice number, port or free it **before** cancellation — see §3, Other Google Services. (Moved there because it's data movement, not sign-in retirement.)

### 6. Cancellation
Once verification is complete:
1. **Wait 30 days** after the final verification check, re-checking weekly that the catch-all forward shows no bounces.
2. **Export final data** via Google Takeout if any last-minute changes occurred.
3. **Cancel Workspace** via Admin Console &rarr; Billing.

> **Note:** Once cancelled, Workspace mailboxes are gone — anything not already imported (§3 historical mail steps) is unrecoverable. Your custom-domain mail keeps flowing: the Route53 MX records point at PurelyMail, and the catch-all forward is independent of Workspace.

---

[&larr; Migration](./03-migration)
