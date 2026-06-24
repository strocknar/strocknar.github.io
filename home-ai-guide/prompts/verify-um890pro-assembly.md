# Verify UM890 Pro Assembly Documentation

Audit the Minisforum UM890 Pro hardware claims in a home AI guide by cross-referencing official specs, user manuals, and published teardown reviews — then produce a structured findings report with source citations and suggested edits.

## Role

You are a hardware researcher with access to web search and local file reads. Your job is to verify technical accuracy — not to praise, soften, or hedge findings. If something in the guide is wrong, say so directly and provide the correction.

## Files to Read

Read these files before searching the web. You need the exact text so your findings reference specific lines, not paraphrases.

| File | Purpose |
|---|---|
| `/Users/rvanklee/projects/github/strocknar.github.io/home-ai-guide/01-hardware-assembly.md` | Primary file to verify — assembly steps, BIOS settings, NVMe slots, RAM slots |
| `/Users/rvanklee/projects/github/strocknar.github.io/home-ai-guide/07-egpu-setup.md` | References the 780M iGPU and OCuLink port |
| `/Users/rvanklee/projects/github/strocknar.github.io/home-ai-guide/README.md` | Hardware spec table — Ryzen 9 8945HS, DDR5-5600, 780M iGPU |

## Research Tasks

Search for the following sources in order of preference. Retrieve at least three independent sources before writing findings.

1. **Official Minisforum product page** for the UM890 Pro — `minisforum.com` — specs tab, user manual PDF, and any listed FAQ
2. **Minisforum UM890 Pro user manual** or quick-start guide (often hosted on minisforum.com or linked from the product page)
3. **Hardware teardown reviews** from sources such as Serve The Home, NotebookCheck, or YouTube teardown videos with documented specs
4. **Forum threads** on r/MiniPCs, r/homelab, or Proxmox forums where users report UM890 Pro BIOS settings, RAM compatibility, or OCuLink behavior
5. **AMD Ryzen 9 8945HS official spec sheet** from amd.com — to verify the iGPU model and architecture

## Claims to Verify

Verify each claim against your research findings. Map every finding to a source URL or document name.

| # | Claim | Location in Guide |
|---|---|---|
| 1 | Bottom panel held by **4 screws** | `01-hardware-assembly.md` §1.1 |
| 2 | Has **2 NVMe slots** (M.2 2280, PCIe 4.0) | `01-hardware-assembly.md` §1.3 |
| 3 | Uses **DDR5-5600 SO-DIMM** in **2 slots** | `01-hardware-assembly.md` §1.2, README hardware table |
| 4 | iGPU is **Radeon 780M** (gfx1103, RDNA 3) | `07-egpu-setup.md` multiple references |
| 5 | Has an **OCuLink port** for the DEG1 eGPU dock | `01-hardware-assembly.md` §3.2, README hardware table |
| 6 | BIOS has **AMD-Vi / IOMMU** setting | `01-hardware-assembly.md` §Phase 2 BIOS table |
| 7 | Boot entry key is **F7 or F11** | `01-hardware-assembly.md` §1.5 (implied via "Delete or F2" for BIOS — check if F7/F11 is boot menu) |
| 8 | RAM max capacity ceiling is **96GB** | `11-upgrading.md` (referenced in upgrade path) |
| 9 | **Above 4G Decoding** setting is available in BIOS | `01-hardware-assembly.md` §Phase 2 BIOS table |
| 10 | **Wake on LAN** is supported | `01-hardware-assembly.md` §Phase 2 Recommended settings table |

> Note on Claim 7: `01-hardware-assembly.md` §1.5 states BIOS entry via `Delete` or `F2`. The boot menu key (F7 or F11) is a separate key. Verify both.

## Output Format

Produce a Markdown report with the following structure. Do not summarize — populate every row with a specific finding.

---

### UM890 Pro Assembly Documentation — Verification Report

**Date:** [date you ran this]  
**Sources consulted:** [numbered list of all URLs and documents you retrieved]

---

#### Findings

For each claim, use one of these statuses:

- **Confirmed** — at least two independent sources agree with the guide
- **Needs Correction** — one or more sources contradict the guide; provide the correct value
- **Unverified** — no reliable source found; explain what you searched and why it was inconclusive

| # | Claim | Status | Finding | Source(s) |
|---|---|---|---|---|
| 1 | 4 screws on bottom panel | | | |
| 2 | 2× NVMe slots (M.2 2280, PCIe 4.0) | | | |
| 3 | DDR5-5600 SO-DIMM, 2 slots | | | |
| 4 | Radeon 780M iGPU (gfx1103, RDNA 3) | | | |
| 5 | OCuLink port present | | | |
| 6 | AMD-Vi / IOMMU in BIOS | | | |
| 7 | BIOS key: Delete or F2 / Boot menu key | | | |
| 8 | RAM max 96GB | | | |
| 9 | Above 4G Decoding in BIOS | | | |
| 10 | Wake on LAN support | | | |

---

#### Suggested Edits

For every claim with status **Needs Correction** or **Unverified**, provide a concrete edit in this format:

**Claim [#] — [short label]**

- **File:** `[filename]`
- **Current text:** exact quote from the guide
- **Suggested replacement:** the corrected text
- **Rationale:** one sentence explaining what the source says and why this change is warranted

If all claims are confirmed, write: "No edits required — all claims verified."

---

#### Confidence Assessment

Close with a one-paragraph summary of overall documentation confidence. Note any areas where sources were sparse or conflicting, and identify any claims that require a physical unit to confirm definitively.
