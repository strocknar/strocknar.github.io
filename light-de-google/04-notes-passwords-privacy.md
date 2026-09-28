---
---
# 04 — Notes, Passwords & Privacy

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Data Migration](03-data-migration) | [Next: Post-Migration & Cancellation →](05-post-migration)

1. **Google Keep** — Notes live in the account that created them and do not follow an email change. There is **no bulk native transfer**: Keep isn't part of Google's Transfer tool, Takeout's export is JSON backup only (not re-importable into Keep), and there is no admin ownership transfer for Keep (unlike Drive files).
   - Path: multi-select notes → Collaborator → add the generic Gmail; add the generic account to the Keep app on Android and switch.
   > **WARNING — shared notes are not copies.** A shared note stays **owned by the original account**: Google's own docs state that deleting a note you own deletes it for everyone. If the Workspace account dies without owned copies existing, every shared note dies with it. **Required follow-up:** from the generic account, open each shared note → ⋮ → **Make a copy** — only the copy is owned by the archive account and survives cancellation. This step is per-note; no bulk copy exists, so budget time if you have many notes.
   > **Caveat:** Takeout's Keep export is JSON backup only — not re-importable.
   - Track B destination: once owned copies exist in the generic account, move notes into Nextcloud Notes. No official bulk conversion exists; Nextcloud Notes is a folder of markdown files, so community Takeout-JSON→markdown converters can bulk-ingest them — unofficial, so review the tool before trusting it with your notes.

> Contacts and calendar destinations depend on your §3 track: Track A imports them to Gmail; Track B moves them to Nextcloud + DAVx⁵ instead ([see §3, Track B step 4](03-data-migration)).

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
