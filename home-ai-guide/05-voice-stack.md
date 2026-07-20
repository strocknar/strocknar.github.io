# 05 — Home Assistant Voice Stack

[← Ollama + Open WebUI](04-ollama-open-webui.md) | [Next: Docker & Homelab →](06-docker-homelab.md)

---

## Architecture

The voice pipeline runs entirely locally — no cloud services:

```
Microphone → Wake Word (OpenWakeWord)
           → STT: Whisper (local)
           → Intent: Ollama (local LLM)
           → TTS: Piper (local)
           → Speaker
```

All components run as HA add-ons within the HA OS VM. A Wyoming satellite handles audio capture on any remote device (Raspberry Pi, ESP32-S3).

---

## 5.1 Install Voice Add-ons

In HA web UI: **Settings → Apps → Install App**

Install each of the following:

### Wyoming Whisper (Speech-to-Text)

1. Search for `Whisper`
2. Install **Wyoming Whisper**
3. Configuration:
   ```yaml
   language: en
   model: small-int8
   ```
   > `small-int8` is the best balance of speed and accuracy for English. On the 780M iGPU via the HA VM, it runs in ~1–3 seconds per utterance. Use `tiny-int8` if latency is too high.
4. Start the add-on and enable **Start on boot**

### Wyoming Piper (Text-to-Speech)

1. Search for `Piper`
2. Install **Wyoming Piper**
3. Configuration:
   ```yaml
   voice: en_US-amy-medium
   ```
   > Browse available voices at `rhasspy.github.io/piper-samples`. `en_US-amy-medium` is natural-sounding. `en_US-ryan-high` is higher quality but slower.
4. Start and enable Start on boot

### OpenWakeWord

1. Search for `openWakeWord`
2. Install **openWakeWord**
3. Configuration:
   ```yaml

   preloaded_models:
     - ok_nabu
     
   ```
   > `ok_nabu` is the default HA wake word. Additional custom wake words can be trained via the HA wake word training tool.
4. Start and enable Start on boot

---

## 5.2 Configure the Voice Pipeline

In HA web UI: **Settings → Voice Assistants → Add Assistant**

| Setting | Value |
|---|---|
| Name | `Local Assistant` |
| Conversation agent | `Ollama (Home Assistant)` |
| Speech-to-text | `Wyoming Whisper` |
| Text-to-speech | `Wyoming Piper` |
| Wake word | `openWakeWord - ok_nabu` |

Save.

---

## 5.3 Test with Browser Mic

The quickest test without extra hardware:

In HA web UI: **Settings → Voice Assistants → [Your assistant] → Try**

Click the microphone button and speak a command like "What time is it?" or "Turn on the living room lights."

---

## 5.4 Wyoming Satellite (Remote Microphone)

A Wyoming satellite is a small device in another room that captures audio and forwards it to HA for processing. The satellite itself does minimal work — all STT, wake word, and TTS happen on the HA server.

### Option A: Raspberry Pi 4 Satellite

```bash
# On the Pi — install Wyoming satellite
pip install wyoming-satellite

# Run with a USB microphone
wyoming-satellite \
  --name "living-room" \
  --uri tcp://0.0.0.0:10700 \
  --mic-command "arecord -r 16000 -c 1 -f S16_LE -t raw" \
  --snd-command "aplay -r 22050 -c 1 -f S16_LE -t raw"
```

In HA: **Settings → Devices & Services → Add Integration → Wyoming Protocol**
- Host: `<pi-ip>`
- Port: `10700`

### Option B: ESP32-S3-Box or M5Stack Atom Echo

These are purpose-built voice satellite devices with HA firmware. Flash with ESPHome and configure as Wyoming satellites. Significantly cheaper than a Pi (~$20–40) and designed specifically for this use case.

Search "ESPHome voice satellite" in the HA community forums for current recommended hardware and firmware configs.

---

## 5.5 Tune Wake Word Sensitivity

If you get false triggers or missed wake words:

In the openWakeWord add-on configuration:

```yaml
threshold: 0.5  # lower = more sensitive, higher = fewer false triggers
```

Start at `0.5` and adjust based on your environment. Noisy rooms may need `0.4`; quiet environments `0.6`.

---

## 5.6 Ollama as Conversation Agent

The Ollama integration (configured in [section 4.7](04-ollama-open-webui.md)) handles natural language commands that HA's built-in intent recognizer can't match.

**How it works:**
- HA first tries its built-in intent matcher ("turn on lights", "set timer", etc.)
- Unmatched queries fall through to the Ollama LLM
- Ollama responds in natural language or generates HA service calls

**Configure the Ollama conversation agent prompt** to be HA-aware:

In HA: **Settings → Voice Assistants → [Your assistant] → Conversation agent → Configure**

System prompt:
```
You are a helpful home assistant. You have access to home automation controls.
Keep responses concise — they will be spoken aloud. Avoid markdown formatting.
When controlling devices, use the provided HA tools. When answering general
questions, be brief (1-2 sentences).
```

---

## Latency Expectations

| Phase | Wake word | STT | LLM response | TTS | Total |
|---|---|---|---|---|---|
| Phase 1 (iGPU) | ~0.3s | ~2–3s | ~3–5s (7B) | ~0.5s | ~6–9s |
| Phase 2 (eGPU) | ~0.3s | ~1–2s | ~1–2s (7B) | ~0.5s | ~3–5s |

Phase 1 latency is acceptable for home automation commands. If STT latency is too high, switch Whisper model to `tiny-int8`.

---

> **Building satellite hardware?** See [14 — Voice Satellites](14-voice-satellites.md) for step-by-step setup of the HA Voice Preview Edition and Pi 3 A+ satellite builds.

[← Ollama + Open WebUI](04-ollama-open-webui.md) | [Next: Docker & Homelab →](06-docker-homelab.md)
