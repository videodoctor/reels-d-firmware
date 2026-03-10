# Feature Map — Type D Port Status

Last updated: 2026-03-10  
Baseline: Phase 8 v3 (stable)  
Reference: 0dan0 firmware v7.7.1 (Type C)

---

## How to Read This Table

**Status values:**
- ✅ `WORKING` — Confirmed working on Type D hardware
- ⚠️ `PARTIAL` — Partially working or intermittently stable
- ❌ `BROKEN` — Attempted, causes known failure
- 🔬 `INVESTIGATING` — Actively being explored
- ⬜ `NOT ATTEMPTED` — Not yet tried on D
- 🚫 `BLOCKED` — Blocked by another feature's failure

**Method column:** `OFFSET` = used +0x1164 offset from C address | `INDEPENDENT` = found via independent Ghidra analysis | `HOOK` = assembly hook injection | `PATCH` = direct byte patch

---

## Core Resolution & Pipeline

| Feature | File Offset (D) | Value | Status | Notes |
|---|---|---|---|---|
| Output resolution | — | — | ✅ LEAVE ALONE | Stock D natively captures and outputs 1728×1296. Do not patch. Patching to 1600×1200 is a downgrade. |
| Framerate (18fps) | `0x1015e8` | `0x12` | ⚠️ IN SCRIPT, UNVALIDATED | Single byte patch. Exists in `patch_phase9.sh`. Not confirmed stable in real scanning sessions. |
| Device type byte | `0x340000` | `0x04` | ✅ CONFIRMED | Required — tells firmware it's Type D. |
| NVM base address | `0x340004` | `0x80E0ADA4` | ✅ CONFIRMED | Required for persistent settings features. |
| NOP printf | `0x1d430` | `0x00000000` | ✅ CONFIRMED | 0dan0's first patch — disables a noisy print call. |

---

## Sensor Resolution Investigation (D-Specific)

| Feature | Address | Status | Notes |
|---|---|---|---|
| Sensor mode table | `0x80DBF448` | ✅ MAPPED | 7 modes, all 16:9 (1936×1076 down to 1792×996). No native 4:3 mode in table. |
| Sensor init function | `0x80D971C0` | 🔬 INVESTIGATING | `Init_OS04D10` string confirmed. Need to follow in Ghidra to find I2C register tables. |
| Mode config struct 1 | `0x802CCBB8` | 🔬 INVESTIGATING | Pointer from mode table header. Contains sensor register init sequence. |
| Mode config struct 2 | `0x802CCB20` | 🔬 INVESTIGATING | Pointer from mode table header. UART read was attempted but session ended. |
| ISP scaling table | `0x80E07090` | ✅ MAPPED | Progressive width values (1806→2116). This is ISP internal scaling, not sensor modes. |
| Native 4:3 sensor mode | Unknown | 🔬 INVESTIGATING | OS04D10 is 4MP — likely has 4:3 mode but not exposed in current init. Goal: 1920×1440 or 2048×1536 true native. |
| Output at stock 1728×1296 | IMEP1 path | ✅ CONFIRMED | Buffer size proves genuine native capture, not upscale. Should be baseline output target. |

---

## Auto Exposure

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| AE hook point 1 | `0x2b68f8` | `0x2b7a5c` | OFFSET | ⚠️ PARTIAL | Phase 7; worked but caused instability |
| AE hook point 2 | `0x2b69fc` | `0x2b7b60` | OFFSET | ⚠️ PARTIAL | See above |
| AE hook point 3 | `0x2b6918` | `0x2b7a7c` | OFFSET | ⚠️ PARTIAL | See above |
| EV bias control | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Depends on AE stability |
| Exposure lock [A]/[L] | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v7.4 feature |
| ISO max control (100/200/400) | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | v7.7 feature |

---

## OSD / C Code Injection

