# 14 — Voice Satellites

[← Devices & HA Compatibility](13-devices.md)

---

This section covers building satellite voice devices to replace Amazon Echo units. Satellites connect to the voice pipeline you configured in [section 05](05-voice-stack.md) — all STT, TTS, and wake word detection continue to run on the HA server. The satellite is a dumb audio pipe.

Two device types are covered. Build one of each as a prototype before committing to room assignments:

- **Option A — HA Voice Preview Edition:** Purpose-built satellite, ~10 minutes to set up, hardware echo cancellation. Best for living areas near TVs.
- **Option B — Pi 3 A+ + ReSpeaker + Pebble V3:** DIY satellite with a real speaker and multi-room music capability via Snapcast. Best for bedrooms.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Home AI Server                      │
│  ┌─────────────────┐    ┌──────────────────────┐    │
│  │  HA OS VM        │    │  Docker LXC           │    │
│  │  - OpenWakeWord  │    │  - Music Assistant    │    │
│  │  - Whisper STT   │    │    (YouTube Music +   │    │
│  │  - Piper TTS     │    │     Plex fallback)    │    │
│  │  - Ollama agent  │    │  - Snapcast Server    │    │
│  └─────────────────┘    └──────────────────────┘    │
└─────────────────────────────────────────────────────┘
         ▲ Wyoming Protocol (TCP)        ▲ Snapcast stream
         │                               │
┌────────┴───────┐            ┌──────────┴──────────┐
│ HA Voice PE    │            │  Pi 3 A+ Satellite   │
│                │            │                       │
│ - Wyoming sat  │            │  - wyoming-satellite  │
│   (built-in)   │            │  - snapclient         │
│ - Hardware AEC │            │  - ReSpeaker HAT      │
│   (XMOS XU316) │            │  - Pebble V3 speaker  │
└────────────────┘            └───────────────────────┘
```

---

## 14.1 Add the "computer" Wake Word

The default wake word `ok_nabu` is replaced with `computer`, using a pre-trained community model. This applies to all satellites — do this once on the server before setting up any satellite hardware.

### Download the model

In the HA OS VM shell (or SSH into the HA host):

```bash
# Create a directory for custom wake word models
mkdir -p /config/openWakeWord

# Download the community-trained "computer" model
curl -L \
  https://github.com/fwartner/home-assistant-wakewords-collection/raw/main/en/computer/computer.tflite \
  -o /config/openWakeWord/computer.tflite
```

### Update OpenWakeWord add-on configuration

In HA web UI: **Settings → Add-ons → openWakeWord → Configuration**

```yaml
preloaded_models: []
custom_model_dir: /config/openWakeWord
threshold: 0.5
```

> `custom_model_dir` tells OpenWakeWord to load all `.tflite` files from that directory. The `computer.tflite` file you downloaded will be automatically detected.

Restart the add-on: **openWakeWord → Restart**

### Update the voice pipeline

In HA web UI: **Settings → Voice Assistants → Local Assistant → Edit**

| Setting | Value |
|---|---|
| Wake word | `computer` |

Save.

> If `computer` does not appear in the wake word dropdown, wait 30 seconds after restarting OpenWakeWord and refresh the page.

---

## 14.2 Option A — HA Voice Preview Edition

### Hardware

| Component | Price | Where to buy |
|---|---|---|
| HA Voice Preview Edition | ~$59 | ameriDroid, The Pi Hut, Seeed Studio |

**Key specs:** ESP32-S3 + XMOS XU316 (hardware echo cancellation + noise suppression), dual mics, internal speaker, 3.5mm audio out, USB-C power, physical mute switch and volume dial.

> The XMOS XU316 chip performs echo cancellation in hardware before audio reaches the server. This makes the Voice PE significantly more reliable than software-based alternatives in rooms where a TV or music is playing.

### Setup

1. Plug in the Voice PE via USB-C.

2. In HA web UI: **Settings → Devices & Services**

   The device auto-discovers and appears as a Wyoming integration. Click **Configure** and accept.

3. In HA web UI: **Settings → Voice Assistants → Local Assistant**

   Under **Satellites**, find your new device and assign it to the **Local Assistant** pipeline.

4. Name the device by location: **Settings → Devices & Services → [Your Voice PE] → Edit** → set a name (e.g., `Living Room Voice`).

5. Test: say **"computer, what time is it?"**

   The LED ring should light up on wake word detection, and you should hear a spoken time response.

> If the device does not auto-discover, check that the Voice PE and the HA server are on the same VLAN. mDNS must be able to reach the HA host.

### Physical mute

The hardware mute switch on the top of the device disconnects the microphone at the hardware level — no software interaction. When muted, the LED ring shows red. The device will not respond to wake words until unmuted.

---
