# Branch: `yumi-armhf`

This branch is a customization layer on top of the `master` branch (which tracks [RetroPie/RetroPie-Setup](https://github.com/RetroPie/RetroPie-Setup) upstream).

It targets **AllWinner H3 (Cortex-A7, ARMv7 armhf)** with a **Mali-400 GPU (GLES 2.0, no desktop OpenGL)** — specifically the [SmartPi One](https://www.smart-pi.org) board running **Debian 12 Bookworm armhf**.

> This branch is used by [RetroMi-packages](https://github.com/Yumi-Lab/RetroMi-packages) to build pre-compiled emulator packages for the [RetroMi](https://github.com/Yumi-Lab/RetroMi) retrogaming OS.

---

## Differences from upstream RetroPie-Setup

### `scriptmodules/ports/openbor.sh`

| | Upstream | `yumi-armhf` |
|---|---|---|
| Source repo | `DCurrent/openbor` | `DCurrent/openbor` (same) |
| Build system | CMake | CMake |
| `rp_module_flags` | `!mali !x11` | `!x11` — **`!mali` removed** |
| OpenGL | `USE_OPENGL ON` (default) | Patched OFF via `sed` on `linux.cmake` |
| WebM video | `USE_WEBM ON` (default) | Patched OFF (no `libvpx` on armhf) |

**Why `!mali` was removed:**  
RetroPie uses the `!mali` flag to skip installation on Mali-400 GPU targets because most ports require OpenGL. OpenBOR compiled with `USE_OPENGL=OFF` runs on SDL2 only — no OpenGL required — so it works perfectly on Mali-400.

**Why we patch `linux.cmake` instead of using cmake `-D` flags:**  
`linux.cmake` uses `set(USE_OPENGL ON)` as a local CMake variable, which overrides command-line `-DUSE_OPENGL=OFF` cache entries. The only reliable fix is to patch the file directly before the cmake invocation.

---

## Branch structure

```
master        ← synced with RetroPie/RetroPie-Setup upstream (never modified directly)
yumi-armhf    ← our patches rebased on top of master (3 commits)
```

### Commits on this branch (above master)

**Scriptmodule patches:**
```
efca085  fix(openbor): patch linux.cmake to disable OpenGL+WebM for Mali-400
d8dafb9  feat(openbor): migrate to DCurrent/openbor — SDL2, CMake, no OpenGL
```

**CI/Documentation:**
```
7223af8  fix(ci): install curl+ca-certificates before install.sh in Debian minimal image
c50068a  ci: simulate install.sh on debian bookworm + trixie armhf — user install validation
a8c3d6a  docs(yumi-armhf): add branch README — patches, update workflow, usage
```

---

## Keeping this branch up to date

When RetroPie upstream merges new modules or fixes:

**1. Sync `master` with upstream** (via GitHub UI):

> `Yumi-Lab/RetroPie-Setup` → **Sync fork** button

Or via CLI:
```bash
git fetch retropie-upstream
git push origin master:master
```

**2. Rebase `yumi-armhf` on updated `master`:**
```bash
git fetch origin
git rebase origin/master yumi-armhf
git push origin yumi-armhf --force-with-lease
```

Our 3 commits will cleanly reapply on top of the new master.

---

## Usage

### Direct use on SmartPi One (native armhf)

Clone **this fork** (not the upstream `RetroPie/RetroPie-Setup`) on the SmartPi One:

```bash
git clone --depth=1 -b yumi-armhf \
    https://github.com/Yumi-Lab/RetroPie-Setup.git \
    ~/RetroPie-Setup
cd ~/RetroPie-Setup
sudo ./retropie_setup.sh
```

> **Important:** Do **not** clone from `https://github.com/RetroPie/RetroPie-Setup.git` — the upstream build will fail on Mali-400 (OpenBOR skipped, other packages may error). This fork removes the `!mali` flag and patches `linux.cmake` so builds work on SmartPi One H3.

### Used by RetroMi-packages (QEMU builds)

This branch is cloned automatically by [RetroMi-packages/scripts/build-group.sh](https://github.com/Yumi-Lab/RetroMi-packages/blob/main/scripts/build-group.sh) inside QEMU armhf Docker containers:

```bash
git clone --depth=1 -b yumi-armhf \
    https://github.com/Yumi-Lab/RetroPie-Setup.git \
    /home/pi/RetroPie-Setup
```

---

## Related repositories

| Repo | Role |
|------|------|
| [Yumi-Lab/RetroMi](https://github.com/Yumi-Lab/RetroMi) | RetroMi OS image builder |
| [Yumi-Lab/RetroMi-packages](https://github.com/Yumi-Lab/RetroMi-packages) | Pre-compiled emulator packages — uses this branch |
| [Yumi-Lab/YUMI-RETROPIE](https://github.com/Yumi-Lab/YUMI-RETROPIE) | End-user installer (`install.sh`) |
| [RetroPie/RetroPie-Setup](https://github.com/RetroPie/RetroPie-Setup) | Upstream — `master` tracks this |
