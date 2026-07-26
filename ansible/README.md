# Proxmox Homelab Automation

Terraform + Ansible automation for the [home-ai-guide](../home-ai-guide/) stack.
Run from the Proxmox web UI shell with a single command.

## Prerequisites (manual — do these before running run.sh)

### 1. Proxmox is installed and reachable

- Proxmox VE 8.x installed and accessible at your configured IP
- You have root SSH access from the Proxmox shell to itself (loopback SSH)

### 2. Create Proxmox API token for Terraform

In the Proxmox web UI shell:

```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Administrator
pveum user token add terraform@pve terraform --privsep=0
```

Copy the token output. You will be prompted for it when running `run.sh`.

Format: `terraform@pve!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 3. Download Debian 13 LXC template

In the Proxmox web UI: **node → local → CT Templates → Templates** → search `debian` → select **Debian 13** → **Download**.

Or in the shell:
```bash
pveam update
pveam download local debian-13-standard_13.0-1_amd64.tar.zst
```

### 4. Download Ubuntu 24.04 cloud image (for Ollama VM)

```bash
wget -O /var/lib/vz/template/iso/ubuntu-24.04-minimal-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
```

Update `ansible/terraform/vm_ollama.tf` — set `default` in `variable "ubuntu_cloud_image"` to match the actual path Proxmox assigned.

### 5. Download HAOS image

```bash
HA_VERSION="14.2"
wget -O /var/lib/vz/template/iso/haos_ova-${HA_VERSION}.qcow2.xz \
  "https://github.com/home-assistant/operating-system/releases/download/${HA_VERSION}/haos_ova-${HA_VERSION}.qcow2.xz"
xz -d /var/lib/vz/template/iso/haos_ova-${HA_VERSION}.qcow2.xz
```

Update `ansible/terraform/vm_haos.tf` — set the `file_id` and `import_from` fields to match the path above.

### 6. Enable SSH on Proxmox host (loopback)

Ansible connects to the Proxmox host via SSH. Verify loopback SSH works:
```bash
ssh root@localhost echo ok
```

If it prompts for a host key, accept it. Ansible will skip host key checking.

### 7. Fill in config.yml

Edit `ansible/config.yml` with your actual IPs, domain, and phase:

```yaml
proxmox:
  host_ip: 192.168.1.10           # Your Proxmox host IP
  node_name: proxmox              # Proxmox node name
  api_url: https://192.168.1.10:8006/api2/json

network:
  gateway: 192.168.1.1            # Your network gateway
  dns_fallback: 1.1.1.1           # Fallback DNS server
  subnet_mask: "24"

guests:
  adguard_ip: 192.168.1.20        # AdGuard Home (CT 202)
  docker_ip: 192.168.1.21         # Docker + homelab stack (CT 200)
  plex_ip: 192.168.1.22           # Plex (CT 201)
  haos_ip: 192.168.1.23           # Home Assistant VM (VM 100)
  ollama_ip: 192.168.1.24         # Ollama VM (VM 101)

domain: yourdomain.com            # Your domain for DNS/ACME

phase: 1                          # Phase 1 (AMD IGPU) or Phase 2 (NVIDIA RTX 3090)
igpu_pci_ids: "1002:1900"         # AMD IGPU PCI ID (run `lspci -nn | grep VGA`)
igpu_pci_ids_vfio: "1002:1900,1002:1640"  # AMD IGPU + audio PCI IDs

