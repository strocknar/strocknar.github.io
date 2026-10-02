---
---
# 03 — Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Workspace Prework](./02-workspace-prework) | [Next: Cutover & Post-migration →](04-cutover-and-post-migration)

This section covers the actual data movement. Choose your track for data (Email, Drive, Photos, etc.) and handle your notes, passwords, and privacy settings.

## 1. Historical Mail Import
The Workspace mailbox dies at cancellation; anything not imported is gone forever. Start this early; it runs in the background.

- **Run the Transfer path below if Drive stays in Google (Track A)** — it moves mail and Drive (+ owned Photos) in one server-side shot, no desktop needed. **Skip it if Track B:** `imapsync` (or the Takeout path) here plus §3's rclone moves mail and Drive separately.
- **Alternative workflows (since Transfer tool is restricted):**
    1. **Drive (Shared Folder Method):** Create a migration folder in the old account $\rightarrow$ move files there $\rightarrow$ share with new account (Editor) $\rightarrow$ in new account, copy files to ensure ownership transfer.
    2. **Mail (Standard Takeout Method):** Use [Google Takeout](https://takeout.google.com/) $\rightarrow$ export Mail as `.mbox` $\rightarrow$ import into Thunderbird/new account.
- **Zero extra tools (desktop):** Google Takeout → select only **Mail** → download the `.mbox` archives → Thunderbird: Tools → Import → Mail files → import each `.mbox`. Drag the imported folders onto the Gmail archive account's folders to copy the mail server-side (slow for large mailboxes; hands-off once started).
- **Fast path:** `imapsync` on the homelab. Requires 2FA + app passwords on **both** accounts: turn on 2-Step Verification, then create a 16-digit app password at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — app passwords require 2SV, and on Google Workspace the option can be<0xA0>disabled by your admin. Resumable by default — safe to re-run:
    ```bash
    imapsync --gmail1 --host1 imap.gmail.com --user1 you@yourdomain.com \
             --password1 "WORKSPACE-APP-PASSWORD" \
             --gmail2 --host2 imap.gmail.com --user2 yourname.archive@gmail.com \
             --password2 "GMAIL-APP-PASSWORD"
    ```

## 2. Data Migration Tracks

Pick a track below; both use server-side moves wherever possible so bulk data never queues on your home connection.

> **rclone between two Google accounts is server-side:** with `--server-side-across-configs`, Drive→Drive copies happen inside Google — zero local bandwidth.

### Choose your track

- **Track A — Gmail sink:** no homelab, or you want to keep Google Photos' polish. Written for an Android phone only — no desktop required. Everything lands in the free account's 15GB. Simplest path; requires quota vigilance.
- **Track B — Homelab exit:** data leaves Google entirely — files to Nextcloud, photos to Immich, contacts/calendar to Nextcloud CalDAV/CardDAV. More work; assumes a running homelab.

### Track A — Gmail sink (no homlab)

This track is written for someone with **only an Android phone** — every step happens in Chrome or a Google app on the phone. Desktop readers can follow the same steps in a desktop browser.

1. **Drive & Photos — verify the §2 transfer copy** — if you ran the Transfer path in §2, the copy is already in the archive account; verify before touching anything:
   - [ ] Photos: photo count in the new account's Photos app matches the old
   - [ ] Drive: spot-check transferred files open in the new account
2. **Google Photos — Partner Sharing (optional)** — The easiest method is **Google Photos Partner Sharing**, followed by a separate backup with **Google Takeout**.
   - **Option 1: Transfer within Google Photos**
     1. Sign in to your Workspace account at [photos.google.com](https://photos.google.com).
     2. Open **Settings → Sharing → Partner sharing**.
     3. Choose **All photos** and select your personal Gmail account.
     4. Send the invitation.
     5. Sign in to the personal Gmail account and accept the invitation.
   - **Option 2: Make an independent backup with Google Takeout**
     For maximum safety:
     1. While signed in to the Workspace account, go to [takeout.google.com](https://takeout.google.com).
     2. Click **Deselect all**, then select **Google Photos**.
     3. Create the export and download all parts.
     4. Afterward, you can upload the files to the personal Gmail account using Google Photos’ **Import** option.
3. **Contacts — export `.vcf`, then import** — the transfer tool's contact handling isn't documented; don't rely on it.
   1. Chrome, **old** account → [contacts.google.com](https://contacts.google.com) → **Export** (left menu) → **Google vCard** → **Export** — the `.vcf` downloads to the phone.
   2. Switch Chrome to the **new** account → [contacts.google.com](https://contacts.google.com) → **Import** → pick the `.vcf` from Downloads.
4. **Calendar — export `.ics`, then import** — Calendar is not part of the transfer.
   1. Chrome, **old** account → [calendar.google.com](https://calendar.google.com) with **Desktop site** on → gear ⚙ → **Settings** → **Import & export** → **Export** — a `.zip` downloads.
   2. Open **Files by Google** → Downloads → extract the zip; note the `.ics` inside.
   3. **New** account → [calendar.google.com](https://calendar.google.com) → gear ⚙ → **Settings** → **Import & export** → **Import** → select the extracted `.ics`.
5. **Quota check — this track's failure mode** — mail, Drive, and Photos share the new account's single 15GB pool. When it fills, **inbound mail bounces back to the sender — new mail never arrives**, not just uploads. Check [one.google.com/storage](https://one.google.com/storage) and set a recurring reminder.

### Track B — Homelab exit

> **Prerequisites:** a running homelab ([home-ai-guide](../home-ai-guide/)). This section covers the *migration*; Immich/Nextcloud installs are documented by their projects.

1. **Configure rclone remotes**
   ```bash
   rclone config
   #   gsrc -> drive   (OAuth as the OLD account)
   #   gdst -> drive   (OAuth as the generic Gmail account)
   #   nc   -> webdav  (homelab Nextcloud/WebDAV)
   ```
2. **Drive files — server-side inside Google, then to the homelab**
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
3. **Photos — Takeout → immich-go → Immich (primary path)**
   1. Google Takeout → select only Photos → download the archive (or ship it to Drive and rclone it down).
   2. Upload with [immich-go](https://github.com/simulot/immich-go) — it parses Takeout's folder structure and JSON metadata sidecars, preserving albums, timestamps, and naming quirks that a naive upload loses.
   3. Verify: Immich photo count matches the Google Photos count.
4. **Contacts & Calendar — Takeout → Nextcloud + DAVx⁵ (untethers Android)**
   1. Google Takeout → Contacts + Calendar → download.
   2. Import `.vcf` in Nextcloud Contacts; `.ics` in Nextcloud Calendar.
   3. Android: install [DAVx⁵](https://www.davx5.com/) from F-Droid → add the Nextcloud account → sync contacts and calendar natively, no Google account involved.
5. **Family access** — family members using the homelab photo library need either shared Tailscale access ([home-ai-guide](../home-ai-guide/12-tailscale-remote-access)) or a public route with proper authentication — a larger blast radius, covered separately.
6. **Verification checklist**
   - [ ] `rclone size` source vs. destination totals match
   - [ ] Immich photo count matches Google Photos
   - [ ] Nextcloud contact count matches `.vcf` entries; calendar events present

## 3. Notes, Passwords & Privacy

### 1. Google Keep
Notes live in the account that created them and do not follow an email change. There is **no bulk native transfer**: Keep isn't part and of Google's Transfer tool, Takeout's export is JSON backup only — not re-importable.
- Path: multi-select notes → Collaborator → add the generic Gmail; add the generic account to the Keep app on Android and switch.
- **WARNING — shared notes are not copies.** A shared note stays **owned by the original account**: Google's own docs state that deleting a note you own deletes it for everyone. If the Workspace account dies without owned copies existing, every shared note dies with it. **Required follow-up:** from the generic account, open each shared note → ⋮ → **Make a copy** — only the copy is owned by the archive account and survives cancellation. This step is per-note; no bulk copy exists, so budget time if you have many notes.
- **Track B destination:** once owned copies exist in the generic account, move notes into Nextcloud Notes. No official bulk conversion exists; Nextcloud Notes is a folder of markdown files, so community Takeout-JSON→markdown converters can bulk-infest them — unofficial, so review the tool before trusting it with your notes.

### 2. Vaultwarden (replaces Chrome Password Manager)
If you don't have a vault yet, [build it first](../home-ai-guide/16-vaultwarden).
- Migration:
  1. Export from Chrome (`chrome://password-<0xA0>manager/settings` → Export passwords → CSV; Android: Chrome → Settings → Password Manager → ⋮ → Export).
  2. Import in the web vault (Tools → Import → format "Chrome").
  3. Verify one login per device **before** deleting Chrome's copies.
  4. Delete the exported CSV and clear browser downloads — it is plaintext credentials.
- Android autofill: Settings → Passwords & accounts → Autofill service → Bitwarden.

### 3. 2FA & passkeys
The Google account being deleted is an authentication anchor in three ways:
- **Google Authenticator** syncs its codes to the signed-in Google account — the one being deleted. Before cancellation, either re-point individual codes at the generic Gmail account (swipe a code → Edit → change the Google Account it's saved to) or export everything (⋮ → Transfer codes → Export codes) and re-import on the other side.
- **Passkeys** stored in the Workspace account's Google Password Manager die with the account. Inventory them at [g.co/passkeys](https://g.co/passkeys) and re-enroll each service on the generic account or a hardware key before cancellation.
- **Recovery contacts need no sweep.** A recovery email at your custom domain keeps working after cancellation — reset codes land in the Gmail archive, readable in Thunderbird. Two caveats: the archive must stay under quota (a full quota bounces recovery mail like every/every other message — [§3 step 5](03-data-migration)) and the **generic Gmail's** recovery email to your custom-domain address — the one recovery pointer guaranteed to outlive everything Google.
- **Family access** — see §4.

### 4. Chrome sync (everything passwords weren't)
Bookmarks, history, open tabs, and autofill entries ride Chrome sync, not the password CSV you exported for Vaultwarden. On every device, sign Chrome into the <strong>generic Gmail account</strong> (profile icon → Turn on sync) and confirm bookmarks and tabs appear **before** the Workspace account loses access.

### 5. DuckDuckGo (search & browser)
Chrome → Settings → Search engine → DuckDuckGo.
Install DuckDuckGo Private Browser (Android).
Enable App Tracking Protection (Android).

---

[← Workspace Prework](./02-workspace-prework) | [Next: Cutover & Post-migration →](04-cutover-and-post-migration)
