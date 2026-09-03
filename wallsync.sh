#!/bin/bash

set -eou pipefail

# launchd runs with a minimal PATH that omits the Tailscale CLI. /usr/local/bin
# holds the wrapper Tailscale's "Install CLI" creates; fall back to the app bundle.
export PATH="$PATH:/usr/local/bin:/Applications/Tailscale.app/Contents/MacOS"

LOCAL_WALLPAPERS="$HOME/Pictures/wallpapers/"
DESTINATION_SERVER="thoughts-server.tail53451c.ts.net"
DESTINATION="thoughts@$DESTINATION_SERVER:~/wallpapers"

echo "Syncing directories"

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "This script is designed for macOS"
  exit 1
fi

if ! tailscale ping "$DESTINATION_SERVER" >/dev/null 2>&1; then
  echo "Destination unreachable"
  exit 1
fi

# Hold a kernel-level flock(2) rather than testing for the file's existence, so a
# lock left behind by a SIGKILL or a reboot is not mistaken for a running sync.
# The kernel drops the lock when the last holder dies; the file itself is inert.
LOCKFILE="/tmp/wall-sync.lock"
exec 9>"$LOCKFILE"
if ! lockf -st 0 9; then
  echo "already running"
  exit 0
fi

rsync -az "$LOCAL_WALLPAPERS" "$DESTINATION"

rsync -az "$DESTINATION/" "$LOCAL_WALLPAPERS"
