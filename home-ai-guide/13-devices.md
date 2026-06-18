# 13 — Devices & Home Assistant Compatibility

[← Overview](README.md)

---

## Required Hardware Purchase

**Z-Wave USB stick (~$40)** — required for the Kwikset lock. Recommended: Zooz 800 Series USB or Aeotec Z-Stick 7.

Pass through to the HA VM via Proxmox: **HA VM → Hardware → Add → USB Device** → select by Vendor/Device ID. See [section 03](03-home-assistant-vm.md) for USB passthrough instructions.

In HA: **Settings → Add Integration → Z-Wave JS**

---

## Device Compatibility

### ✅ Works Excellently — Local Control

#### Kasa Smart Plugs + Kasa Smart Switch
- **Integration:** TP-Link Kasa (built into HA — no HACS required)
- **Control:** Fully local, no cloud dependency
- **Setup:** HA: **Settings → Add Integration → TP-Link Kasa Smart Home** → auto-discovers devices on your LAN
- **Capabilities:** On/off, energy monitoring (plugs), scheduling, HA automations

#### Kwikset Z-Wave Smart Lock
- **Integration:** Z-Wave JS (built into HA)
- **Control:** Fully local via Z-Wave USB stick
- **Setup:** Pair the lock to the Z-Wave network via HA Z-Wave JS UI; lock/unlock from HA, lock state reported in real time
- **Capabilities:** Lock/unlock, lock state, battery level, access code management
- **Requires:** Z-Wave USB stick (~$40) passed through to HA VM

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
- **Note:** No Ring subscription required for HA integration basics

---

### ⚠️ Works — Cloud-Dependent or Requires Workaround

#### Leviton D26HD WiFi Switches
- **Integration:** Community (HACS) — no official HA integration
- **Control:** Cloud-dependent
- **Setup:** Install HACS → search Leviton integration → configure with your Leviton account
- **Capabilities:** On/off, dimming, energy monitoring
- **Risk:** Cloud API changes can break the integration without warning; Leviton has no commitment to maintaining HA compatibility

#### American Standard Air (Nexia) Thermostat
- **Integration:** Nexia (official, built into HA)
- **Control:** Cloud (Nexia API) — no local option
- **Setup:** HA: **Settings → Add Integration → Nexia** → sign in with your Nexia/American Standard account
- **Capabilities:** Temperature control, mode (heat/cool/auto), fan control, current temperature reporting
- **Risk:** This platform has been renamed multiple times (Trane, Nexia, American Standard Air) — each rename has historically disrupted HA integrations. Monitor HA release notes after major HA updates.

#### Govee Outdoor Lights
- **Integration:** Govee LAN (HACS community) or Govee cloud
- **Control:** Local LAN API on some models; cloud fallback on others
- **Setup:** Install HACS → install Govee integration → enable LAN control in the Govee app first
- **Capabilities:** On/off, brightness, color, scenes
- **Note:** Test LAN control with your specific model — not all Govee products support it. If LAN fails, the cloud integration still works but adds latency.

#### Wyze Cam v3 (Garage Door) + Wyze Cam Pan V3
- **Integration:** Generic Camera (RTSP) after firmware flash
- **Control:** Local after one-time firmware modification
- **Setup:**
  1. Download Wyze RTSP firmware from wyze.com (official — search "Wyze RTSP firmware")
  2. Flash via microSD card per Wyze instructions (~15 minutes, reversible)
  3. Enable RTSP in the Wyze app under camera settings
  4. In HA: **Settings → Add Integration → Generic Camera** → enter RTSP URL:
     ```
     rtsp://<username>:<password>@<camera-ip>/live
     ```
- **Capabilities:** Live stream in HA dashboard, motion snapshots
- **Note:** Wyze removed their official HA integration. RTSP firmware is the most stable path. Consider adding **Frigate NVR** (see below) for local AI object detection.

#### Kasa Camera
- **Integration:** Limited community support
- **Control:** Cloud-dependent; Kasa camera support significantly lags behind Kasa plugs/switches
- **Capabilities:** Basic snapshot; unreliable motion events in HA
- **Recommendation:** Use the Kasa app for this camera independently until HA support improves, or replace with a camera that has better HA support (Reolink, Amcrest) if local integration matters to you

---

## Optional: Frigate NVR (Local AI Camera Detection)

If you flash Wyze cameras to RTSP, adding **Frigate** gives you local AI person/vehicle/animal detection without any cloud service. Runs as a Docker container in the Docker LXC.

Frigate uses the 890M iGPU for object detection inference — add to `docker-compose.yml`:

```yaml
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: always
    privileged: true
    shm_size: "128mb"
    ports:
      - "5000:5000"
      - "8554:8554"
    volumes:
      - ./frigate/config.yml:/config/config.yml
      - /media/frigate:/media/frigate
    devices:
      - /dev/dri/renderD128  # 890M iGPU for detection
```

Frigate integrates with HA natively — motion events, object detection alerts, and camera streams all appear in HA automatically.

---

## Summary Table

| Device | Integration | Local? | Effort | Reliability |
|---|---|---|---|---|
| Kasa Plugs | TP-Link Kasa (official) | ✅ | None | ⭐⭐⭐⭐⭐ |
| Kasa Switch | TP-Link Kasa (official) | ✅ | None | ⭐⭐⭐⭐⭐ |
| Kwikset Z-Wave Lock | Z-Wave JS (official) | ✅ | Z-Wave stick | ⭐⭐⭐⭐⭐ |
| Ring Doorbell | Ring (official) | ☁️ | None | ⭐⭐⭐⭐ |
| Ring Cameras | Ring (official) | ☁️ | None | ⭐⭐⭐⭐ |
| Leviton D26HD | HACS community | ☁️ | HACS install | ⭐⭐⭐ |
| Nexia Thermostat | Nexia (official) | ☁️ | None | ⭐⭐⭐ |
| Govee Outdoor Lights | HACS community | ⚠️ Depends | HACS install | ⭐⭐⭐ |
| Wyze Cam v3 | RTSP (after flash) | ✅ | Firmware flash | ⭐⭐⭐⭐ |
| Wyze Cam Pan V3 | RTSP (after flash) | ✅ | Firmware flash | ⭐⭐⭐⭐ |
| Kasa Camera | Community | ☁️ | HACS install | ⭐⭐ |

---

[← Overview](README.md)
