#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Dependency checks ─────────────────────────────────────────────────────────

if ! command -v terraform &>/dev/null; then
  echo "Installing Terraform..."
  TF_VERSION="1.9.8"
  wget -qO /tmp/terraform.zip \
    "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
  unzip -o /tmp/terraform.zip -d /usr/local/bin/
  rm /tmp/terraform.zip
fi

if ! command -v ansible-playbook &>/dev/null; then
  echo "Installing Ansible..."
  apt-get update -qq && apt-get install -y -qq ansible
fi

if ! python3 -c "import yaml" &>/dev/null; then
  apt-get install -y -qq python3-yaml
fi

# ── Read config.yml ───────────────────────────────────────────────────────────

CFG="${SCRIPT_DIR}/config.yml"
get_cfg() { python3 -c "import yaml,sys; d=yaml.safe_load(open('${CFG}')); print($1)"; }

PROXMOX_IP=$(get_cfg "d['proxmox']['host_ip']")
PROXMOX_API_URL=$(get_cfg "d['proxmox']['api_url']")
PROXMOX_NODE=$(get_cfg "d['proxmox']['node_name']")
GATEWAY=$(get_cfg "d['network']['gateway']")
DNS_FALLBACK=$(get_cfg "d['network']['dns_fallback']")
ADGUARD_IP=$(get_cfg "d['guests']['adguard_ip']")
DOCKER_IP=$(get_cfg "d['guests']['docker_ip']")
PLEX_IP=$(get_cfg "d['guests']['plex_ip']")
HAOS_IP=$(get_cfg "d['guests']['haos_ip']")
OLLAMA_IP=$(get_cfg "d['guests']['ollama_ip']")
PHASE=$(get_cfg "d['phase']")
IGPU_PCI_ID=$(get_cfg "d['igpu_pci_ids']")
RTX_PCI_ID=$(get_cfg "d.get('rtx3090_pci_ids', '')")

# ── Prompt for secrets ────────────────────────────────────────────────────────

prompt_secret() {
  local var_name="$1" prompt_text="$2"
  read -rsp "${prompt_text}: " value
  echo
  printf -v "$var_name" '%s' "$value"
}

prompt_secret PROXMOX_API_TOKEN  "Proxmox API token (format: user@realm!tokenid=secret)"
prompt_secret ANSIBLE_SSH_PASS   "Proxmox root SSH password"
prompt_secret ADGUARD_PASSWORD   "AdGuard admin password (will be set)"
prompt_secret GRAFANA_PASSWORD   "Grafana admin password (will be set)"
prompt_secret AWS_KEY_ID         "AWS Route 53 Access Key ID"
prompt_secret AWS_SECRET_KEY     "AWS Route 53 Secret Access Key"
prompt_secret PLEX_CLAIM_TOKEN   "Plex claim token (from plex.tv/claim)"

# ── Terraform ─────────────────────────────────────────────────────────────────

export TF_VAR_proxmox_api_url="${PROXMOX_API_URL}"
export TF_VAR_proxmox_api_token="${PROXMOX_API_TOKEN}"
export TF_VAR_proxmox_node="${PROXMOX_NODE}"
export TF_VAR_gateway="${GATEWAY}"
export TF_VAR_dns_fallback="${DNS_FALLBACK}"
export TF_VAR_adguard_ip="${ADGUARD_IP}"
export TF_VAR_docker_ip="${DOCKER_IP}"
export TF_VAR_plex_ip="${PLEX_IP}"
export TF_VAR_haos_ip="${HAOS_IP}"
export TF_VAR_ollama_ip="${OLLAMA_IP}"
export TF_VAR_phase="${PHASE}"
export TF_VAR_igpu_pci_id="${IGPU_PCI_ID}"
export TF_VAR_rtx3090_pci_id="${RTX_PCI_ID}"

cd "${SCRIPT_DIR}/terraform"
terraform init -upgrade
terraform apply -auto-approve
cd "${SCRIPT_DIR}"

# ── Generate static inventory from config values ──────────────────────────────

mkdir -p "${SCRIPT_DIR}/inventory"

cat > "${SCRIPT_DIR}/inventory/hosts.ini" <<EOF
[proxmox_host]
proxmox ansible_host=${PROXMOX_IP} ansible_user=root

[lxc]
adguard ansible_host=${ADGUARD_IP} ansible_user=root
docker  ansible_host=${DOCKER_IP}  ansible_user=root
plex    ansible_host=${PLEX_IP}    ansible_user=root

[vms]
haos   ansible_host=${HAOS_IP}   ansible_user=root
ollama ansible_host=${OLLAMA_IP} ansible_user=root
EOF

# ── Ansible ───────────────────────────────────────────────────────────────────

export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook site.yml \
  -i inventory/hosts.ini \
  --extra-vars "ansible_ssh_pass=${ANSIBLE_SSH_PASS}" \
  --extra-vars "adguard_password=${ADGUARD_PASSWORD}" \
  --extra-vars "grafana_password=${GRAFANA_PASSWORD}" \
  --extra-vars "aws_key_id=${AWS_KEY_ID}" \
  --extra-vars "aws_secret_key=${AWS_SECRET_KEY}" \
  --extra-vars "plex_claim_token=${PLEX_CLAIM_TOKEN}" \
  --extra-vars "@config.yml"

echo ""
echo "Done. Access your services:"
echo "  Home Assistant: http://${HAOS_IP}:8123"
echo "  Open WebUI:     http://${OLLAMA_IP}:3000"
echo "  Portainer:      http://${DOCKER_IP}:9000"
echo "  AdGuard:        http://${ADGUARD_IP}"
echo "  NPM Admin:      http://${DOCKER_IP}:81"
