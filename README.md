<div align="center">

# 👁 SoulEyes

**The 20-20-20 rule, enforced beautifully.**

*Every 20 minutes, look at something 20 feet away for 20 seconds.*

[![Build](https://github.com/proxysoul/soulEyes/actions/workflows/build.yml/badge.svg)](https://github.com/proxysoul/soulEyes/actions/workflows/build.yml)
[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://github.com/proxysoul/soulEyes/releases)
[![License](https://img.shields.io/badge/license-MIT-AD82FF)](LICENSE)

<br>

<!-- Add screenshots here -->
<!-- ![SoulEyes Overlay](screenshots/overlay.png) -->
<!-- ![SoulEyes Menu Bar](screenshots/menubar.png) -->

</div>

---

## ✦ What it does

SoulEyes lives in your menu bar and quietly counts down 20 minutes. When time's up, a fullscreen overlay appears with animated particles and a glowing countdown ring. You look away for 20 seconds, and it fades out. Repeat forever.

## ✦ Features

- **~200KB binary** — single Swift file, zero dependencies
- **~8MB RAM** — native Cocoa, no Electron, no frameworks
- **Menu bar countdown** — always visible `👁 18:42` ticking down
- **Fullscreen overlay** — dark theme with purple glow, floating particles, ring animation
- **Skip / Snooze / Mute** — skip any break, mute for 5 / 10 / 30 / 60 min
- **Sleep & lock aware** — pauses on screen lock, system sleep, screensaver; resets on wake
- **SF Symbols** — native Apple vector icons throughout
- **Auto-start** — LaunchAgent for login startup
- **Retina-sharp** — all rendering is vector/layer-based

## ✦ Install

### Option A: Download release (recommended)

1. Go to [**Releases**](https://github.com/proxysoul/soulEyes/releases)
2. Download `SoulEyes.app.zip`
3. Unzip and drag **SoulEyes.app** to `/Applications`
4. Open it — grant accessibility if prompted
5. (Optional) Right-click → Options → Open at Login

### Option B: Build from source

```bash
git clone https://github.com/proxysoul/soulEyes.git
cd soulEyes
./install.sh
```

This compiles, installs to `/usr/local/bin/`, and sets up auto-start via LaunchAgent.

### Option C: Just run it

```bash
git clone https://github.com/proxysoul/soulEyes.git
cd soulEyes
swiftc -O -framework Cocoa -framework QuartzCore -o SoulEyes SoulEyes.swift
./SoulEyes
```

## ✦ Uninstall

```bash
./uninstall.sh
```

Or if you used the .app: drag SoulEyes.app to Trash.

## ✦ Menu bar

| State | Display |
|---|---|
| Counting down | `👁 18:42` |
| Paused | `👁 paused` |
| On break | `👁 break!` |
| Muted | `👁 🔇 8:42` |
| Screen locked / sleeping | `👁 💤` |

Click the icon for pause/resume, break now, mute, and more.

## ✦ Overlay controls

| Button | Action |
|---|---|
| **▶ Start Break** | Begin 20-second countdown |
| **Skip** | Dismiss overlay, restart 20-min cycle |
| **5m / 10m / 30m** | Mute — dismiss and delay next break |
| **Esc** | Same as Skip |

## ✦ Requirements

- macOS 13+ (Ventura or later)
- That's it

## ✦ Stack

- **Language:** Swift 5.9+
- **Frameworks:** Cocoa, QuartzCore (both built into macOS)
- **Dependencies:** zero
- **Build:** single `swiftc` invocation

## ✦ Transfer to another Mac

```bash
scp -r ~/dev/soulEyes user@other-mac:~/dev/soulEyes
ssh user@other-mac "cd ~/dev/soulEyes && ./install.sh"
```

---

<div align="center">

**[proxysoul.com](https://proxysoul.com)** · built with **SoulForge** ⚡

</div>
