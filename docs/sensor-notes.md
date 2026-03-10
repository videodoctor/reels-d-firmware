# Type D Sensor Notes

The Type D variant uses a new imaging sensor compared to Types A/B/C. This is the primary source of complexity in the D port.

---

## Confirmed: OmniVision OS04D10

Identified via firmware string search (`xxd FWDV280-D.rbn | grep -i "os04"`):

```
00105de0: CMOS_OS04D10
00d971c0: Init_OS04D10
00d97130: OS04D10
00d97180: ChgMode_OS04D10
```

The **OS04D10** is an OmniVision 4MP sensor. Maximum physical resolution is approximately **2688×1520** or larger. The 1936×1076 currently in use is a cropped/binned 16:9 mode — not the sensor's full capability.

---

## What We Know

- Sensor is confirmed **OmniVision OS04D10** (4MP)
- Native sensor output in current firmware: **1936×1076 (16:9)**
- IMEP1 (capture path) output: **1728×1296 (4:3)** — the ISP is upscaling the height from 1076→1296 (~20% vertical stretch)
- IMEP2 (preview/LCD path): **656×480**
- The 1936×1076 is a cropped/binned mode, not the sensor's native maximum
- Sensor change is the reason the +0x1164 offset breaks down in certain pipeline areas
- The Type D unit was first shipped around late 2024/early 2025 (serial numbers starting `H2825148BKxxxxx`)

## What We Don't Know Yet

- Whether the OS04D10 has a native 4:3 mode (e.g. 2048×1536 or similar) that could be activated
- Exact sensor register map for mode switching (I2C register tables)
- Whether the frame buffer geometry can accommodate a larger native resolution
- Where the equivalent free code space exists for injecting extensions (the `0x338f28–0x33a190` region used in C was formerly dashcam audio code)

---

## Sensor Mode Table (Confirmed via UART + Ghidra — Feb 2026)

Found at `0x80DBF448` in firmware (confirmed via `mem r` during live UART session):

```
80DBF440 : 802CCBB8  ← Pointer to mode config struct
80DBF444 : 802CCB20  ← Pointer to mode config struct
80DBF448 : 00000790  ← 1936 (Mode 0 width)
80DBF44C : 00000434  ← 1076 (Mode 0 height)
80DBF450 : 00000790  ← 1936 (Mode 1 width)
80DBF454 : 00000434  ← 1076 (Mode 1 height)
80DBF458 : 00000790  ← 1936 (Mode 2 width)
80DBF45C : 00000434  ← 1076 (Mode 2 height)
80DBF460 : 00000740  ← 1856 (Mode 3 width)
80DBF464 : 00000408  ← 1032 (Mode 3 height)
80DBF468 : 00000740  ← 1856 (Mode 4 width)
80DBF46C : 00000408  ← 1032 (Mode 4 height)
80DBF470 : 00000740  ← 1856 (Mode 5 width)
80DBF474 : 00000408  ← 1032 (Mode 5 height)
80DBF478 : 00000700  ← 1792 (Mode 6 width)
80DBF47C : 000003E4  ←  996 (Mode 6 height)
```

All modes are 16:9. No native 4:3 mode exists in the current mode table.

Also found a secondary resolution table at `0x80E07090` (likely ISP scaling table):
```
80E07090: 070E 0739 0764 0790 07BC 07E9 0816 0844
          1806 1849 1892 1936 1980 2025 2070 2116
```
This is a progressive width scaling table, not sensor modes.

### Runtime IMEP path confirmed during capture (UART):
- **P1 (capture): 1728×1296, SW:1** ← active during capture
- **P2 (preview): 656×480, SW:1** ← LCD only

### Buffer size math confirms native capture (not upscaled):
- P1 buffer gap: `0xa2fafbb0 - 0xa2c7b9b0 = 0x334200 = 3,359,232 bytes`
- Expected for 1728×1296 YUV: `1728 × 1296 × 1.5 = 3,359,232` ✅ exact match
- **Conclusion: Type D is genuinely capturing at 1728×1296, not upscaling from 656×480**

### Why 1728×1296 is still suboptimal:
The sensor outputs 1936×1076 (16:9). The ISP converts this to 1728×1296 (4:3) by:
- Cropping width: 1936→1728
- **Upscaling height: 1076→1296 (~20% vertical stretch)**

The vertical stretch means the 4:3 output is not truly native — it's interpolated. The ideal would be a native 4:3 sensor mode.

---

## Hypotheses Under Investigation

### Native 4:3 Sensor Mode (Key Quality Goal)

**Goal:** Get a true native 4:3 capture from the OS04D10 without ISP vertical upscaling.

**Options explored:**
1. **Patch mode table to 1920×1440** — risky. The sensor hardware outputs 1936×1076. Telling the ISP to expect 1920×1440 causes a pixel count mismatch and likely crashes/garbage frames.
2. **Native 4:3 sensor mode** — the OS04D10 is a 4MP sensor with a pixel array likely around 2688×1520. It may support a native 4:3 mode (e.g. 2048×1536) via different I2C register init. This is the right approach but requires the sensor datasheet or reverse engineering the I2C init sequence.
3. **Accept 1728×1296** — already significantly better than modded C firmware (1600×1200). The 20% vertical stretch may be acceptable for practical use.

**Next steps:**
- Follow the `Init_OS04D10` function at `0x80D971C0` in Ghidra to find the I2C register init tables
- Search firmware for OmniVision timing registers (`0x3808`, `0x380A`, `0x380C`, `0x380E`)
- Check the two mode config struct pointers at `0x802CCBB8` and `0x802CCB20` — these likely contain the full sensor register sequences for each mode
- Try `mem r 0x802ccbb8 0x80` and `mem r 0x802ccb20 0x80` via UART to read the register tables

**Key blocker:** We got cut off during the UART session when a sensor register read command hung the console. Need to revisit with caution — use `Ctrl+C` quickly if a `sensor getreg` command doesn't return.

### FPS/Capture Timing Freeze (Phase 9 Problem)

**Symptom:** Patching the FPS value at the offset-equivalent of C's `0x1ef984` causes the capture loop to freeze on D.

**Hypothesis:** The new sensor uses a different clock divider register or a different sequence of timing register writes to set frame rate. In C, a single patch to `0x1ef984` (values: `0x60EA` for 20fps, `0xF0D2` for 18fps) was sufficient. In D, there may be additional registers that need to be updated in concert, or the timing value format changed.

**Approach to resolve:** In Ghidra on the C firmware, trace backward from `0x1ef984` to understand the full call chain and all register writes involved in setting FPS. Then find the analogous sequence in D by function shape matching rather than offset.

### OSD Code Space

**Hypothesis:** The region used for 0dan0's C extensions (`0x338f28–0x33a190`) corresponds to dashcam audio code that was vestigial in the C firmware. The D firmware may have removed, replaced, or reorganized this code, meaning we can't assume the same region is free.

**Approach to resolve:** In Ghidra on the D firmware, examine what lives at `0x338f28 + 0x1164 = 0x33a08c`. If it's not free space, sweep the D firmware for large NOP blocks or unused regions.

---

## Useful UART Notes

UART debugging was used during January 2026 work. The bootloader is intact on units that survive a bad flash, enabling serial recovery. Key:
- Hardware recovery via UART is possible if bootloader survives
- Boot log output on UART is useful for diagnosing capture pipeline differences
- If doing new sensor analysis, capturing UART output during a normal capture sequence (C vs D side by side if possible) might reveal register-level differences
