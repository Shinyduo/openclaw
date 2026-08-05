#!/bin/sh
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

# Railway mounts volumes root-owned; the image runs as node (uid 1000).
mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"
chown -R 1000:1000 /data

# Drop back to uid 1000 and run the upstream entrypoint (tini) + CMD.
exec setpriv --reuid=1000 --regid=1000 --clear-groups tini -s -- "$@"
