---
---
# 03 — Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[&larr; Workspace Prework](./02-workspace-prework) | [Next: Cutover & Post-migration &rarr;](04-cutover-and-post-migration)

This section covers the actual data movement. Choose your track for data (Email, Drive, Photos, etc.) and handle your notes, passwords, and privacy settings.

### Choose your track

- **Track A — Gmail sink:** no homelab, or you want to keep Google Photos’ polish. Written for an Android phone only — no desktop required. Everything lands in the free account’s 15GB. Simplest path; requires quota vigilance.
- **Track B — Homelab exit:** data leaves Google entirely — files to Nextcloud, photos to Immich, contacts/calendar to Nextcloud CalDAV/CardDAV. More work; assumes a running homelab.

### Track A — Gmail sink (no homelab)

This track is written for someone with **only an Android phone** — every step happens in Chrome or a Google app on the phone. Desktop readers can follow the same steps in a desktop browser.

1. **Historical mail — forward keepers, archive the rest** — bulk mail can’t be merged into the Gmail pool from a phone: Thunderbird for Android cannot import `.mbox` archives. The phone-only equivalent is two moves:
   1. **Forward the keepers:** in the Workspace Gmail, forward important messages to your custom-domain address — the PurelyMail catch-all set up in §2 lands them in the archive account.
   2. **Archive the bulk:** [takeout.google.com](https://takeout.google.com) → **Deselect all** → select **Mail** → export the `.mbox` zip → keep it in Drive or Downloads as a permanent backup, readable in any desktop Thunderbird.
   > **Desktop readers:** to merge bulk mail into the archive account instead, import the `.mbox` files (Thunderbird: Tools → Import → Mail files) and drag the folders onto the archive account’s IMAP folders — or run Track B’s `imapsync`.
2. **Drive (Shared Folder Method):**
   1. Create a migration folder in the old account
   2. Move files there
   3. Share with new account (Editor)
   4. In new account, copy files to ensure ownership transfer.
3. **Google Photos — Partner Sharing (optional)** — The easiest method is **Google Photos Partner Sharing**, followed by a separate backup with **Google Takeout**.
   - **Option 1: Transfer within Google Photos**
     1. Sign in to your Workspace account at [photos.google.com](https://photos.google.com).
     2. Open **Settings &rarr; Sharing &rarr; Partner sharing**.
     3. Choose **All photos** and select your personal Gmail account.
     4. Send the invitation.
     5. Sign in to the personal Gmail account and accept the invitation.
   - **Option 2: Make an independent backup with Google Takeout**
     For maximum safety:
     1. While signed in to the Workspace account, go to [takeout.google.com](https://takeout.google.com).
     2. Click **Deselect all**, then select **Google Photos**.
     3. Create the export and download all parts.
     4. Afterward, you can upload the files to the personal Gmail account using Google Photos’ **Import** option.
4. **Contacts — export `.vcf`, then import** — there is no automated contact transfer; don’t rely on one.
   1. Chrome, **old** account &rarr; [contacts.google.com](https://contacts.google.com) &rarr; **Export** (left menu) &rarr; **Google vCard** &rarr; **Export** — the `.vcf` downloads to the phone.
   2. Switch Chrome to the **new** account &rarr; [contacts.google.com](https://contacts.google.com) &rarr; **Import** &rarr; pick the `.vcf` from Downloads.
5. **Calendar — export `.ics`, then import** — no automated path exists for Calendar either.
   1. Chrome, **old** account &rarr; [calendar.google.com](https://calendar.google.com) with **Desktop site** on &rarr; gear ⚙ &rarr; **Settings** &rarr; **Import & export** &rarr; **Export** — a `.zip` downloads.
   2. Open **Files by Google** &rarr; Downloads &rarr; extract the zip; note the `.ics` inside.
   3. **New** account &rarr; [calendar.google.com](https://calendar.google.com) &rarr; gear ⚙ &rarr; **Settings** &rarr; **Import & export** &rarr; **Import** &rarr; select the extracted `.ics`.
6. **Quota check — this track’s failure mode** — mail, Drive, and Photos share the new account’s single 15GB pool. When it fills, **inbound mail bounces back to the sender — new mail never arrives**, not just uploads. Check [one.google.com/storage](https://one.google.com/storage) and set a recurring reminder.

Finish Track A by working through **Notes, Passwords & Privacy** and **Other Google Services** below — they apply to both tracks.

### Track B — Homelab exit

> **Prerequisites:** a running homelab ([home-ai-guide](../home-ai-guide/)). This section covers the *migration*; Immich/Nextcloud installs are documented by their projects.

1. **Historical mail — `imapsync` fast path.** Requires 2FA + app passwords on **both** accounts: turn on 2-Step Verification, then create a 16-digit app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — app passwords require 2SV, and on Google Workspace the option can be disabled by your admin. Resumable by default — safe to re-run:
   ```bash
   imapsync --gmail1 --host1 imap.gmail.com --user1 you@yourdomain.com \
            --password1 "WORKSPACE-APP-PASSWORD" \
            --gmail2 --host2 imap.gmail.com --user2 yourname.archive@gmail.com \
            --password2 "GMAIL-APP-PASSWORD"
   ```
   Alternative: Takeout → Mail → `.mbox` → desktop Thunderbird import → drag onto the archive account's IMAP folders (slow for large mailboxes; hands-off once started).
2. **Configure rclone remotes**
   ```bash
   rclone config
   #   gsrc -> drive   (OAuth as the OLD account)
   #   gdst -> drive   (OAuth as the generic Gmail account)
   #   nc   -> webdav  (homelab Nextcloud/WebDAV)
   ```
3. **Drive files — server-side inside Google, then to the homelab**
   ```bash
   rclone copy gsrc: gdst: --server-side-across-configs --progress -v   # inside Google
   rclone copy gdst: nc:Documents/migrated --progress -v
   rclone check gsrc: nc:Documents/migrated           # verify before deleting anything
   ```
   > **WARNING:** never `rclone sync` until verified — sync deletes destination files missing at the source.
   > Once `rclone check` passes, drain the intermediate copy — otherwise the full dataset stays in the mail-archive account's 15GB pool:
   ```bash
   rclone delete gdst: --rmdirs
   ```
4. **Photos — Takeout &rarr; immich-go &rarr; Immich (primary path)**
   1. Google Takeout &rarr; select only Photos &rarr; download the archive (or ship it to Drive and rclone it down).
   2. Upload with [immich-go](https://github.com/simulot/immich-go) — it parses Takeout's folder structure and JSON metadata sidecars, preserving albums, timestamps, and naming quirks that a naive upload loses.
   3. Verify: Immich photo count matches the Google Photos count.
5. **Contacts & Calendar — Takeout &rarr; Nextcloud + DAVx⁵ (untethers Android)**
   1. Google Takeout &rarr; Contacts + Calendar &rarr; download.
   2. Import `.vcf` in Nextcloud Contacts; `.ics` in Nextcloud Calendar.
   3. Android: install [DAVx⁵](https://www.davx5.com/) from F-Droid &rarr; add the Nextcloud account &rarr; sync contacts and calendar natively, no Google account involved.
6. **Family access** — family members using the homelab photo library need either shared Tailscale access ([home-ai-guide](../home-ai-guide/12-tailscale-remote-access)) or a public route with proper authentication — a larger blast radius, covered separately.
7. **Verification checklist**
   - [ ] `rclone size` source vs. destination totals match
   - [ ] Immich photo count matches Google Photos
   - [ ] Nextcloud contact count matches `.vcf` entries; calendar events present
   - [ ] Historical mail: `imapsync` transfer counts match the Workspace mailbox

## Notes, Passwords & Privacy

### Google Keep
Notes live in the account that created them and do not follow an email change. There is **no bulk native transfer**: Keep isn't part of Google's Transfer tool, Takeout's export is JSON backup only — not re-importable.
- Path: multi-select notes &rarr; Collaborator &rarr; add the generic Gmail; add the generic account to the Keep app on Android and switch.
- **WARNING — shared notes are not copies.** A shared note stays **owned by the original account**: Google's own docs state that deleting a note you own deletes it for everyone. If the Workspace account dies without owned copies existing, every shared note dies with it. **Required follow-up:** from the generic account, open each shared note &rarr; ⋮ &rarr; **Make a copy** — only the copy is owned by the archive account and survives cancellation. This step is per-note; no bulk copy exists, so budget time if you have many notes.
- **Track B destination:** once owned copies exist in the generic account, move notes into Nextcloud Notes. No official bulk conversion exists; Nextcloud Notes is a folder of markdown files, so community Takeout-JSON&rarr;markdown converters can bulk-ingest them — unofficial, so review the tool before trusting it with your notes.

### Vaultwarden (replaces Chrome Password Manager)
If you don't have a vault yet, [build it first](../home-ai-guide/16-vaultwarden).
- Migration:
  1. Export from Chrome (`chrome://password-manager/settings` &rarr; Export passwords &rarr; CSV; Android: Chrome &rarr; Settings &rarr; Password Manager &rarr; ⋮ &rarr; Export).
  2. Import in the web vault (Tools &rarr; Import &rarr; format "Chrome").
  3. Verify one login per device **before** deleting Chrome's copies.
  4. Delete the exported CSV and clear browser downloads — it is plaintext credentials.
- Android autofill: Settings &rarr; Passwords & accounts &rarr; Autofill service &rarr; Bitwarden.

### 2FA & passkeys
The Google account being deleted is an authentication anchor in three ways:
- **Google Authenticator** syncs its codes to the signed-in Google account — the one being deleted. Before cancellation, either re-point individual codes at the generic Gmail account (swipe a code &rarr; Edit &rarr; change the Google Account it's saved to) or export everything (⋮ &rarr; Transfer codes &rarr; Export codes) and re-import on the other side.
- **Passkeys** stored in the Workspace account's Google Password Manager die with the account. Inventory them at [g.co/passkeys](https://g.co/passkeys) and re-enroll each service on the generic account or a hardware key before cancellation.
- **Recovery contacts need no sweep.** A recovery email at your custom domain keeps working after cancellation — reset codes land in the Gmail archive, readable in Thunderbird. Two caveats: the archive must stay under quota (a full quota bounces recovery mail like every/every other message — [Track A quota check](#track-a--gmail-sink-no-homelab)) and the **generic Gmail's** recovery email to your custom-domain address — the one recovery pointer guaranteed to outlive everything Google.
- **Family access** — see §3 Track B step 6.

### Chrome sync (everything passwords weren't)
Bookmarks, history, open tabs, and autofill entries ride Chrome sync, not the password CSV you exported for Vaultwarden. On every device, sign Chrome into the <strong>generic Gmail account</strong> (profile icon &rarr; Turn on sync) and confirm bookmarks and tabs appear **before** the Workspace account loses access.

### DuckDuckGo (search & browser)
Chrome &rarr; Settings &rarr; Search engine &rarr; DuckDuckGo.
Install DuckDuckGo Private Browser (Android).
Enable App Tracking Protection (Android).

## Other Google Services

The migration steps above cover Mail, Drive, Photos, Contacts, Calendar, and Keep. Everything else Google knows about you lives in [Google Takeout](https://takeout.google.com) too — ~70 products, and **select-all is cheap insurance**: archive now, decide later.

### Before anything else: hidden app-data

Some of the most valuable data in your account is **invisible to Takeout**: Drive "app-data" — the hidden per-app storage used by **WhatsApp chat backups and some game saves**. It does not appear in the Shared Folder method or rclone copy, and it dies with the account. For each app that backs up to Google Drive, use its built-in transfer **before cancellation** — e.g. WhatsApp: Settings → Chats → **Transfer chats** to the new device/account. (Signal dropped Google Drive backups in 2020 — its backups are local files moved by Signal's own device-transfer, so it needs no Google-side sweep.) No Takeout export rescues this category.

### Google Voice — the unrecoverable number (do this before cancellation)

A Voice number on a deleted Google account is **gone for good**, and call history/voicemails never transfer with the number.

1. Workspace Voice numbers are **org-owned**. Free the number via the Workspace Admin console (transfer it to another account) — or unlock it at [voice.google.com](https://voice.google.com) → Settings → Unlock, then **port it to a personal carrier**.
2. Export anything worth keeping: Takeout → **Google Voice** (recordings as audio files + transcripts).
3. Timing matters: complete the port/transfer **before** the 30-day soak in §4 — a number on a cancelled account is unrecoverable.

### Sweep the rest

| Takeout item | Re-importable? | Note |
|---|---|---|
| Tasks, Reminders | No | Hand-copy active items to the generic account before cancelling |
| YouTube playlists | Via URL list | Export, then rebuild in the destination account |
| Google Pay / Play balance | N/A | Spend down any Play balance first |
| Fit, Timeline, My Activity, Chat | No | Archive-only; export for the record |
| Chrome sync, Passwords | Covered above | See Vaultwarden and Chrome sync sections |

---

[&larr; Workspace Prework](./02-workspace-prework) | [Next: Cutover & Post-migration &rarr;](04-cutover-and-post-migration)
