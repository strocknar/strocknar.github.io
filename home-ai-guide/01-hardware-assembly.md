# 01 — Hardware Assembly

[← Overview](README.md) | [Next: Proxmox Installation →](02-proxmox-installation.md)

---

## What You'll Need

- Minisforum UM890 Pro (barebones unit or refurb)
- 2× Crucial 16GB DDR5-5600 SO-DIMM (sold as 32GB dual-channel kit)
- WD Black SN770 1TB M.2 2280 NVMe
- Phillips head screwdriver (small)
- Anti-static wrist strap (recommended)

---

## Phase 1: Mini PC Assembly

### 1.1 Open the Unit

The UM890 Pro uses a magnetic top cover for access. Flip the unit upside down, then slide the magnetic cover off. There are 4 screws at the corners of an internal shield. Unscrew those and carefully pull up the shield.

### 1.2 Install RAM

> **Critical:** Install both sticks for dual-channel. Single-channel halves iGPU memory bandwidth and cuts LLM inference speed in half (~7–9 tok/s vs ~15–18 tok/s on 7B models).

1. Align the SO-DIMM notch with the slot keying
2. Insert at ~30° angle, press down until both retention clips snap closed
3. Repeat for the second slot
4. Both sticks must be seated — verify clips are fully engaged on both sides

### 1.3 Install NVMe

1. Locate the M.2 2280 slot (primary slot)
2. Insert the SN770 at ~30° angle into the M.2 connector
3. Press flat and secure with the single retention screw

> The UM890 Pro has 2 NVMe slots total. One slot is used for the OCuLink card. The second should be used for the NVMe drive.

### 1.4 Reassemble

Replace the shield and screws. Do not overtighten. Then replace the top magnetic cover.

### 1.5 First Power-On Test

Before installing the eGPU, verify the base unit works:

1. Connect HDMI to a monitor
2. Connect USB keyboard
3. Power on — unit should POST and attempt to boot (will fail with no OS — this is expected)
4. Enter BIOS (typically `Delete` or `F2` on first POST screen)
5. Verify:
   - RAM shows as 32GB total
   - RAM speed shows as 5600MHz (or 5200MHz — XMP/EXPO may not be auto-enabled)
   - NVMe drive is detected

---

## Phase 2: BIOS Configuration

Before installing Proxmox, configure these BIOS settings. **IOMMU must be enabled here — software-side GRUB parameters are inert without it, and the VM will hard-freeze when a PCI passthrough device is started.**

### Enable IOMMU

Navigate to:

```
Advanced → AMD CBS → NBIO Common Options → IOMMU → Enabled
```

On BIOS version 02.22.0058 (and likely all current UM890 Pro firmware), this setting appears **greyed out and already set to Enabled** — this is the correct and expected state. The firmware locks it on. No action needed.

> **If IOMMU is not already enabled:** It should be under the path above. If you don't see AMD CBS, look for any setting labeled "IOMMU" or "AMD-Vi" under the Advanced tab.

**SVM Mode (AMD hardware virtualization):** Not separately configurable on this BIOS. It is enabled by default alongside IOMMU and does not appear under CPU Configuration. If IOMMU is enabled and Proxmox boots, SVM is active.

### Required Settings

| Setting | Value | Notes |
|---|---|---|
| AMD-Vi / IOMMU | **Enabled** | Greyed out on 02.22.0058 — locked to enabled, correct |
| Secure Boot | **Disabled** | Proxmox installer may conflict |

> **Fast Boot** and **Above 4G Decoding** are not exposed in the UM890 Pro BIOS UI. Both are enabled at the firmware level by default — no action needed.

### UMA Frame Buffer Size (iGPU VRAM)

The 780M uses system RAM as VRAM. The BIOS controls how much is reserved:

```
Advanced → AMD CBS → NBIO Common Options → UMA Frame Buffer Size
```

The right value depends on what you want to run on GPU and how much RAM your VMs need. With 32GB system RAM, the constraint is:

**UMA + Ollama VM RAM + Proxmox overhead (~2-3GB) ≤ 32GB**

