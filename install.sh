#!/usr/bin/env bash
# resolve-perf installer — root helper + user watcher + sudoers rule.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
USER_NAME=${SUDO_USER:-$(id -un)}
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

echo "==> checking dependencies"
for dep in socat jq wrmsr rdmsr; do
  command -v "$dep" >/dev/null || {
    echo "missing: $dep  (pacman -S socat jq msr-tools)" >&2
    exit 1
  }
done

echo "==> installing root helper -> /usr/local/sbin/resolve-perf"
install -o root -g root -m 0755 "$HERE/resolve-perf" /usr/local/sbin/resolve-perf

echo "==> installing watcher -> $USER_HOME/.local/bin/resolve-perf-watch"
install -D -o "$USER_NAME" -g "$USER_NAME" -m 0755 \
  "$HERE/resolve-perf-watch" "$USER_HOME/.local/bin/resolve-perf-watch"

echo "==> installing sudoers rule -> /etc/sudoers.d/resolve-perf"
cat >/etc/sudoers.d/resolve-perf <<EOF
# DaVinci Resolve performance mode (see ~/.local/bin/resolve-perf-watch)
$USER_NAME ALL=(root) NOPASSWD: /usr/local/sbin/resolve-perf on, /usr/local/sbin/resolve-perf off, /usr/local/sbin/resolve-perf status
EOF
chmod 0440 /etc/sudoers.d/resolve-perf
visudo -c

echo
echo "==> done. Add this line to ~/.config/hypr/autostart.lua:"
echo "o.launch_on_start(\"$USER_HOME/.local/bin/resolve-perf-watch\")"
echo
echo "Manual test:   sudo resolve-perf on && resolve-perf status && sudo resolve-perf off"
