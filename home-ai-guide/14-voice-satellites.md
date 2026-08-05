---
---
# 14 — Voice Satellites

[← Devices & HA Compatibility](13-devices.md) | [Next: Local Coding Assistant →](15-coding-assistant.md)

---

{% include guide-toc.html %}

This section covers building satellite voice devices to replace Amazon Echo units. Satellites connect to the voice pipeline you configured in [section 06](06-voice-stack.md) — all STT, TTS, and wake word detection continue to run on the HA server. The satellite is a dumb audio pipe.

Two device types are covered. Build one of each as a prototype before committing to room assignments:

- **Option A — HA Voice Preview Edition:** Purpose-built satellite, ~10 minutes to set up, hardware echo cancellation. Best for living areas near TVs. Requires Alpha firmware to participate in Music Assistant playback.
- **Option B — Pi 3 A+ + ReSpeaker + Pebble V3:** DIY satellite with a real speaker and multi-room music capability via Sendspin. Best for bedrooms.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Home AI Server                      │
│  ┌─────────────────┐    ┌──────────────────────┐    │
│  │  HA OS VM        │    │  Docker LXC           │    │
│  │  - OpenWakeWord  │    │  - Music Assistant    │    │
│  │  - Whisper STT   │    │    (YouTube Music +   │    │
│  │  - Piper TTS     │    │     Plex fallback)    │    │
│  │  - Ollama agent  │    │  - Sendspin server    │    │
│  └─────────────────┘    │    (built into MA)    │    │
│                          └──────────────────────┘    │
└─────────────────────────────────────────────────────┘
         ▲ Wyoming Protocol (TCP)    ▲ Sendspin (WS :8927)
         │                           │
┌────────┴───────┐        ┌──────────┴──────────┐
│ HA Voice PE    │        │  Pi 3 A+ Satellite   │
│                │        │                       │
│ - Wyoming sat  │        │  - wyoming-satellite  │
│   (built-in)   │        │  - sendspin-cli       │
│ - Hardware AEC │        │  - ReSpeaker HAT      │
│   (XMOS XU316) │        │  - Pebble V3 speaker  │
│ - Sendspin     │        │                       │
│   (Alpha fw)   │        │                       │
└────────────────┘        └───────────────────────┘
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

### Enable music playback on the Voice PE

By default the Voice PE only handles voice. To make it a Music Assistant player, it requires the Sendspin Alpha firmware — a separate ESPHome build that adds the Sendspin client alongside the existing Wyoming satellite firmware.

> Do this **after** section 14.3 is complete. The Voice PE needs MA's Sendspin server running before it can connect.

1. On a browser, navigate to the Voice PE Alpha firmware installer:
   `https://esphome.github.io/home-assistant-voice-pe-alpha/`

2. Connect the Voice PE via USB-C to your computer.

3. Follow the on-screen flash instructions. The installer runs in-browser via Web Serial — Chrome or Edge required.

4. Once flashed, the Voice PE reboots and reconnects to Wi-Fi. In MA web UI → **Players**, it appears within ~60 seconds as a Sendspin player.

5. In HA, the same device now exposes both a Wyoming satellite (for voice) and a `media_player` entity (for music). They are independent — muting the mic does not stop music.

> The Alpha firmware is a technical preview. If you run into issues, the stable Wyoming-only firmware can be re-flashed from the standard HA Voice PE installer at `https://esphome.github.io/home-assistant-voice-pe/`.

---

## 14.3 Server-Side Setup (Docker LXC — one-time)

Complete this before setting up the Pi satellite or flashing the Voice PE.

### Add Music Assistant to Docker Compose

In the Docker LXC shell:

```bash
vim /opt/homelab/docker-compose.yml
```

Add inside the `services:` block:

```yaml
  music-assistant:
    image: ghcr.io/music-assistant/server:latest
    container_name: music-assistant
    restart: always
    network_mode: host
    volumes:
      - /opt/homelab/music-assistant:/data
    privileged: true
```

> `network_mode: host` is required. MA uses mDNS to discover players (AirPlay, Sendspin) and bridge networking breaks mDNS across the LAN.

Create the data directory and start the container:

```bash
mkdir -p /opt/homelab/music-assistant
cd /opt/homelab
docker compose up -d music-assistant
```

Verify it is running:

```bash
docker ps | grep music-assistant
```

Expected: container shows `Up`.

### Configure Music Assistant

Access the MA web UI at `http://<docker-lxc-ip>:8095`

On first launch, MA runs a setup wizard:

1. **Add YouTube Music provider:**
   - **Settings → Music Providers → Add → YouTube Music**
   - MA uses `ytmusicapi` for authentication. Follow the on-screen OAuth flow.
   - Once authenticated, MA indexes your YouTube Music library.

2. **Add Plex provider:**
   - **Settings → Music Providers → Add → Plex**
   - Enter your Plex server URL: `http://<plex-lxc-ip>:32400`
   - Authenticate with your Plex account token.

   > This is your fallback provider. When YouTube Music is unavailable, MA uses Plex automatically.