| UMA | Remaining RAM | Ollama VM max | GPU fits |
|---|---|---|---|
| 8G | 24GB | 14GB | qwen3:8b (5.2GB) |
| 16G | 16GB | ~12GB | qwen3:14b (9.3GB) |

> **The freeze:** Setting 16G UMA with the Ollama VM at 14GB leaves only ~16GB for system — tight enough that VM startup triggers memory pressure and hard-freezes the host. The fix is to reduce the VM's RAM allocation to match: 16G UMA → set VM RAM to 10-12GB.

> **Phase 2:** The RTX 3090 has 24GB GDDR6X — UMA size becomes irrelevant once you rebuild the VM with NVIDIA drivers.

### Recommended Settings

| Setting | Value | Why |
|---|---|---|
| UMA Frame Buffer Size | **16G** (VM at 12GB) or **8G** (VM at 14GB) | See table above — must balance with VM RAM |
| Fan curve | Silent/Balanced | 24/7 home environment |
| Wake on LAN | Enabled | Useful for remote homelab management |
| Auto Power On | Enabled | Restores power after outage |

Save and exit BIOS (`F10`).

---

## Phase 3: eGPU Assembly (when ready)

> Skip this phase initially. Complete [Proxmox](02-proxmox-installation.md) through [Ollama](04-ollama-open-webui.md) setup first, then return here.

### What You'll Need (Phase 2)

- Minisforum DEG1 GPU Docking Station
- Corsair RM850x 850W ATX PSU
- NVIDIA RTX 3090 24GB (used)
- OCuLink cable (confirm included with DEG1 — if not, purchase separately)
- ATX 24-pin, PCIe 8-pin/16-pin power cables (included with RM850x)

### 3.1 Assemble the DEG1

1. Open the DEG1 enclosure
2. Install the ATX PSU into the DEG1 chassis
   - Route 24-pin ATX power to the DEG1 motherboard connector
   - The DEG1 uses the PSU to power both the enclosure and the GPU
3. Install the RTX 3090 into the PCIe x16 slot
4. Connect PCIe power cables from PSU to GPU
   - RTX 3090 requires 2× or 3× 8-pin connectors depending on the card (most AIB cards use 3× 8-pin; Founders Edition uses 2× via 12-pin adapter) — the RM850x includes enough cables for either
   - 850W is sufficient: RTX 3090 TDP is ~350W + ~65W system = ~415W peak

> **Verify clearance:** The RTX 3090 is a large triple-fan card. Confirm it fits within the DEG1 chassis before fully assembling. Check minisforum.com for DEG1 internal dimensions if uncertain.

### 3.2 Connect OCuLink

1. Power off the UM890 Pro completely
2. Connect the OCuLink cable from the DEG1 to the OCuLink port on the UM890 Pro
3. OCuLink is keyed — it only inserts one way
4. Power on the DEG1 enclosure first, then the UM890 Pro

> **Boot order matters:** Always power the DEG1 before the mini PC so Proxmox detects the GPU during POST. Hot-plug is unreliable on Linux — treat the OCuLink connection as permanent.

### 3.3 Verify GPU Detection

After boot, in Proxmox shell:

```bash
lspci | grep -E "AMD|NVIDIA"
```

Expected output should show both the AMD 780M iGPU and the NVIDIA RTX 3090 as separate PCI devices. Continue to [eGPU Setup](07-egpu-setup.md) to configure passthrough.

---

## Troubleshooting

**RAM not detected at full speed:**
Enter BIOS → find XMP/EXPO profile → enable it. DDR5-5600 kits often default to JEDEC 4800MHz without XMP enabled.

**NVMe not detected:**
Re-seat the drive. Confirm it is fully pressed into the connector before screwing down.

**No POST with eGPU attached:**
Disconnect OCuLink, boot without eGPU, confirm BIOS settings (Above 4G Decoding, IOMMU), then reconnect.

---

[← Overview](README.md) | [Next: Proxmox Installation →](02-proxmox-installation.md)