# Phase 2 only: NVIDIA RTX 3090 PCI passthrough
# rtx3090_pci_ids: "10de:2204"
# rtx3090_pci_ids_vfio: "10de:2204,10de:1ad8"
```

## How to run

From the Proxmox web UI shell:

```bash
cd /path/to/repo/ansible
bash run.sh
```

The script will:

1. **Check dependencies** — Install Terraform 1.9.8, Ansible, and Python3 YAML support
2. **Install Ansible collections** — `community.docker` (required for Portainer)
3. **Prompt for secrets** — All 7 required credentials (kept in memory, never written to disk):
   - Proxmox API token
   - Proxmox root SSH password
   - AdGuard admin password (will be set)
   - Grafana admin password (will be set)
   - AWS Route 53 Access Key ID
   - AWS Route 53 Secret Access Key
   - Plex claim token (from [plex.tv/claim](https://plex.tv/claim))
4. **Run Terraform** — Provision LXC containers and VMs from `terraform/`
5. **Generate inventory** — Create dynamic `inventory/hosts.ini` from `config.yml`
6. **Run Ansible** — Execute `site.yml` playbook with all roles in order

Access your services after deployment:

```
Home Assistant: http://<haos_ip>:8123
Open WebUI:     http://<ollama_ip>:3000
Portainer:      http://<docker_ip>:9000
AdGuard:        http://<adguard_ip>
NPM Admin:      http://<docker_ip>:81
Grafana:        http://<docker_ip>:3000
Prometheus:     http://<docker_ip>:9090
Plex:           http://<plex_ip>:32400
```

## Roles and their order (from site.yml)

| Role | Host | Purpose |
|---|---|---|
| `proxmox_host` | Proxmox | Enable VFIO, kernel GRUB patches, IOMMU, cgroup2 validation |
| `adguard` | CT 202 | DNS filtering with blocklists and ACME challenge support |
| `docker_lxc` | CT 200 | Install Docker with NVIDIA/ROCm GPU support (phase-conditional) |
| `homelab_stack` | CT 200 | Deploy Portainer, NPM, Grafana, Prometheus |
| `plex` | CT 201 | Install Plex media server |
| `haos_vm` | VM 100 | Wait for Home Assistant boot, display setup URL |
| `ollama_vm` | VM 101 | Install ROCm or NVIDIA drivers (phase-conditional), Ollama, Open WebUI |

## Phase 2 Upgrade: Add NVIDIA RTX 3090 GPU passthrough

After Home Assistant and Ollama are running, to add GPU acceleration:

1. Connect RTX 3090 via eGPU dock (or internal slot)
2. Boot Proxmox and verify it detects the GPU:
   ```bash
   lspci -nn | grep -i nvidia
   ```
   Note the PCI ID (e.g., `10de:2204`)
3. Update `ansible/config.yml`:
   ```yaml
   phase: 2
   rtx3090_pci_ids: "10de:2204"           # From lspci
   rtx3090_pci_ids_vfio: "10de:2204,10de:1ad8"  # GPU + audio
   ```
4. Re-run the deployment:
   ```bash
   bash run.sh
   ```
   (You'll be re-prompted for secrets, but it's safe to re-run)

Phase 2 enables:

- **Ollama VM** — NVIDIA CUDA acceleration for LLM inference
- **Docker LXC** — NVIDIA Docker plugin for GPU-enabled containers

The `proxmox_host` role will configure VFIO isolation and rebind devices to the VFIO driver.

## Troubleshooting

### SSH loopback not working

If `ssh root@localhost echo ok` hangs or fails:

```bash
# Enable SSH on Proxmox
systemctl enable ssh
systemctl start ssh

# Test again
ssh root@localhost
# Accept the fingerprint if prompted
```

### Terraform or Ansible not found

The `run.sh` script auto-installs them. If installation fails, manually install:

```bash
# Terraform 1.9.8 (or configure TF_VERSION in run.sh)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
apt-get update && apt-get install -y terraform

# Ansible
apt-get install -y ansible

# Ansible collection: community.docker
ansible-galaxy collection install community.docker
```

### Plex claim token expired

If Plex setup fails during `plex` role, get a fresh token from [plex.tv/claim](https://plex.tv/claim) and re-run `bash run.sh`.

### GPU passthrough not working (Phase 2)

Ensure:
- IOMMU is enabled in BIOS/UEFI
- Kernel GRUB parameters include `intel_iommu=on` or `amd_iommu=on`
- `proxmox_host` role ran successfully (sets GRUB)
- PCI IDs match your GPU (run `lspci -nn` and update `config.yml`)

## Architecture

The automation deploys:

- **LXC 200** — Docker container runtime (6GB RAM, 40GB disk)
- **LXC 201** — Plex media server (2GB RAM, 20GB disk)
- **LXC 202** — AdGuard Home DNS (512MB RAM, 8GB disk)
- **VM 100** — Home Assistant OS (q35, 4GB RAM, 32GB disk, CPU: host)
- **VM 101** — Ollama (q35, 8GB RAM, 60GB disk, NVIDIA/ROCm GPU passthrough)

All network interfaces are in the same isolated bridge (`vmbr0`), routed through AdGuard for DNS resolution and filtering.

## References

- [Proxmox VE documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Proxmox provider (bpg/proxmox)](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Ansible community.docker collection](https://docs.ansible.com/ansible/latest/collections/community/docker/index.html)
- [Home Assistant OS downloads](https://www.home-assistant.io/installation/)
- [Ollama documentation](https://ollama.ai)
