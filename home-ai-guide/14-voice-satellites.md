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

## 14.3 Server-Side Setup (Docker LXC — one-time)

Complete this before setting up the Pi satellite. The Pi's `snapclient` needs a running Snapcast server to connect to.

### Add Music Assistant and Snapcast to Docker Compose

In the Docker LXC shell:

```bash
nano /opt/homelab/docker-compose.yml
```

Add the following services inside the `services:` block (alongside your existing Portainer, Grafana, etc.):

```yaml
  music-assistant:
    image: ghcr.io/music-assistant/server:latest
    container_name: music-assistant
    restart: always
    network_mode: host
    volumes:
      - /opt/homelab/music-assistant:/data
    privileged: true

  snapcast-server:
    image: ghcr.io/badaix/snapcast:latest
    container_name: snapcast-server
    restart: always
    network_mode: host
    volumes:
      - /opt/homelab/snapcast:/etc/snapcast
      - /tmp/snapcast:/tmp/snapcast
```

> Both services use `network_mode: host` so that mDNS discovery and Snapcast's multicast stream work correctly across your LAN. Do not use bridge networking for these.

Also add the volumes at the top-level `volumes:` block:

```yaml
volumes:
  # ... existing volumes ...
  music_assistant_data:
  snapcast_data:
```

> The volume declarations are only needed if you switch away from bind mounts later. The bind mounts in the service definitions above (`/opt/homelab/music-assistant` and `/opt/homelab/snapcast`) are sufficient for now.

Create the data directories:

```bash
mkdir -p /opt/homelab/music-assistant
mkdir -p /opt/homelab/snapcast
mkdir -p /tmp/snapcast
```

Start the new containers:

```bash
cd /opt/homelab
docker compose up -d music-assistant snapcast-server
```

Verify both are running:

```bash
docker ps | grep -E "music-assistant|snapcast"
```

Expected: both containers show `Up`.

### Configure Snapcast Server

Create the Snapcast server config:

```bash
nano /opt/homelab/snapcast/snapserver.conf
```

```ini
[server]
threads = -1

[stream]
source = pipe:///tmp/snapcast/snapcast.fifo?name=MusicAssistant&sampleformat=48000:16:2&codec=flac

[http]
enabled = true
port = 1780
```

Restart Snapcast to pick up the config:

```bash
docker restart snapcast-server
```

Create the named pipe that Music Assistant writes audio to:

```bash
mkfifo /tmp/snapcast/snapcast.fifo
```

> This FIFO is recreated at boot — add `mkfifo /tmp/snapcast/snapcast.fifo` to `/etc/rc.local` or a systemd service to ensure it exists after reboots.

### Configure Music Assistant

Access the MA web UI at `http://<docker-lxc-ip>:8095`

On first launch, MA runs a setup wizard:

1. **Add YouTube Music provider:**
   - **Settings → Music Providers → Add → YouTube Music**
   - MA uses `ytmusicapi` for authentication. Follow the on-screen OAuth flow — it opens a Google login page.
   - Once authenticated, MA indexes your YouTube Music library.

2. **Add Plex provider:**
   - **Settings → Music Providers → Add → Plex**
   - Enter your Plex server URL: `http://<plex-lxc-ip>:32400`
   - Authenticate with your Plex account token.

   > This is your fallback provider. When YouTube Music is unavailable (internet down), MA automatically uses Plex.

3. **Add Snapcast output player:**
   - **Settings → Player Providers → Add → Snapcast**
   - Host: `localhost` (MA and Snapcast are on the same host)
   - Port: `1780`
   - MA discovers the `MusicAssistant` stream and creates a player entity for each connected snapclient.

### Add Music Assistant to Home Assistant

In HA web UI: **Settings → Devices & Services → Add Integration → Music Assistant**

- MA Server URL: `http://<docker-lxc-ip>:8095`

HA now exposes each MA player as a media player entity, enabling voice commands like "computer, play children's music in the bedroom."

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
sudo nano /etc/systemd/system/wyoming-satellite.service
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

### 14.4.5 Install Snapcast Client

```bash
sudo apt install -y snapclient
```

Configure it to point at the Snapcast server:

```bash
sudo nano /etc/default/snapclient
```

```bash
SNAPCLIENT_OPTS="--host <docker-lxc-ip> --port 1704 --soundcard plughw:1,0"
```

> Replace `<docker-lxc-ip>` with the IP address of your Docker LXC. Port `1704` is the Snapcast default binary protocol port.

Enable and start:

```bash
sudo systemctl enable snapclient
sudo systemctl start snapclient
sudo systemctl status snapclient
```

Expected: `Active: active (running)`

### 14.4.6 Verify Music Assistant Player

In Music Assistant web UI (`http://<docker-lxc-ip>:8095`):

Go to **Players**. Within ~30 seconds of starting snapclient, a new player appears named `bedroom-satellite` (matching your snapclient hostname).

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

All grouped players receive the same Snapcast stream and play in sync within ~30ms.

In HA voice: **"computer, play lullabies everywhere"** — MA groups all bedroom players and starts playback.

> Grouping via voice requires the Ollama conversation agent to understand and map "everywhere" or room names to MA player entities. This works out of the box when player entities in HA have clear location-based names (e.g., `media_player.bedroom_1_satellite`). Name your satellites clearly when adding them.

---
