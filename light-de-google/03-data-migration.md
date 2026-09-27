---
---
# Data Migration

{% include guide-toc.html toc=site.data.de-google-toc %}

Everything migrates to the generic Gmail account; the paths below are ordered so hundreds of GB never touch your local connection — download-free paths first, rclone as the fallback.

1. **Google Drive — server-side copy (primary)** — Share top-level Drive folders with the generic Gmail account, then in the shared view select-all and "Make a copy" or move into the new account's own Drive. Copies happen inside Google — zero local bandwidth.
   > **Note:** If bulk copy hits limits, perform the operation per-folder.
   > **Alternative:** Use MultCloud for automated Drive $\rightarrow$ Drive transfer (verify current free-tier limits for your volume).

2. **Google Photos — Partner Sharing (primary)** — From the old account, enable partner sharing with the generic Gmail; on the receiving side, save copies in bulk.
   > **Caveats:** Verify the quality setting of saved copies; storage is counted on the receiving account.
   > **Alternative:** Use MultCloud Google Photos transfer.

3. **Contacts & Calendar — Takeout (tiny, download is fine)** — Use Google Takeout to export these small datasets.
   1. Google Takeout $\rightarrow$ select only Contacts + Calendar.
   2. Download the resulting archive.
   3. Import `.vcf` into Google Contacts and `.ics` into Google Calendar on the generic account.

4. **Docs/Sheets/Slides — Takeout export** — Export specialized Google formats to standard office formats (Docs $\rightarrow$ .docx/.odt, Sheets $\rightarrow$ .xlsx, Slides $\rightarrow$ .pptx).
   > **Limitations:** Comments, revision history, and some embedded features do not survive export.
   > **Homelab Note:** If the new consumer of these files is your homelab, note they will land in the migrated Drive copy.

5. **Fallback — rclone on the homelab** — If the above paths are unsuitable, use rclone on a local server to move data between accounts.

```bash
# Configure two remotes: old account, then new account
rclone config
#   gsrc -> drive  (OAuth as the OLD account)
#   gdst -> drive  (OAuth as the generic Gmail account)

# Preview, then copy (use copy, not sync, first — verify before pruning)
rclone copy gsrc: gdst: --drive-root-folder-id root --progress -v
```

> **WARNING:** This transfers at line rate through the homelab's connection — fine for tens of GB, expensive for hundreds. Prefer the no-download paths above.
> **Note:** `rclone sync` deletes files at the destination if they aren't at the source; use `copy` until you have verified the migration.
