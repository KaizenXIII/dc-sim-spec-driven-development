#!/usr/bin/env bash
# dc-sim Local CI/CD Pipeline
# Spec: SPEC-100, SPEC-110
#
# Simulates a full CI/CD pipeline run locally:
#   1. Generate SSH keypair (if missing)
#   2. Start 9 simulated datacenter nodes via docker compose
#   3. Wait for all SSH ports to be ready
#   4. Run the Ansible hello-world playbook against all nodes
#   5. (Optional) Tear down containers
#
# Usage:
#   bash scripts/local-pipeline.sh              # Run and keep containers up
#   bash scripts/local-pipeline.sh --cleanup    # Run and tear down after
#   bash scripts/local-pipeline.sh --down       # Just tear down

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra/docker"
ANSIBLE_DIR="$REPO_ROOT/services/ansible"
COMPOSE_FILE="$INFRA_DIR/docker-compose.sim-nodes.yml"
KEY_FILE="$INFRA_DIR/sim-dev.key"
PUB_KEY_FILE="$INFRA_DIR/sim-dev.key.pub"

# ── SSH ports to wait on ───────────────────────────────────────────────────────
SSH_PORTS=(22001 22002 22003 22004 22005 22006 22007 22008 22009)
SSH_TIMEOUT=90

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${BLUE}[dc-sim]${NC} $*"; }
ok()     { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()   { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()  { echo -e "${RED}[ FAIL ]${NC} $*"; exit 1; }
banner() { echo -e "\n${BOLD}$*${NC}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
CLEANUP=false
DOWN_ONLY=false
for arg in "$@"; do
  case $arg in
    --cleanup) CLEANUP=true ;;
    --down)    DOWN_ONLY=true ;;
  esac
done

# ── Dependency checks ─────────────────────────────────────────────────────────
check_deps() {
  banner "── Checking dependencies ─────────────────────────────────────────"
  for cmd in docker ansible-playbook ssh-keygen nc; do
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd found"
    else
      error "$cmd not found. Please install it and retry."
    fi
  done
}

# ── Tear down ─────────────────────────────────────────────────────────────────
teardown() {
  banner "── Tearing down sim nodes ────────────────────────────────────────"
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans
  ok "Containers stopped and removed."
}

if $DOWN_ONLY; then
  teardown
  exit 0
fi

# ── Step 1: SSH keypair ───────────────────────────────────────────────────────
banner "── Step 1/4: SSH keypair ─────────────────────────────────────────"
if [ -f "$KEY_FILE" ] && [ -f "$PUB_KEY_FILE" ]; then
  ok "SSH keypair already exists at $KEY_FILE"
else
  log "Generating ed25519 keypair for dc-sim dev environment..."
  ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "dc-sim-dev-$(date +%Y%m%d)" -q
  ok "Keypair generated: $KEY_FILE (private — gitignored)"
  ok "               and $PUB_KEY_FILE (public — safe to commit)"
fi

# ── Step 2: Start sim nodes ───────────────────────────────────────────────────
banner "── Step 2/4: Starting simulated datacenter nodes ────────────────"
log "Building images and starting 9 nodes (VMware + OpenStack + UCS)..."
log "This may take a few minutes on first run (building Ubuntu base image)."

docker compose -f "$COMPOSE_FILE" up -d --build 2>&1 | \
  { grep -E "^(#|\[|\s*(✔|✓|=>)|Container|Network|Error)" || true; }

ok "docker compose up complete."

# ── Step 3: Wait for SSH ──────────────────────────────────────────────────────
banner "── Step 3/4: Waiting for SSH on all 9 nodes ─────────────────────"
start_time=$(date +%s)

for port in "${SSH_PORTS[@]}"; do
  log "Waiting for SSH on port $port..."
  elapsed=0
  while ! nc -z 127.0.0.1 "$port" 2>/dev/null; do
    sleep 2
    elapsed=$(( $(date +%s) - start_time ))
    if [ "$elapsed" -gt "$SSH_TIMEOUT" ]; then
      error "Timeout waiting for SSH on port $port after ${SSH_TIMEOUT}s. Check: docker compose -f $COMPOSE_FILE logs"
    fi
  done
  ok "Port $port ready"
done

# Extra settle time for sshd to fully initialise
sleep 3
ok "All 9 SSH ports are ready."

# ── Step 4: Run Ansible hello-world ──────────────────────────────────────────
banner "── Step 4/4: Running Ansible hello-world playbook ───────────────"
log "Playbook: services/ansible/playbooks/hello-world.yml"
log "Targets:  all datacenter_nodes (VMware, OpenStack, UCS)"
echo ""

pushd "$ANSIBLE_DIR" > /dev/null
ansible-playbook playbooks/hello-world.yml \
  --private-key "$KEY_FILE" \
  --ssh-common-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
popd > /dev/null

# ── Done ──────────────────────────────────────────────────────────────────────
banner "── Pipeline complete ─────────────────────────────────────────────"
ok "9 nodes reached across VMware, OpenStack, and Cisco UCS."
echo ""
echo "  Next steps:"
echo "    Explore nodes:  ssh -i $KEY_FILE -p 22001 root@127.0.0.1"
echo "    Run a playbook: cd services/ansible && ansible-playbook playbooks/<name>.yml"
echo "    Stop nodes:     bash scripts/local-pipeline.sh --down"
echo ""

if $CLEANUP; then
  teardown
fi
