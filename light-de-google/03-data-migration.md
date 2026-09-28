---
---
# 03 — Data Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Email Migration](02-email-migration) | [Next: Notes, Passwords & Privacy →](04-notes-passwords-privacy)

Pick a track below; both use server-side moves wherever possible so bulk data never queues on your home connection.

> **rclone between two Google accounts is server-side:** with `--server-side-across-configs`, Drive→Drive copies happen inside Google — zero local bandwidth. Earlier guides (including previous versions of this one) wrongly warned this always transits your connection. The flag is available since rclone 1.60 and replaces the deprecated `--drive-server-side-across-configs`. Both remotes must be Google Drive remotes; server-side copies between differently-configured Drive remotes are best-effort, which is why the flag is off by default.

## Choose your track

- **Track A — Gmail sink:** no homelab, or you want to keep Google Photos' polish. Written for an Android phone only — no desktop required. Everything lands in the free account's 15GB. Simplest path; requires quota vigilance.
- **Track B — Homelab exit:** data leaves Google entirely — files to Nextcloud, photos to Immich, contacts/calendar to Nextcloud CalDAV/CardDAV. More work; assumes a running homelab.

The tracks are independent — run A now and B later if you want.

## Track A — Gmail sink (no homelab)

This track is written for someone with **only an Android phone** — every step happens in Chrome or a Google app on the phone, and nothing is downloaded except two tiny files (`.vcf`, `.ics`). Desktop readers can follow the same steps in a desktop browser.

1. **Drive & Photos — verify the §2 transfer copy** — if you ran the Transfer path in §2, the copy is already in the archive account; verify before touching anything:
   - [ ] Photos: photo count in the new account's Photos app matches the old
   - [ ] Drive: spot-check transferred files open in the new account

