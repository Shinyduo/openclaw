#!/bin/sh
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$STATE_DIR}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"
BIND="${OPENCLAW_GATEWAY_BIND:-lan}"

# Config (openclaw.json, auth profiles, gateway token) lives in CONFIG_DIR, which
# defaults to $HOME/.openclaw - off-volume, so it would vanish on every redeploy.
export OPENCLAW_CONFIG_DIR="$CONFIG_DIR"

# Railway mounts volumes root-owned; the image runs as node (uid 1000).
mkdir -p "$STATE_DIR" "$WORKSPACE_DIR" \
  "$CONFIG_DIR/identity" "$CONFIG_DIR/agents/main/agent" "$CONFIG_DIR/agents/main/sessions"
chown -R 1000:1000 /data

as_node() {
  setpriv --reuid=1000 --regid=1000 --clear-groups "$@"
}

# The gateway refuses to start unconfigured ("Missing config. Run `openclaw setup`
# or set gateway.mode=local"). There is no env var for this, so pin the same
# config upstream's scripts/docker/setup.sh writes. Idempotent, safe every boot.
as_node openclaw config set --batch-json \
  "[{\"path\":\"gateway.mode\",\"value\":\"local\"},{\"path\":\"gateway.bind\",\"value\":\"$BIND\"}]" >/dev/null

# Non-loopback binds need a Control UI origin allowlist. Only seed it when empty
# so a custom domain added later isn't clobbered on the next deploy.
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  CURRENT="$(as_node openclaw config get gateway.controlUi.allowedOrigins 2>/dev/null || true)"
  case "$(printf '%s' "$CURRENT" | tr -d '\r')" in
    ""|null|"[]")
      as_node openclaw config set --batch-json \
        "[{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":[\"https://$RAILWAY_PUBLIC_DOMAIN\"]}]" >/dev/null
      ;;
  esac
fi

# Drop back to uid 1000 and run the upstream entrypoint (tini) + CMD.
exec setpriv --reuid=1000 --regid=1000 --clear-groups tini -s -- "$@"
