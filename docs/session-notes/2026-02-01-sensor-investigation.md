# Session Notes: 2026-02-01 — OS04D10 Sensor Investigation

**Date:** February 1, 2026  
**Participants:** videodoctor, Claude (AI assist)  
**Goal:** Identify the Type D sensor, understand the capture pipeline, determine if 1920×1440 native 4:3 capture is achievable  
**Outcome:** 🔬 Major findings — sensor identified, pipeline confirmed, native 4:3 path partially mapped but not yet achieved

---

## Key Findings

### 1. Sensor Confirmed: OmniVision OS04D10
String search in firmware binary:
```bash
xxd FWDV280-D_free.rbn | grep -i "os04"
# → CMOS_OS04D10, Init_OS04D10, ChgMode_OS04D10, GetExpoSetting_OS04D10
```

### 2. Capture Pipeline Confirmed (UART live session)
During capture, IMEP paths:
- **P1: 1728×1296, SW:1** ← actual capture path
- **P2: 656×480, SW:1** ← LCD preview only

Buffer size math confirms genuine native capture (not upscale from 656×480):
```
P1 buffer gap = 0x334200 = 3,359,232 bytes
1728 × 1296 × 1.5 (YUV) = 3,359,232 ✅ exact match
```

### 3. Sensor Max Raw Confirmed
```
ipl getcapmaxrawinfo 0
→ IPL(0) max raw width = 1936 height = 1076
```

### 4. The Vertical Upscale Problem
Stock D captures 1936×1076 from sensor → ISP upscales height 1076→1296 to produce 4:3 output. This ~20% vertical stretch is interpolated, not native. The ideal goal remains a true 4:3 sensor mode.

### 5. Full Sensor Mode Table Mapped
At `0x80DBF448`:
| Mode | Width | Height | Ratio |
|------|-------|--------|-------|
| 0-2 | 1936 | 1076 | 16:9 |
| 3-5 | 1856 | 1032 | 16:9 |
| 6   | 1792 |  996 | 16:9 |

**All modes are 16:9. No native 4:3 mode in the table.**

### 6. Direct Patch of Mode Table is Unsafe
Attempted to understand whether patching `0x80DBF448` from 1936×1076 to 1920×1440 would work. Conclusion: **No** — the sensor hardware physically outputs 1936×1076. Changing the ISP mode table without also changing the sensor register init would cause a pixel count mismatch → corrupted frames or crash.

### 7. Runtime Memory Table Found and Written
Found a secondary config table at `0x80DFE4E0` with 656 (0x290) values (the preview path dimensions). Confirmed writes to this region stick:
```
mem w 0x80dfe4ec 0x00000640  (test write, confirmed)
```
This path is for the 656×480 preview pipeline — not the primary capture path.

---

## Addresses Explored

| Address | Purpose | Result |
|---|---|---|
| `0x80DBF448` | Sensor mode table (width/height pairs) | ✅ Fully mapped, 7 modes all 16:9 |
| `0x80E07090` | ISP scaling table | ✅ Mapped — progressive width values, not sensor modes |
| `0x80D971C0` | `Init_OS04D10` function string | 🔬 Need to follow in Ghidra |
| `0x802CCBB8` | Mode config struct pointer 1 | 🔬 Not yet read — contains I2C register sequence |
| `0x802CCB20` | Mode config struct pointer 2 | 🔬 UART session ended before reading |
| `0x80DFE4E0` | Runtime preview config table | ✅ Writable, contains 656×480 (0x290) values |
| `0x80F9A7A0` | Runtime IMEP array | ✅ Confirmed — shows live path dimensions during capture |

---

## What Killed the Session

A `sensor getreg 0 0x3808` command (attempting to read OmniVision output width register) caused the UART console to hang. Had to power cycle. This type of direct sensor register read is risky — use `mem r` on the firmware's cached register tables instead.

---

## Conclusions

1. **Phase 8 v3 baseline outputs 1600×1200, but stock D already captures at 1728×1296.** The baseline should be updated to output 1728×1296 instead — it's a straightforward change and already better than what we're outputting.
2. **True native 4:3 requires activating a different sensor mode** — this means finding and modifying the I2C register init sequence for the OS04D10.
3. **The mode config structs at `0x802CCBB8` and `0x802CCB20`** are the next things to read — they should contain the actual sensor register programming sequences.

---

## Next Steps

- [ ] Update Phase 8 v3 baseline to output 1728×1296 instead of 1600×1200
- [ ] In Ghidra, follow `Init_OS04D10` at `0x80D971C0` to find I2C register tables
- [ ] Via UART (carefully): `mem r 0x802ccbb8 0x80` and `mem r 0x802ccb20 0x80`
- [ ] Search firmware for OmniVision timing registers `0x3808`, `0x380A` via Ghidra (not live UART)
- [ ] Consult OS04D10 datasheet if obtainable — OmniVision may have published it
