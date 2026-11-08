#!/usr/bin/env bash
# test-vm.sh - Provisionierung auf einer Wegwerf-VM testen.
#
# Baut eine Ubuntu-24.04-Cloud-VM (QEMU/KVM im Container), provisioniert sie
# mit site.yml und misst die Zeit. Die VM ist nach dem Lauf weg, die
# Festplatte liegt als Overlay in $WORK und laesst sich loeschen.
#
# Voraussetzungen: docker, /dev/kvm, ca. 3 GB freier Platz.
# Kein sudo noetig - alles laeuft im Container.
#
#   ./scripts/test-vm.sh            # Standard: Plattform-Rollen
#   TAGS=base,ssh ./scripts/test-vm.sh
#   RESET=1 ./scripts/test-vm.sh    # Overlay neu aufsetzen
#
# Wichtig: die VM laeuft in einem Docker-Container, und der Gast sieht als
# SSH-Gegenstelle die Docker-Bridge (172.17.0.1), nicht 10.0.2.2. Deshalb das
# Wartungsnetz 172.17.0.0/16 - mit dem qemu-eigenen Netz 10.0.2.0/24 sperrt
# ufw den Zugang nach dem Aktivieren aus.
#
# Bewusst nicht enthalten: die Stack-Rollen. Sie brauchen ~6 GB RAM
# (Summe der mem_limits) - dafuer ist eine kleine VM die falsche Umgebung.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$HOME/.vps-test-vm}
TAGS=${TAGS:-base,tailscale,ssh,ufw,fail2ban,docker}
SSH_PORT=${SSH_PORT:-2200}
PUBKEY=${PUBKEY:-$HOME/.ssh/id_ed25519.pub}
VM_MEM=${VM_MEM:-3072}
VM_CPU=${VM_CPU:-4}
IMAGE_URL=${IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}
QEMU_IMAGE=qemu-cloud
CONTAINER=vpstest-vm

DATA="$WORK/data"
mkdir -p "$DATA"

command -v docker >/dev/null || { echo "docker fehlt"; exit 2; }
[ -r /dev/kvm ] || echo "WARNUNG: /dev/kvm nicht lesbar - die VM wird sehr langsam"

# --- Container-Image mit qemu bauen (einmalig) -------------------------------
if ! docker image inspect "$QEMU_IMAGE" >/dev/null 2>&1; then
  echo "== baue $QEMU_IMAGE (einmalig)"
  mkdir -p "$WORK/build"
  cat > "$WORK/build/Dockerfile" <<'EOF'
FROM debian:12-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends qemu-system-x86 qemu-utils genisoimage ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /data
ENTRYPOINT ["qemu-system-x86_64"]
EOF
  docker build -q -t "$QEMU_IMAGE" "$WORK/build"
fi

# --- Cloud-Image laden (einmalig) -------------------------------------------
if [ ! -f "$DATA/noble.img" ]; then
  echo "== lade Ubuntu-24.04-Cloud-Image (~600 MB)"
  curl -sSL -o "$DATA/noble.img" "$IMAGE_URL"
fi

# --- cloud-init: Standard-User ubuntu, Key des Aufrufers ---------------------
# Ein eigener User im users-Block ist auf dem Cloud-Image unzuverlaessig
# (users_groups schlaegt fehl) - der Default-User funktioniert.
KEY=$(<"$PUBKEY")
cat > "$DATA/user-data" <<EOF
#cloud-config
hostname: vps-test
ssh_authorized_keys:
  - $KEY
EOF
printf 'instance-id: vps-test-%s\nlocal-hostname: vps-test\n' "$(date +%s)" > "$DATA/meta-data"
docker run --rm -v "$DATA":/data --entrypoint genisoimage "$QEMU_IMAGE" \
  -output /data/seed.iso -volid cidata -joliet -rock /data/user-data /data/meta-data 2>/dev/null

# --- Overlay: frisch oder weiterverwenden ------------------------------------
if [ "${RESET:-0}" = "1" ] || [ ! -f "$DATA/disk.qcow2" ]; then
  echo "== lege frisches Overlay an"
  docker run --rm -v "$DATA":/data --entrypoint qemu-img "$QEMU_IMAGE" \
    create -f qcow2 -b /data/noble.img -F qcow2 /data/disk.qcow2 20G >/dev/null
fi

# --- VM starten --------------------------------------------------------------
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --device /dev/kvm -v "$DATA":/data -p "$SSH_PORT":22 "$QEMU_IMAGE" \
  -enable-kvm -m "$VM_MEM" -smp "$VM_CPU" -cpu host \
  -drive file=/data/disk.qcow2,if=virtio,format=qcow2,cache=unsafe,aio=threads \
  -drive file=/data/seed.iso,media=cdrom \
  -netdev user,id=n0,hostfwd=tcp::22-:22 \
  -device virtio-net-pci,netdev=n0 -display none -serial "file:/data/console.log" >/dev/null

trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

echo "== warte auf SSH"
for _ in $(seq 1 40); do
  if timeout 6 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o BatchMode=yes -o ConnectTimeout=4 -p "$SSH_PORT" ubuntu@127.0.0.1 true 2>/dev/null; then
    break
  fi
  sleep 5
done

# --- Provisionieren ----------------------------------------------------------
cat > "$DATA/inventory.ini" <<EOF
[prod]
vm ansible_host=127.0.0.1 ansible_port=$SSH_PORT ansible_user=ubuntu ansible_ssh_private_key_file=$HOME/.ssh/id_ed25519
EOF

echo "== starte Playbook (tags: $TAGS)"
START=$(date +%s)
cd "$REPO_ROOT"
ANSIBLE_TIMEOUT=60 ansible-playbook site.yml -i "$DATA/inventory.ini" --tags "$TAGS" \
  -e ssh_port=22 -e admin_user=ubuntu \
  -e ufw_maintenance_cidr=172.17.0.0/16 \
  -e 'fail2ban_ignoreip=127.0.0.1/8 ::1 172.17.0.0/16' \
  --vault-password-file "${VAULT_PASSWORD_FILE:-/dev/null}" || true
END=$(date +%s)

echo
echo "== Laufzeit: $((END - START)) s"
echo "== Konsole:  $DATA/console.log"
echo "== Reset:    RESET=1 $0"