| Feature | File Offset (D) | Status | Notes |
|---|---|---|---|
| Injection region | `0x338f28` (`MANWB_OFFSET`) | ✅ CONFIRMED EXISTS | Same region as C. Free space confirmed. `patch_printf.sh` uses this. |
| Printf patch in injected code | varies | ✅ CONFIRMED METHOD | Replace `0x0c020058` → `0x0c030318`. Automated in `patch_printf.sh`. |
| AE hook point | `0x2b6a60` | ⚠️ IN SCRIPT, UNVALIDATED | Replaces modulus code region. In `patch_printf.sh` but not confirmed stable. |
| WB hook point | `0x2b7e14` | ⚠️ IN SCRIPT, UNVALIDATED | In `patch_printf.sh` but not confirmed stable. |
| RGB Histogram (hist module) | `0x338f28` + manwb size | ⚠️ FLICKERING | Rendered visually but with bad flicker. Root cause unknown. Not usable yet. |
| Manual WB (manwb module) | `0x338f28` | ⚠️ UNVALIDATED | Injected alongside hist. No confirmed working validation. |
| Frame counter | — | ⬜ NOT ATTEMPTED | Depends on stable injection pipeline first. |
| FPS display | — | ⬜ NOT ATTEMPTED | Depends on stable injection pipeline first. |
| EV display | — | ⬜ NOT ATTEMPTED | |
| Qp display | — | ⬜ NOT ATTEMPTED | |
| ISO display | — | ⬜ NOT ATTEMPTED | |

---

## Frame Rate Control

| Feature | File Offset (D) | Value | Status | Notes |
|---|---|---|---|---|
| 18fps default | `0x1015e8` | `0x12` | ⚠️ IN SCRIPT, UNVALIDATED | Single byte. In `patch_phase9.sh`. Mechanically different from C (which used 2-byte `0xF0D2` timing value). The earlier Phase 9 freeze may have been caused by wrong approach — this simpler patch has not been confirmed stable in real scanning. Needs a careful validation session. |
| FPS selector (16/18/24) | — | — | 🚫 BLOCKED | Blocked pending validation of 18fps patch. |

---

## White Balance

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| Fixed WB (RGB gains) | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | Early feature, low complexity |
| Manual WB control (menu) | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v6.6+ feature |
| RGB gains OSD control | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v7.5 feature; requires OSD |

---

## Motor & Capture Control

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| Motor stop on encoder crash | `0x1a9ff8` | TBD | PATCH | ⬜ NOT ATTEMPTED | v5.4 — patches call to error print, reroutes to shutdown code |
| Auto stop (end-of-reel detection) | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Uses luma min/max delta to detect grey frame |
| Hook safety rule | — | — | — | ✅ WORKING | **Rule established in Jan 2026:** Function entry hooks cause motor runaway on D. Use internal function hooks only. |

---

## Capture Quality

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| Qp level control | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v7.3 feature |
| Saturation control | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | B&W mode at -2 |
| Frame controls (zoom/pan) | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Extended zoom-out range |
| Custom boot screen | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | Low priority cosmetic |
| Custom folder naming | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | Low priority |

---

## Priority Queue (Suggested Next Steps)

1. 🔬 **Validate framerate patch in real capture** — single byte `0x12` at file offset `0x1015e8`. Exists in script but not confirmed stable in real-world scanning.
2. 🔬 **Diagnose histogram flicker** — C code injection pipeline works mechanically, histogram renders, but flickers badly. Root cause unknown. This is the key unsolved quality problem.
3. ⬜ **Port fixed white balance** — quick win, low complexity
4. ⬜ **Port motor stop on encoder crash** — safety feature, self-contained
5. ⬜ **Port auto stop (end-of-reel)** — useful for unattended scanning

---

## Known D-Specific Facts & Constraints

- **1728×1296 is stock D native** — do NOT patch resolution. Leave it alone. This is already better than modded C.
- **Framerate patch for D is a single byte** — value `0x12` (decimal 18) at file offset `0x1015e8`. Simpler than C's 2-byte timing value approach.
- **NVM base address for D:** `0x80E0ADA4` (written to file offset `0x340004`) — required for any feature using persistent settings.
- **Device type byte:** `0x04` at file offset `0x340000`
- **C code injection region `0x338f28` confirmed present in D** — `patch_printf.sh` uses this as `MANWB_OFFSET`. The free region exists.
- **Printf must be patched in injected code** — replace `0x0c020058` (JAL libc printf) with `0x0c030318` (JAL firmware-internal print). Done automatically by `patch_printf.sh`.
- **Function entry hooks → motor runaway** — always hook inside functions, not at entry points.
- **AE hook at file offset `0x2b6a60`** — confirmed in script, replaces modulus code region.
- **WB hook at file offset `0x2b7e14`** — confirmed in script.
- **+0x1164 offset** is a useful starting hypothesis but verify every address in Ghidra before trusting it.
