---
---
# 13 — Devices & Home Assistant Compatibility

[← Image Generation](12-image-generation.md) | [Satellites →](14-voice-satellites.md)

---

{% include guide-toc.html %}

## Required Hardware Purchase

**Z-Wave USB stick (~$40)** — required for the Kwikset lock. Recommended: Zooz 800 Series USB or Aeotec Z-Stick 7 (800-series adapters with firmware ≥ 7.23.2 are the current recommended hardware for new setups).

Pass through to the HA VM via Proxmox: **HA VM → Hardware → Add → USB Device** → select by Vendor/Device ID. See [section 04](04-home-assistant-vm.md) for USB passthrough instructions.

In HA: **Settings → Add Integration → Z-Wave JS**

---

## Device Compatibility

### ✅ Works Excellently — Local Control

#### Kasa Smart Plugs + Kasa Smart Switch
- **Integration:** TP-Link Smart Home (built into HA — no HACS required)
- **Control:** Fully local after initial setup
- **Setup:** HA: **Settings → Add Integration → TP-Link Smart Home** → auto-discovers devices on your LAN
- **Capabilities:** On/off, energy monitoring (plugs), scheduling, HA automations
- **Note:** Newer Kasa devices (2023+) require TP-Link cloud credentials during first-time pairing to authenticate locally. After pairing, all communication is local. Older devices may pair without cloud credentials.

#### Kwikset Z-Wave Smart Lock
- **Integration:** Z-Wave JS (built into HA)
- **Control:** Fully local via Z-Wave USB stick
- **Setup:** Pair the lock to the Z-Wave network via HA Z-Wave JS UI; lock/unlock from HA, lock state reported in real time
- **Capabilities:** Lock/unlock, lock state, battery level, access code management
- **Requires:** Z-Wave USB stick (~$40) passed through to HA VM
- **Note:** The older Z-Wave JS UI add-on is being phased out in favor of the Z-Wave JS app. If you installed the UI add-on previously, migrate to the Z-Wave JS app — devices do not need to be re-paired. HA 2026.7+ requires zwave-js-server 3.9.0 or later; if using the HA add-on store this updates automatically.

---

### ✅ Works Well — Cloud Required

#### Ring Doorbell + Ring Outdoor Cameras
- **Integration:** Ring (official, built into HA)
- **Control:** Cloud (Ring API) — no local option exists
- **Setup:** HA: **Settings → Add Integration → Ring** → sign in with Ring account
- **Capabilities:**
  - Doorbell press → trigger any HA automation (flash lights, TTS announcement, etc.)
  - Motion detection events → HA automations
  - Camera snapshots in HA dashboard
  - Live streaming not available in HA (Ring restriction)
- **Note:** No Ring subscription required for basic doorbell events and sensor states. A Ring Protect subscription is required for the "last recording" camera entity.

---

### ✅ Works Well — Local Control (recently improved)

#### Govee Outdoor Lights
- **Integration:** Govee Light Local (official, built into HA as of HA 2024.2 — no HACS required)
- **Control:** Fully local — communicates directly with devices on your LAN
- **Setup:**
  1. In the Govee app: open your light device → **Settings → Local Control** → enable it (required once per device)
  2. In HA: **Settings → Add Integration → Govee Light Local** → devices auto-discover
- **Capabilities:** On/off, brightness, color, scenes
- **Note:** 250+ models supported. H70xx outdoor series is broadly covered. If your specific model isn't auto-discovered, check the supported model list in the HA integration docs — fallback to the Govee cloud app is available for unsupported models.

---

### ⚠️ Works — Cloud-Dependent or Requires Workaround

#### Leviton D26HD WiFi Switches
- **Integration:** Community (HACS) — no official HA integration
- **Control:** Cloud-dependent
- **Setup:** Install HACS → search "Leviton" or "Decora" → verify the repository is actively maintained (check last commit date and open issues) → configure with your Leviton account
- **Capabilities:** On/off, dimming, energy monitoring
- **Risk:** Cloud API changes can break the integration without warning; Leviton has no commitment to maintaining HA compatibility. The HACS integration landscape for Leviton shifts frequently — verify the specific repo you install is current before committing.

#### American Standard Air (Nexia) Thermostat
- **Integration:** Nexia/American Standard/Trane (official, built into HA)
- **Control:** Cloud (Nexia API) — no local option
- **Setup:** HA: **Settings → Add Integration → Nexia** → sign in with your Nexia/American Standard account
- **Capabilities:** Temperature control, mode (heat/cool/auto), fan control, current temperature reporting
- **Risk:** This platform has been renamed multiple times (Trane, Nexia, American Standard Air) — each rename has historically disrupted HA integrations. Monitor HA release notes after major HA updates.

