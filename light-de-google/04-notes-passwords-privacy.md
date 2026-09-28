---
---
# 04 — Notes, Passwords & Privacy

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Data Migration](03-data-migration) | [Next: Post-Migration & Cancellation →](05-post-migration)

1. **Google Keep** — Notes live in the account that created them and do not follow an email change.
   - Path: in each important note → Collaborator → add generic Gmail (the account then holds its own copy); add the generic account to the Keep app on Android and switch.
   > **Note:** No bulk native transfer exists; sharing is the practical path.
   > **Caveat:** Takeout's Keep export is JSON backup only — not re-importable.

2. **Vaultwarden (replaces Chrome Password Manager)** — If you don't have a vault yet, [build it first](../home-ai-guide/16-vaultwarden).
   - Migration:
     1. Export from Chrome (`chrome://password-manager/settings` → Export passwords → CSV; Android: Chrome → Settings → Password Manager → ⋮ → Export).
     2. Import in the web vault (Tools → Import → format "Chrome").
     3. Verify one login per device **before** deleting Chrome's copies.
     4. Delete the exported CSV and clear browser downloads — it is plaintext credentials.
   - Android autofill: Settings → Passwords & accounts → Autofill service → Bitwarden.

3. **DuckDuckGo (search & browser)** — Chrome → Settings → Search engine → DuckDuckGo.
   - Install DuckDuckGo Private Browser (Play Store / duckduckgo.com).
   - Enable App Tracking Protection (Android).
   - Optional: make it the default browser app.

---

[← Data Migration](03-data-migration) | [Next: Post-Migration & Cancellation →](05-post-migration)
