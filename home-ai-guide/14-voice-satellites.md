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