#### Wyze Cam v3 (Garage Door) + Wyze Cam Pan V3
- **Integration:** Generic Camera (RTSP) after firmware flash
- **Control:** Local after one-time firmware modification
- **Setup:**
  1. Check `support.wyze.com` for current RTSP firmware availability for your camera model — Wyze has occasionally discontinued RTSP support for certain models
  2. If available: download RTSP firmware, flash via microSD card per Wyze instructions (~15 minutes, reversible)
  3. Enable RTSP in the Wyze app under camera settings
  4. In HA: **Settings → Add Integration → Generic Camera** → enter RTSP URL:
     ```
     rtsp://<username>:<password>@<camera-ip>/live
     ```
- **Capabilities:** Live stream in HA dashboard, motion snapshots
- **Note:** Wyze removed their official HA integration. RTSP firmware is the most stable path but Wyze does not guarantee its continued availability — verify before depending on it. If RTSP firmware is unavailable for your model, consider replacing with a Reolink or Amcrest camera that has native RTSP. Consider adding **Frigate NVR** (see below) for local AI object detection.

#### Kasa Camera
- **Integration:** Not supported in HA — Kasa-branded cameras have no official or community integration
- **Note:** The TP-Link Smart Home integration supports **Tapo-branded cameras only** (C100, C120, C210, C220, C225, C325WB, C520WS, C720, TC65, TC70). If you have a Tapo camera, use **Settings → Add Integration → TP-Link Smart Home** and enable "Third-Party Compatibility" in the Tapo app under Device Settings first.
- **Recommendation:** For a Kasa camera specifically: use the Kasa app independently, or replace with a Tapo or Reolink camera for proper HA integration.

---

## Optional: Frigate NVR (Local AI Camera Detection)

If you flash Wyze cameras to RTSP, adding **Frigate** gives you local AI person/vehicle/animal detection without any cloud service. Runs as a Docker container in the Docker LXC.

Frigate uses the 780M iGPU for object detection inference — add to `docker-compose.yml`:

```yaml
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: always
    privileged: true
    shm_size: "128mb"
    ports:
      - "8971:8971"   # authenticated web UI (use this for browser access and NPM)
      - "5000:5000"   # internal API (Docker-network only — do not expose externally)
      - "8554:8554"   # RTSP streams
    volumes:
      - ./frigate/config.yml:/config/config.yml
      - /media/frigate:/media/frigate
    devices:
      - /dev/dri/renderD128  # 780M iGPU for detection
```

Access the Frigate UI at `http://<docker-lxc-ip>:8971` (authenticated). Port 5000 is for internal API calls within the same Docker network only — do not use it for browser access or reverse proxy configuration.

**Frigate HA integration** is installed via HACS (not HA core). After installing the HACS integration and restarting HA, go to **Settings → Devices & Services → Add Integration → Frigate** and enter `http://<docker-lxc-ip>:8971`. Frigate also requires the **MQTT integration** to be installed and configured first.

Frigate integrates with HA natively — motion events, object detection alerts, and camera streams all appear in HA automatically.

---

## Summary Table

| Device | Integration | Local? | Effort | Reliability |
|---|---|---|---|---|
| Kasa Plugs | TP-Link Smart Home (official) | ✅ | None | ⭐⭐⭐⭐⭐ |
| Kasa Switch | TP-Link Smart Home (official) | ✅ | None | ⭐⭐⭐⭐⭐ |
| Kwikset Z-Wave Lock | Z-Wave JS (official) | ✅ | Z-Wave stick | ⭐⭐⭐⭐⭐ |
| Ring Doorbell | Ring (official) | ☁️ | None | ⭐⭐⭐⭐ |
| Ring Cameras | Ring (official) | ☁️ | None | ⭐⭐⭐⭐ |
| Govee Outdoor Lights | Govee Light Local (official) | ✅ | Enable in app | ⭐⭐⭐⭐ |
| Leviton D26HD | HACS community | ☁️ | HACS install | ⭐⭐⭐ |
| Nexia Thermostat | Nexia/American Standard/Trane (official) | ☁️ | None | ⭐⭐⭐ |
| Wyze Cam v3 | RTSP (after flash, if available) | ✅ | Firmware flash | ⭐⭐⭐ |
| Wyze Cam Pan V3 | RTSP (after flash, if available) | ✅ | Firmware flash | ⭐⭐⭐ |
| Kasa Camera | None | ❌ | — | ⭐ |

---

[← Image Generation](12-image-generation.md) | [Satellites →](14-voice-satellites.md)
