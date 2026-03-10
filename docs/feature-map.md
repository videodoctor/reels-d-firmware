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

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| 1600×1200 encode resolution | `0x2bf908` | `0x2c0a6c` | OFFSET | ✅ WORKING | Stable in Phase 8 v3 |
| 1600×1200 preview resolution | `0x2bfe74` | `0x2c0fd8` | OFFSET | ✅ WORKING | Stable in Phase 8 v3 |
| Disable 3DNR | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | Low priority |
| Full range flag (MP4 metadata) | TBD | TBD | PATCH | ⬜ NOT ATTEMPTED | avcC atom fix |
| Frame buffer memory layout | — | — | — | 🔬 INVESTIGATING | D sensor may have different buffer geometry |

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

## OSD (On-Screen Display)

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| OSD injection point | `0x338f28` | TBD | INDEPENDENT | 🔬 INVESTIGATING | 0dan0's C extensions live at 0x338f28–0x33a190 in C; D equivalent not yet found |
| Frame counter (Frm) | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Requires OSD injection point first |
| FPS display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Requires OSD injection point first |
| RGB histogram | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | Most complex OSD feature |
| WB gains display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | |
| EV display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | |
| Qp level display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | |
| ISO display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | |
| Sensor readout resolution (preview) | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v7.6 feature |
| Window offset display | TBD | TBD | HOOK | ⬜ NOT ATTEMPTED | v7.6 feature |

---

## Frame Rate Control

| Feature | C Address | D Address | Method | Status | Notes |
|---|---|---|---|---|---|
| 18fps default | `0x1ef984` (patch: `0xF0D2`) | TBD | PATCH | ❌ BROKEN | Phase 9 — causes capture loop freeze on D. DO NOT RE-ATTEMPT without new analysis. See session note 2026-01-22. |
| FPS selector (16/18/24) | TBD | TBD | HOOK | 🚫 BLOCKED | Blocked by 18fps default fix |
| Capture timing register | Unknown | Unknown | INDEPENDENT | 🔬 INVESTIGATING | **Key unsolved problem.** D sensor likely uses different clock divider or exposure timing register. Must trace from FPS write in C firmware back through call chain, then find analogous sequence in D by function shape matching — not offset. |

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

1. 🔬 **Find OSD injection point in D** — unlocks the entire OSD feature set
2. 🔬 **Resolve FPS/capture timing freeze** — the key unsolved structural problem
3. ⬜ **Port fixed white balance** — quick win, low complexity, useful immediately
4. ⬜ **Port motor stop on encoder crash** — safety feature, relatively self-contained
5. ⬜ **Port auto stop (end-of-reel)** — useful for unattended scanning

---

## Known D-Specific Constraints

- **+0x1164 offset** is consistent across most functions but has exceptions — exceptions are where new sensor code lives
- **Function entry hooks → motor runaway** — always hook inside functions, not at entry points
- **Phase 9 (FPS) freeze** — root cause unknown; working hypothesis is different clock/timing register structure for new sensor
- **OSD code space** — in C, 0dan0 used the region `0x338f28–0x33a190` (formerly dashcam audio code). The equivalent free region in D has not been identified.