3. **Enable Sendspin player provider:**
   - **Settings → Player Providers → Add → Sendspin**
   - No additional configuration required. MA starts the Sendspin server on port `8927` and auto-discovers any Sendspin clients on the LAN via mDNS.

   > Sendspin is MA's native multi-room protocol. It is in technical preview — the protocol may change in future MA versions, but it is functional and actively maintained.

### Add Music Assistant to Home Assistant

In HA web UI: **Settings → Devices & Services → Add Integration → Music Assistant**

- MA Server URL: `http://<docker-lxc-ip>:8095`

HA now exposes each MA player as a `media_player` entity, enabling voice commands like "computer, play children's music in the bedroom."

---

## 14.4 Option B — Pi 3 A+ Satellite

### Hardware

| Component | Price | Notes |
|---|---|---|
| Raspberry Pi 3 A+ | ~$25 | No per-unit purchase limits |
| ReSpeaker 2-Mics Pi HAT | $13.99 | Seeed Studio |
| Creative Pebble V3 | ~$38 | Amazon |
| 32GB microSD (Class 10) | ~$8 | |
| USB-C 5V/3A charger | ~$10 | |

**Audio routing:**

```
ReSpeaker HAT (GPIO) ──── Pi 3 A+
ReSpeaker HAT 3.5mm ──── Pebble V3 aux-in   ← audio (WM8960 codec)
Pi USB-A             ──── Pebble V3 USB-C    ← power only
Wall outlet          ──── USB-C charger ──── Pi USB-C
```

> Use the ReSpeaker HAT's 3.5mm output, not the Pi's built-in audio jack. The Pi's jack is PWM-based and produces audible noise. The ReSpeaker's WM8960 codec is significantly cleaner.

### 14.4.1 Flash the OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

2. Select **Raspberry Pi OS Lite (64-bit)** — no desktop required

3. Before writing, click the **gear icon** to preconfigure:
   - Hostname: `satellite-bedroom-1` (or your preferred name)
   - Enable SSH: yes, use password authentication
   - Configure WiFi: your SSID and password
   - Set username/password: `pi` / your chosen password

4. Write to the microSD card, insert into the Pi, power on

5. SSH in:

```bash
ssh pi@satellite-bedroom-1.local
```

### 14.4.2 Install ReSpeaker HAT Driver

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git

git clone https://github.com/HinTak/seeed-voicecard
cd seeed-voicecard
sudo ./install.sh
sudo reboot
```

> Use the `HinTak/seeed-voicecard` fork — it is actively maintained for current Raspberry Pi OS kernels. The original `respeaker/seeed-voicecard` repo is no longer updated and will fail on recent kernels.

After reboot, verify the driver loaded:

```bash
aplay -l
```

Expected output includes:
```
card 1: seeed2micvoicec [seeed-2mic-voicecard], device 0: ...
```

Test microphone capture:

```bash
arecord -D plughw:1,0 -r 16000 -c 1 -f S16_LE -d 5 test.wav
aplay test.wav
```

You should hear your own voice played back. If the playback is silent, check that the HAT is fully seated on the GPIO header.

### 14.4.3 Install wyoming-satellite

```bash
sudo apt install -y python3-pip python3-venv
python3 -m venv /home/pi/wyoming-satellite
/home/pi/wyoming-satellite/bin/pip install wyoming-satellite
```

Create the systemd service:

```bash
sudo vim /etc/systemd/system/wyoming-satellite.service
```

```ini
[Unit]
Description=Wyoming Satellite
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/home/pi/wyoming-satellite/bin/wyoming-satellite \
  --name "bedroom-satellite" \
  --uri tcp://0.0.0.0:10700 \
  --mic-command "arecord -D plughw:1,0 -r 16000 -c 1 -f S16_LE -t raw" \
  --snd-command "aplay -D plughw:1,0 -r 22050 -c 1 -f S16_LE -t raw"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

> Change `--name` to match the room (e.g., `bedroom-1-satellite`). This name appears in HA when you add the device.

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable wyoming-satellite
sudo systemctl start wyoming-satellite
sudo systemctl status wyoming-satellite
```

Expected: `Active: active (running)`

### 14.4.4 Add to Home Assistant

In HA web UI: **Settings → Devices & Services → Add Integration → Wyoming Protocol**

| Setting | Value |
|---|---|
| Host | `<pi-ip-address>` |
| Port | `10700` |

After adding, go to **Settings → Voice Assistants → Local Assistant** and assign the new satellite to the **Local Assistant** pipeline.

Test: say **"computer, what time is it?"**

The Pi's ReSpeaker LED ring lights up on wake word detection, and you hear Piper's TTS response through the Pebble V3.

### 14.4.5 Install Sendspin Client

The Sendspin CLI provides an automated systemd installer that handles audio device selection and service registration interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/Sendspin/sendspin-cli/refs/heads/main/scripts/systemd/install-systemd.sh | sudo bash
```

The script will prompt you to:
- Name the player (e.g., `bedroom-satellite`) — this is the name that appears in MA
- Select an audio output device — choose the ReSpeaker HAT (`plughw:1,0`)

After the script completes, verify the service is running:

