# Session Notes: 2026-01-through-02 — Build Pipeline & Patch Scripts

**Date range:** January–February 2026  
**Participants:** videodoctor, Claude (AI assist)  
**Goal:** Establish a working build/patch pipeline for Type D firmware  
**Outcome:** ⚠️ Pipeline mechanically works; feature validation incomplete

---

## What Was Built

Three shell scripts form the complete D firmware build pipeline:

### `patch_phase9.sh`
Applies the core D-specific binary patches to a base firmware file (takes `FWDV280-D_0dan0.rbn` as input, produces `FWDV280-D-phase9.rbn`):

| Patch | File Offset | Value | Purpose |
|---|---|---|---|
| Device type | `0x340000` | `0x04000000` | Identifies firmware as Type D |
| NVM base addr | `0x340004` | `0x80E0ADA4` | D-specific NVM address |
| NOP printf | `0x1d430` | `0x00000000` | Silences noisy print (0dan0's first change) |
| Resolution W | `0x1c5c48`, `0x1c5cac`, `0x1c7170` | `0x0640` | Width = 1600 |
| Resolution H | `0x1c5c50`, `0x1c5cb4`, `0x1c7178` | `0x04b0` | Height = 1200 |
| Framerate | `0x1015e8` | `0x12` | 18fps (single byte) |

> ⚠️ **Note on resolution patches:** These patch to 1600×1200. Stock D natively outputs 1728×1296. These patches are a downgrade and should be removed or changed to 1728×1296 in a future revision.

> ⚠️ **Note on framerate patch:** The `0x12` (18fps) single-byte patch exists in the script but has **not been confirmed stable** in real scanning sessions. The earlier "Phase 9 freeze" was likely caused by a different, incorrect approach. This simpler patch needs careful validation.

### `patch_printf.sh`
Takes `FWDV280-D-phase9.rbn`, compiles and injects C code modules (`manwb/` and `hist/`) into the free region at `0x338f28`:

- Runs `make` to compile the C modules
- Uses `mipsel-linux-gnu-objcopy` to extract raw binary
- Strips header via `CUT HERE` marker pattern
- Patches printf calls: replaces `0x0c020058` (JAL libc printf) → `0x0c030318` (JAL firmware-internal print)
- NOPs any raw syscalls (`0x0c380000` → `0x00000000`)
- Injects `manwb` at `0x338f28`, then `hist` immediately after
- Installs hooks:
  - AE hook at file offset `0x2b6a60` → `hist` entry point (JAL)
  - WB hook at file offset `0x2b7e14` → `manwb` entry point (JAL)

> ⚠️ **Validation status:** The histogram **rendered visually** but with **bad flicker**. Root cause not identified. The manwb (manual white balance) module was injected but not independently validated. The pipeline mechanics work; the feature quality does not.

### `build_local.sh`
Final packaging step:
- Finds most recent `.rbn` file
- Runs `./utils/ntkcalc -cw` (checksum recalc)
- Runs `./utils/bfc4ntk -c` (Novatek packaging)
- Mounts D: drive (SD card) and copies `FWDV280.BIN` to it

> ⚠️ **Dependencies:** Requires `./utils/ntkcalc` and `./utils/bfc4ntk` binaries. These are Novatek tools — not open source. Keep them alongside the scripts but do NOT commit them to git (binary blobs, license unclear).

---

## Histogram Flicker — What We Know

- Histogram **does render** on screen during capture
- Flicker is **bad enough to be unusable**
- Possible causes (none confirmed):
  1. Hook running too frequently or at wrong point in frame pipeline
  2. Memory conflict between hist code and firmware working buffers
  3. AE hook at `0x2b6a60` (modulus replacement) fires at wrong cadence
  4. The commented-out `MODULO_BRANCH` NOP in the script (`0x2b6a60`) suggests we experimented with run-every-frame vs. modulo-3 cadence — the right cadence is unknown
- The script has several commented-out alternatives (different hook offsets, NOP branches) that reflect this uncertainty

---

## Things That Need Validating Before Claiming They Work

- [ ] 18fps framerate patch (`0x1015e8` = `0x12`) — run a real capture, check output file
- [ ] Resolution patches — consider removing or replacing with 1728×1296
- [ ] Histogram render quality — fix flicker before declaring any OSD feature working
- [ ] WB hook — no independent validation of manwb functionality

---

## Build Environment Requirements

- `mipsel-linux-gnu-objcopy` — MIPS cross-compilation tools
  ```bash
  sudo apt install binutils-mipsel-linux-gnu
  ```
- `make` + MIPS cross-compiler for rebuilding C modules:
  ```bash
  sudo apt install gcc-mipsel-linux-gnu
  ```
- `./utils/ntkcalc` and `./utils/bfc4ntk` — Novatek proprietary tools (not in repo)
- SD card mounted at `/mnt/d` (Windows D: drive via WSL `drvfs`)
