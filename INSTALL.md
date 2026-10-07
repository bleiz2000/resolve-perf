# Installation

Step-by-step setup for **Arch Linux + Omarchy/Hyprland** with an NVIDIA laptop.
Everything is designed for my HP Victus 16 (i5-13500H + RTX 4060 8 GB) —
on other machines the steps are the same, the power numbers are not.

## 0. Requirements

* Arch-based system running **Hyprland** (Omarchy uses `~/.config/hypr/autostart.lua`)
* NVIDIA proprietary driver with NVENC/OpenCL/CUDA (works with 610.57.04)
* DaVinci Resolve / Resolve Studio installed (AUR: `davinci-resolve-studio`)
* User able to run `sudo` (the helper needs root for `wrmsr` and cpufreq)

```bash
sudo pacman -S --needed socat jq msr-tools
```

## 1. Get the scripts

```bash
git clone https://github.com/bleiz2000/resolve-perf.git
cd resolve-perf
```

## 2. Run the installer

```bash
./install.sh
```

What it does:

| Step | Result |
|---|---|
| root helper | `/usr/local/sbin/resolve-perf` (0755, root) |
| watcher | `~/.local/bin/resolve-perf-watch` (0755, your user) |
| sudoers | `/etc/sudoers.d/resolve-perf` — NOPASSWD **only** for `resolve-perf on/off/status`, checked with `visudo -c` |

Manual alternative, if you prefer to skip `install.sh`:

```bash
sudo install -o root -g root -m 0755 resolve-perf /usr/local/sbin/resolve-perf
install -D -m 0755 resolve-perf-watch ~/.local/bin/resolve-perf-watch
sudo tee /etc/sudoers.d/resolve-perf >/dev/null <<'EOF'
YOURUSER ALL=(root) NOPASSWD: /usr/local/sbin/resolve-perf on, /usr/local/sbin/resolve-perf off, /usr/local/sbin/resolve-perf status
EOF
sudo chmod 0440 /etc/sudoers.d/resolve-perf && sudo visudo -c
```

## 3. Autostart (one line)

Append to `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("/home/YOURUSER/.local/bin/resolve-perf-watch")
```

Reload the config:

```bash
hyprctl reload && hyprctl configerrors   # must print nothing
```

## 4. Optional but recommended: render cache without compression

```bash
mkdir -p ~/ResolveCache
sudo chattr +C ~/ResolveCache    # btrfs: disables zstd on this subtree
lsattr -d ~/ResolveCache         # -> ---------------C------
```

Then add `~/ResolveCache` as Resolve's Media Storage
(**Preferences → Media Storage → Add Storage**).

## 5. Test it

```bash
# 1) watcher on (auto-applies immediately):
resolve-perf-watch status        # watcher: stopped / running

# 2) open DaVinci Resolve -> within a second:
cat ~/.local/state/resolve-perf.log | tail -2
#   ... watch: mode ON
sudo resolve-perf status
#   {"active":true,"ac":true,"no_turbo":0,"max_freq_khz":4700000,...}

# 3) close Resolve -> within a second:
#   ... watch: mode OFF     (2.6 GHz, powersave, dGPU auto again)

# 4) the one-switch stop/start:
resolve-perf-watch toggle        # stops everything, or starts it again
resolve-perf-watch stop          # kill watcher + restore quiet state
```

Expected values **on AC with Resolve open**: `no_turbo=0`,
`max_freq_khz=4700000`, `governor=performance`, `dgpu_control=on`.
On battery the script changes nothing (and reverts itself if the charger
is unplugged mid-session).

## 6. Uninstall

```bash
resolve-perf-watch stop
sudo rm -f /usr/local/sbin/resolve-perf /etc/sudoers.d/resolve-perf
rm -f ~/.local/bin/resolve-perf-watch
# remove the o.launch_on_start(...) line from ~/.config/hypr/autostart.lua
sudo rm -rf /var/lib/resolve-perf
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `resolve-perf status` shows `"turbo_msr":"n/a"` | `rdmsr` needs root — run `sudo resolve-perf status` |
| `no_turbo` stays `1` after `on` | BIOS re-locks `IA32_MISC_ENABLE[38]` on reboot; the helper clears it on every `on`. If it still fails: `sudo wrmsr 0x1A0 0x850089` |
| `wrmsr: cannot set MSR ... to 0xee7820a9` | this machine parses `0x`-less values as decimal — always pass `0x...` |
| `nvidia-smi -pl` fails: *not supported* | laptop GPUs reject it; driver already does 40 W battery / 80 W AC |
| watcher exits: *no Hyprland socket2* | `ls $XDG_RUNTIME_DIR/hypr/*/.socket2.sock` — path changed after Hyprland restart, just restart the watcher |
| `already running` in the log | a stale `socat` child kept the lock — `resolve-perf-watch stop` clears it |

Log file: `~/.local/state/resolve-perf.log`
State file: `/var/lib/resolve-perf/state`
