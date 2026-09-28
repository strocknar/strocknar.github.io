---
---
# 03 — Data Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

[← Email Migration](02-email-migration) | [Next: Notes, Passwords & Privacy →](04-notes-passwords-privacy)

Pick a track below; both use server-side moves wherever possible so bulk data never queues on your home connection.

> **rclone between two Google accounts is server-side:** with `--server-side-across-configs`, Drive→Drive copies happen inside Google — zero local bandwidth. Earlier guides (including previous versions of this one) wrongly warned this always transits your connection. The flag is available since rclone 1.60 and replaces the deprecated `--drive-server-side-across-configs`. Both remotes must be Google Drive remotes; server-side copies between differently-configured Drive remotes are best-effort, which is why the flag is off by default.

## Choose your track

- **Track A — Gmail sink:** no homelab, or you want to keep Google Photos' polish. Everything lands in the free account's 15GB. Simplest path; requires quota vigilance.
- **Track B — Homelab exit:** data leaves Google entirely — files to Nextcloud, photos to Immich, contacts/calendar to Nextcloud CalDAV/CardDAV. More work; assumes a running homelab.

The tracks are independent — run A now and B later if you want.

## Track A — Gmail sink (no homelab)

1. **Google Drive — server-side copy (primary)** — Share top-level Drive folders with the generic Gmail account, then in the shared view select-all and "Make a copy" or move into the new account's own Drive. Copies happen inside Google — zero local bandwidth.
   > **Alternative (automatable):** rclone with two Drive remotes (config in Track B step 1):
   ```bash
   rclone copy gsrc: gdst: --server-side-across-configs --progress -v
   ```
   > **Note:** If bulk copy hits limits, perform the operation per-folder.

2. **Google Photos — Partner Sharing (primary)** — From the old account, enable partner sharing with the generic Gmail; on the receiving side, save copies in bulk.
   > **Caveats:** Verify the quality setting of saved copies; storage counts on the receiving account.
   > **Alternative:** Use MultCloud Google Photos transfer.

3. **Docs/Sheets/Slides — Takeout export** — Export specialized Google formats to standard office formats (Docs → .docx/.odt, Sheets → .xlsx, Slides → .pptx).
   > **Limitations:** Comments, revision history, and some embedded features do not survive export.

4. **Contacts & Calendar — Takeout → import into Gmail** — Google Takeout → select only Contacts + Calendar → download → import `.vcf` into Google Contacts and `.ics` into Google Calendar on the generic account. (Track A accepts Google tethering by design.)

5. **Quota check — this track's failure mode** — the mail archive, Drive, and Photos all share one 15GB pool. When it fills, inbound mail forwarding **bounces — new mail is silently lost**, not just uploads. Check [one.google.com/storage](https://one.google.com/storage) and set a recurring reminder. Near the ceiling: a cheap Google One tier, or move to Track B.

## Track B — Homelab exit

> **Prerequisites:** a running homelab ([home-ai-guide](../home-ai-guide/)). This section covers the *migration*; Immich/Nextcloud installs are documented by their own projects.

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

3. **Photos — Takeout → immich-go → Immich (primary path)**
   1. Google Takeout → select only Photos → download the archive (or ship it to Drive and rclone it down).
   2. Upload with [immich-go](https://github.com/simulot/immich-go) — it parses Takeout's folder structure and JSON metadata sidecars, preserving albums, timestamps, and naming quirks that a naive upload loses. immich-go (github.com/simulot/immich-go, currently v0.32.0, compatible with Immich V2 and V3) ingests Google Takeout zips directly:
   ```bash
   immich-go upload from-google-photos --server=<IMMICH-URL> --api-key=<KEY> /path/to/takeout-*.zip
   ```
   It matches each photo to its Takeout JSON sidecar to restore the original capture date, description, location, and album membership.
   3. Verify: Immich photo count matches the Google Photos count (Google Photos → Settings shows your storage/item counts; spot-check a few albums).
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
