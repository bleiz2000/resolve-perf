# resolve-perf

AC-aware performance mode for **DaVinci Resolve** on an **HP Victus laptop**
(i5-13500H + RTX 4060 Laptop), running **Omarchy / Arch Linux / Hyprland**.

Open Resolve → the machine switches to full performance.
Close it → everything goes back to the quiet, battery-safe state.

> Built specifically for my hardware (HP Victus 16, RTX 4060 8 GB, 230 W
> adapter). Paths, GPU model and thermal behaviour are tuned for this box —
> on other laptops the logic works, but the power figures in this README do not.

## Why

DaVinci Resolve is a CPU/GPU hog, and this laptop ships in a state that
sabotages it:

| Problem | Default | With `resolve-perf` |
|---|---|---|
| Turbo Boost locked by BIOS (`IA32_MISC_ENABLE[38]`) | CPU capped at **2.6 GHz** (`dmesg: "Turbo disabled by BIOS"`) | MSR bit cleared → **4.7 GHz** |
| `intel_pstate/no_turbo` rejects writes | `echo 0 > no_turbo` → *Operation not permitted* | unlocked first, then enabled |
| cpufreq governor | `powersave` | `performance` (AC only) |
| dGPU runtime PM | `auto` → parked in D3cold | `on` while Resolve runs |

The other half of the requirement: **nothing may get more power hungry on
battery**. So the whole mode is gated on AC presence.

## How it works

Two small scripts:

### 1. `resolve-perf` (root helper — `/usr/local/sbin/`)

`resolve-perf on | off | status`

* **`on`** — if AC is online: saves the current state, clears the BIOS turbo
  lock (`wrmsr 0x1A0`), sets `no_turbo=0`, switches every cpufreq policy to
  `performance` (governor + EPP), keeps NVIDIA persistence mode on and writes
  `power/control=on` for the NVIDIA PCI device (no more D3cold wake latency).
* **`off`** — restores every saved value byte-for-byte and deletes the state.
* **`on` while on battery** — does *nothing*, or reverts to the quiet state if
  the charger was unplugged mid-session.
* **`status`** — JSON: `active`, `ac`, `no_turbo`, `turbo_msr`, `max_freq_khz`,
  `governor`, `gpu`, `dgpu_control`.

Deliberately **not** touched: RAPL (`PL1/PL2 = 115/115 W` stays as-is),
fans and `platform_profile` — those are handled by my own
[victus-suite](https://github.com/bleiz2000/victus-suite) tooling.

State: `/var/lib/resolve-perf/state` · Log: `~/.local/state/resolve-perf.log`

### 2. `resolve-perf-watch` (user daemon — `~/.local/bin/`)

* connects to the **Hyprland socket2** event stream (`socat`)
* on `openwindow` / `closewindow` matching the Resolve class
  (`resolve` *or* `davinci-resolve-studio`, depending on `argv0`) it runs
  `resolve-perf on` / `off`
* re-checks every **60 s** so AC plug/unplug mid-session is picked up
* `flock` makes it single-instance; on exit it restores the quiet state
* desktop notification + log line on every switch

Started from `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("/home/YOURUSER/.local/bin/resolve-perf-watch")
```

### GPU power limits (no script needed)

Laptop GPUs reject `nvidia-smi -pl` ("not supported") — and the driver already
does the right thing:

* battery → **40 W**
* AC → **80 W** (VBIOS max is 120 W)

So battery consumption never goes up, by design.

## Install

```bash
./install.sh
```

It copies both scripts, drops `/etc/sudoers.d/resolve-perf` (NOPASSWD for the
three helper subcommands only) and prints the one-line autostart snippet.
Requires `socat`, `jq`, `msr-tools` (`pacman -S socat jq msr-tools`).

## Verified on

* DaVinci Resolve **Studio 21.1** (AUR package `davinci-resolve-studio`)
* NVIDIA driver **610.57.04**, OpenCL + CUDA present
* Omarchy 4.0.4 / Hyprland / Arch Linux
* 2.6 GHz → 4.7 GHz, `powersave` → `performance`, D3cold → `on`,
  full ON/OFF cycle driven by real window events

---

**Credits**

* Subtitle editor: **A. Semkin**
* Corrector: **A. Egorova**