2. **Google Photos — Partner Sharing (optional)** — the transfer copies photos you own into the new account's Photos library, so for owned photos this step is now optional. Run it anyway if you have partner-shared photos you don't own, or want Auto-save to keep copying new shots going forward.
   1. In the Photos app on the **old** account: Photos settings → **Partner sharing** → share with the new Gmail address. Choose **All photos** so nothing is left behind.
   2. Accept the invite from the **new** account and enable **Auto save to library**, so photos copied from now on land in your library automatically.
   3. Existing photos: open the partner's shared view in the **new** account, long-press to start selecting, tap **Save to library** per batch — there is no one-tap save-all.
   > **Huge libraries:** batch-saving thousands of photos is painful. Instead, request a Google Takeout export of **Photos only** with delivery **Add to Drive** ([takeout.google.com](https://takeout.google.com)) **before** running the §2 Transfer path — the export lands in the old account's Drive as a `Takeout` folder, and the §2 transfer copies it to the new Drive. You get every original as files (not browsable in Photos), and can still run the partner-sharing save afterwards for the polished copy.

3. **Contacts — export `.vcf`, then import** — the transfer tool's contact handling isn't documented; don't rely on it.
   1. Chrome, **old** account → [contacts.google.com](https://contacts.google.com) → **Export** (left menu) → **Google vCard** → **Export** — the `.vcf` downloads to the phone.
   2. Switch Chrome to the **new** account → [contacts.google.com](https://contacts.google.com) → **Import** → pick the `.vcf` from Downloads.

   Verify the contact count matches the `.vcf` export.

4. **Calendar — export `.ics`, then import** — Calendar is not part of the transfer.
   1. Chrome, **old** account → [calendar.google.com](https://calendar.google.com) with **Desktop site** on → gear ⚙ → **Settings** → **Import & export** → **Export** — a `.zip` downloads.
   2. Open **Files by Google** → Downloads → extract the zip; note the `.ics` inside.
   3. **New** account → [calendar.google.com](https://calendar.google.com) → gear ⚙ → **Settings** → **Import & export** → **Import** → select the extracted `.ics`.

   Spot-check a recurring event and a past event.

5. **Quota check — this track's failure mode** — mail, Drive, and Photos share the new account's single 15GB pool. When it fills, **inbound mail bounces back to the sender — new mail never arrives**, not just uploads. Check [one.google.com/storage](https://one.google.com/storage) and set a recurring reminder. Near the ceiling: a [Google One plan](https://one.google.com/about/plans), or move to Track B.

## Track B — Homelab exit

> **Prerequisites:** a running homelab ([home-ai-guide](../home-ai-guide/)). This section covers the *migration*; Immich/Nextcloud installs are documented by their own projects.

1. **Configure rclone remotes**
   ```bash
   rclone config
   #   gsrc -> drive   (OAuth as the OLD account)
   #   gdst -> drive   (OAuth as the generic Gmail account)
   #   nc   -> webdav  (homelab Nextcloud/WebDAV)
   ```

   > The `gdst` remote is the archive account created in §2.

2. **Drive files — server-side inside Google, then to the homelab**
   ```bash
   rclone copy gsrc: gdst: --server-side-across-configs --progress -v   # inside Google
   rclone copy gdst: nc:Documents/migrated --progress -v
   rclone check gsrc: nc:Documents/migrated           # verify before deleting anything
   ```
   > **WARNING:** never `rclone sync` until verified — sync deletes destination files missing at the source.
   >
   > Once `rclone check` passes, drain the intermediate copy — otherwise the full dataset stays in the mail-archive account's 15GB pool:
   ```bash
   rclone delete gdst: --rmdirs
   ```
   > Only safe once `rclone check` passes. If the archive account's Drive holds anything else you want to keep, delete only the migrated folders instead:
   ```bash
   rclone delete gdst:<folder> --rmdirs
   ```

   > **Shared Drives:** a My Drive remote cannot see them. In `rclone config`, create one Drive remote per Shared Drive — answer "y" at the "Configure this as a Shared Drive (Team Drive)?" prompt (config field `team_drive`) — then copy each to `nc:` exactly as above. The Workspace admin can also produce a Data export covering shared drives.

3. **Photos — Takeout → immich-go → Immich (primary path)**
   1. Google Takeout → select only Photos → download the archive (or ship it to Drive and rclone it down).
   2. Upload with [immich-go](https://github.com/simulot/immich-go) — it parses Takeout's folder structure and JSON metadata sidecars, preserving albums, timestamps, and naming quirks that a naive upload loses. immich-go (github.com/simulot/immich-go, currently v0.32.0, compatible with Immich V2 and V3) ingests Google Takeout zips directly:
   ```bash
   immich-go upload from-google-photos --server=<IMMICH-URL> --api-key=<KEY> /path/to/takeout-*.zip
   ```
   It matches each photo to its Takeout JSON sidecar to restore the original capture date, description, location, and album membership.
   3. Verify: Immich photo count matches the Google Photos count (check your photo count via Google Photos or the Google One storage manager; spot-check a few albums).
   > If you want Google Photos as the working copy meanwhile, also run the Track A partner-sharing path — but the Takeout archive is the migration source either way.

4. **Contacts & Calendar — Takeout → Nextcloud + DAVx⁵ (untethers Android)**
   1. Google Takeout → Contacts + Calendar → download.
   2. Import `.vcf` in Nextcloud Contacts; `.ics` in Nextcloud Calendar.
   3. Android: install [DAVx⁵](https://www.davx5.com/) from F-Droid → add the Nextcloud account → sync contacts and calendar natively, no Google account involved.
   4. Desktop: Thunderbird consumes both directly — CardDAV address book (Address Book → New → CardDAV) and CalDAV calendar (calendar tab → new calendar → on the network).

5. **Family access** — family members using the homelab photo library need either shared Tailscale access ([home-ai-guide §12](../home-ai-guide/12-tailscale-remote-access)) or a public route with proper authentication — a larger blast radius, covered separately.

6. **Verification checklist**
   - [ ] `rclone size` source vs. destination totals match
   - [ ] Immich photo count matches Google Photos
   - [ ] Nextcloud contact count matches `.vcf` entries; calendar events present
   - [ ] Android syncs contacts/calendar via DAVx⁵ with the Google account's sync toggles off

---

[← Email Migration](02-email-migration) | [Next: Notes, Passwords & Privacy →](04-notes-passwords-privacy)
