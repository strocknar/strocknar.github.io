---
---
# Post-Migration & Cancellation

{% include guide-toc.html toc=site.data.de-google-toc %}

### 1. Spark Configuration Checklist
1. Gmail (OAuth) + PurelyMail (IMAP) accounts added
2. Unified Inbox on
3. Smart Inbox classification
4. Per-account signatures (Settings → Signatures → + New Signature, assign per account)
5. Smart notifications + quiet hours
6. Gatekeeper enabled
7. Default account set

### 2. Notify Contacts
Use the following template to inform your contacts of the change.

**Subject:** Important - Updated Communication Address

**Body:**
Please update your contact information with our new communication address.

I have completed my transition from Google Workspace and am now using Spark Mail with PurelyMail for email services.

My new working address is:
[Your Email Address]

You can continue to reach me using the same methods, but please update your contacts. My old Google Workspace address will remain functional (forwarded) for the next 3 months.

### 3. Update Business Services
Ensure the following services are updated with your new address:
- [ ] Banking and financial services
- [ ] Subscriptions and memberships
- [ ] Professional services (LinkedIn, etc.)
- [ ] Website contact forms

### 4. Verification Checklist
Verify the migration is fully operational before proceeding to cancellation:
- [ ] **Email:** Test mail both directions works (mirrors §2 deliverability check)
- [ ] **Data:** Drive/Photos present on the generic account (mirrors §3 paths)
- [ ] **Credentials:** Vaultwarden autofill works on every device
- [ ] **Notes:** Keep collaborator copies in place

### 5. Cancellation
Once verification is complete, follow these steps to decommission Google Workspace:
1. **Wait 30 days** after the final verification check.
2. **Export final data** via Google Takeout if any last-minute changes occurred.
3. **Cancel Workspace** via Admin Console → Billing.

> **Note:** Once cancelled, Workspace mailboxes are gone → the forwarding rule dies with them; only the custom-domain MX records (now at PurelyMail) keep mail flowing.
