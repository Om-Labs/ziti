#!/usr/bin/env bash
set -euo pipefail

# Install the ziti-tunnel systemd service on the local machine.
#
# Usage:
#   scripts/install_tunnel_service.sh                          # interactive
#   IDENTITY=/path/to/id.json scripts/install_tunnel_service.sh  # explicit

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '[%s] ==> %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() { printf '[%s] ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

# --- prereqs ---------------------------------------------------------------

[[ $EUID -eq 0 ]] || die "Must run as root (sudo)"
command -v ziti >/dev/null 2>&1 || die "ziti CLI not found in PATH"

# --- identity file ---------------------------------------------------------

IDENTITY="${IDENTITY:-}"
IDENTITY_DIR="/etc/ziti/identities"

if [[ -z "$IDENTITY" ]]; then
  # Auto-detect: use the first .json file in out/identities/ that isn't a JWT.
  for f in "$ROOT_DIR"/out/identities/*.json; do
    [[ -f "$f" ]] || continue
    IDENTITY="$f"
    break
  done
fi

[[ -n "$IDENTITY" ]] || die "No identity file found. Set IDENTITY=/path/to/id.json"
[[ -f "$IDENTITY" ]] || die "Identity file not found: $IDENTITY"

IDENTITY_NAME="$(basename "$IDENTITY")"
log "Using identity: $IDENTITY"

# --- install ---------------------------------------------------------------

log "Creating $IDENTITY_DIR"
mkdir -p "$IDENTITY_DIR"

log "Copying identity to $IDENTITY_DIR/$IDENTITY_NAME"
cp "$IDENTITY" "$IDENTITY_DIR/$IDENTITY_NAME"
chmod 600 "$IDENTITY_DIR/$IDENTITY_NAME"

# Patch service file if identity name differs from default.
SERVICE_SRC="$ROOT_DIR/systemd/ziti-tunnel.service"
SERVICE_DST="/etc/systemd/system/ziti-tunnel.service"

if [[ "$IDENTITY_NAME" != "matthew-laptop.json" ]]; then
  log "Patching service file for identity: $IDENTITY_NAME"
  sed "s|matthew-laptop.json|${IDENTITY_NAME}|g" "$SERVICE_SRC" > "$SERVICE_DST"
else
  cp "$SERVICE_SRC" "$SERVICE_DST"
fi

# --- stop existing manual tunnel ------------------------------------------

if pgrep -f "ziti tunnel" >/dev/null 2>&1; then
  log "Stopping existing ziti tunnel process"
  pkill -f "ziti tunnel" || true
  sleep 2
fi

# --- enable + start --------------------------------------------------------

log "Reloading systemd"
systemctl daemon-reload

log "Enabling and starting ziti-tunnel"
systemctl enable --now ziti-tunnel

sleep 3
if systemctl is-active --quiet ziti-tunnel; then
  log "ziti-tunnel is running"
  systemctl status ziti-tunnel --no-pager
else
  die "ziti-tunnel failed to start — check: journalctl -u ziti-tunnel -n 50"
fi