```bash
sudo systemctl status sendspin
```

Expected: `Active: active (running)`

The client announces itself via mDNS. Within ~30 seconds, it appears as a player in MA without any manual pairing.

> Settings persist in `~/.config/sendspin/settings-daemon.json`. To rename the player or change the audio device later, edit that file and restart the service: `sudo systemctl restart sendspin`.

### 14.4.6 Verify Music Assistant Player

In Music Assistant web UI (`http://<docker-lxc-ip>:8095`):

Go to **Players**. Within ~30 seconds of starting the Sendspin client, a new player appears named `bedroom-satellite` (the name you chose during the installer).

In HA: **Developer Tools → States** — search for `media_player`. A new entity for the bedroom satellite appears.

### 14.4.7 Test Music Playback

1. In Music Assistant, browse to any YouTube Music track
2. Click the player selector → choose `bedroom-satellite`
3. Play — audio should come through the Pebble V3

Test voice-triggered playback:

Say: **"computer, play children's music"**

HA passes the request to Music Assistant via the Ollama conversation agent, MA starts playback on the active player entity.

### Multi-room Grouping

To play synchronized audio across multiple Pi satellites:

In Music Assistant: click the **Group** icon on any player → select which bedroom players to include → play music.

All grouped Sendspin players receive the same stream and play in sync. Sendspin uses sample-accurate synchronization — latency between grouped players is typically under 30ms.

In HA voice: **"computer, play lullabies everywhere"** — MA groups all bedroom players and starts playback.

> Grouping via voice requires the Ollama conversation agent to understand and map "everywhere" or room names to MA player entities. This works out of the box when player entities in HA have clear location-based names (e.g., `media_player.bedroom_1_satellite`). Name your satellites clearly when adding them.

---

## 14.5 Latency Reference

Voice pipeline latency is the same for both satellite types — all processing happens on the server.

| Phase | Wake word | STT | LLM | TTS | Total |
|---|---|---|---|---|---|
| Phase 1 (iGPU) | ~0.3s | ~2–3s | ~3–5s | ~0.5s | ~6–9s |
| Phase 2 (eGPU) | ~0.3s | ~1–2s | ~1–2s | ~0.5s | ~3–5s |

Music playback start time (voice command to first audio): ~2–3 seconds on a stable LAN.

---

## 14.6 Fallback Behavior

| Scenario | Result |
|---|---|
| Internet down | Voice + local device control work normally. YouTube Music fails; Plex plays from local library. |
| YouTube Music unavailable | Music Assistant automatically falls back to Plex provider. |
| HA server unreachable | Satellites go silent — no local processing on the satellite itself. |
| Sendspin server down (MA container down) | Voice still works. Music requests fail with a spoken error from Piper. |

---

## 14.7 Troubleshooting

**Wake word not triggering**

- Verify OpenWakeWord add-on is running and `computer.tflite` is present in `/config/openWakeWord/`
- Check OpenWakeWord add-on log for model loading errors
- Lower threshold: `threshold: 0.4` in the add-on config, restart

**Pi satellite not appearing in HA**

- Confirm wyoming-satellite is running: `systemctl status wyoming-satellite`
- Confirm port 10700 is reachable from the HA server: `nc -zv <pi-ip> 10700`
- Check that HA and the Pi are on the same subnet (or that mDNS/TCP can route between them)

**ReSpeaker mic not detected**

- Confirm driver installed: `aplay -l` should show `seeed-2mic-voicecard`
- If missing: re-run `sudo ./install.sh` from the `seeed-voicecard` directory and reboot
- Confirm you used the `HinTak/seeed-voicecard` fork, not the original Seeed repo

**No audio output from Pebble V3**

- Confirm Pebble V3 aux-in cable is connected to the ReSpeaker HAT's 3.5mm jack (not the Pi's)
- Test: `aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Center.wav`
- Adjust HAT output volume: `alsamixer` → select ReSpeaker card → raise PCM/Speaker level

**Sendspin client not connecting**

- Verify the sendspin service is running on the Pi: `sudo systemctl status sendspin`
- Verify MA's Sendspin provider is enabled: MA web UI → **Settings → Player Providers → Sendspin**
- Confirm port `8927` is reachable from the Pi: `nc -zv <docker-lxc-ip> 8927`
- Check logs: `journalctl -u sendspin -f`

**Music Assistant player not appearing**

- Confirm the sendspin service is active: `sudo systemctl status sendspin`
- mDNS discovery requires the Pi and MA to be on the same subnet. If on different VLANs, mDNS packets will not cross — move both to the same VLAN or configure mDNS reflection on your router.
- Restart MA container: `docker restart music-assistant`

**Voice PE not appearing as MA player**

- Confirm the Alpha firmware is flashed (standard firmware does not include Sendspin)
- Confirm MA's Sendspin provider is enabled and MA is running
- Check the Voice PE's ESPHome logs in HA: **Settings → Devices & Services → [Voice PE] → Logs**

---

[← Devices & HA Compatibility](13-devices.md) | [Next: Local Coding Assistant →](15-coding-assistant.md)
