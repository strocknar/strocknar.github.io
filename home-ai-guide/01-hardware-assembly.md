# 01 — Hardware Assembly

[← Overview](README.md) | [Next: Proxmox Installation →](02-proxmox-installation.md)

---

## What You'll Need

- Minisforum AI X1 Pro-470 (barebones unit)
- 2× Crucial 16GB DDR5-5600 SO-DIMM (sold as 32GB dual-channel kit)
- WD Black SN770 1TB M.2 2280 NVMe
- Phillips head screwdriver (small)
- Anti-static wrist strap (recommended)

---

## Phase 1: Mini PC Assembly

### 1.1 Open the Unit

The AI X1 Pro-470 bottom panel is held by 4 screws. Remove them and slide the panel off. The RAM slots and NVMe bays are immediately accessible.

### 1.2 Install RAM

> **Critical:** Install both sticks for dual-channel. Single-channel halves iGPU memory bandwidth and cuts LLM inference speed in half (~10 tok/s vs ~20 tok/s on 7B models).

1. Align the SO-DIMM notch with the slot keying
2. Insert at ~30° angle, press down until both retention clips snap closed
3. Repeat for the second slot
4. Both sticks must be seated — verify clips are fully engaged on both sides

### 1.3 Install NVMe

1. Locate the M.2 2280 slot (primary slot)
2. Insert the SN770 at ~30° angle into the M.2 connector
3. Press flat and secure with the single retention screw

> The AI X1 Pro-470 has 3 NVMe slots total. Slots 2 and 3 are empty — leave them for future model weight and media storage drives.

### 1.4 Reassemble

Replace the bottom panel and screws. Do not overtighten.

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

Before installing Proxmox, configure these BIOS settings:

### Required Settings

| Setting | Value | Why |
|---|---|---|
| AMD-Vi / IOMMU | **Enabled** | Required for GPU passthrough in Proxmox |
| Secure Boot | **Disabled** | Proxmox installer may conflict |
| Fast Boot | **Disabled** | Ensures clean POST every boot |
| Above 4G Decoding | **Enabled** | Required for GPU passthrough |

### Recommended Settings

| Setting | Value | Why |
|---|---|---|
| Fan curve | Silent/Balanced | 24/7 home environment |
| Wake on LAN | Enabled | Useful for remote homelab management |
| Auto Power On | Enabled | Restores power after outage |

Save and exit BIOS.

---

## Phase 3: eGPU Assembly (when ready)

> Skip this phase initially. Complete [Proxmox](02-proxmox-installation.md) through [Ollama](04-ollama-open-webui.md) setup first, then return here.

### What You'll Need (Phase 2)

- Minisforum DEG1 GPU Docking Station
- Corsair RM850x 850W ATX PSU
- Radeon RX 7900 XTX
- OCuLink cable (confirm included with DEG1 — if not, purchase separately)
- ATX 24-pin, PCIe 8-pin/16-pin power cables (included with RM850x)

### 3.1 Assemble the DEG1

1. Open the DEG1 enclosure
2. Install the ATX PSU into the DEG1 chassis
   - Route 24-pin ATX power to the DEG1 motherboard connector
   - The DEG1 uses the PSU to power both the enclosure and the GPU
3. Install the RX 7900 XTX into the PCIe x16 slot
4. Connect PCIe power cables from PSU to GPU
   - RX 7900 XTX requires 2× 8-pin or 1× 16-pin (PCIe 5.0 connector) — use what the RM850x provides
   - 850W is sufficient: XTX TDP is ~355W + ~65W system = ~420W peak

> **Verify clearance:** The RX 7900 XTX is a triple-fan card. Confirm it fits within the DEG1 chassis before fully assembling. Check minisforum.com for DEG1 internal dimensions if uncertain.

### 3.2 Connect OCuLink

1. Power off the AI X1 Pro-470 completely
2. Connect the OCuLink cable from the DEG1 to the OCuLink port on the AI X1 Pro-470
3. OCuLink is keyed — it only inserts one way
4. Power on the DEG1 enclosure first, then the AI X1 Pro-470

> **Boot order matters:** Always power the DEG1 before the mini PC so Proxmox detects the GPU during POST. Hot-plug is unreliable on Linux — treat the OCuLink connection as permanent.

### 3.3 Verify GPU Detection

After boot, in Proxmox shell:

```bash
lspci | grep -i amd
```

Expected output should show both the 890M iGPU and the RX 7900 XTX as separate PCI devices. Continue to [eGPU Setup](07-egpu-setup.md) to configure passthrough.

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
