# Type D Sensor Notes

The Type D variant uses a new imaging sensor compared to Types A/B/C. This is the primary source of complexity in the D port.

---

## What We Know

- The sensor change is the reason even a well-established offset like +0x1164 breaks down in certain pipeline areas
- The capture timing / FPS control pipeline appears structurally different — the clock divider or exposure timing register layout likely changed with the new sensor
- The Type D unit was first shipped around late 2024/early 2025 (serial numbers starting `H2825148BKxxxxx`)

## What We Don't Know Yet

- Which specific sensor vendor/model is used in Type D
- Exact register map differences vs. Type C sensor
- Whether the frame buffer geometry changed (relevant to OSD injection and memory layout)
- Where the equivalent free code space exists for injecting extensions (the `0x338f28–0x33a190` region used in C was formerly dashcam audio code)

---

## Hypotheses Under Investigation

### FPS/Capture Timing Freeze (Phase 9 Problem)

**Symptom:** Patching the FPS value at the offset-equivalent of C's `0x1ef984` causes the capture loop to freeze on D.

**Hypothesis:** The new sensor uses a different clock divider register or a different sequence of timing register writes to set frame rate. In C, a single patch to `0x1ef984` (values: `0x60EA` for 20fps, `0xF0D2` for 18fps) was sufficient. In D, there may be additional registers that need to be updated in concert, or the timing value format changed.

**Approach to resolve:** In Ghidra on the C firmware, trace backward from `0x1ef984` to understand the full call chain and all register writes involved in setting FPS. Then find the analogous sequence in D by function shape matching rather than offset. Look for the same pattern of register writes in the same relative order.

### OSD Code Space

**Hypothesis:** The region used for 0dan0's C extensions (`0x338f28–0x33a190`) corresponds to dashcam audio code that was vestigial in the C firmware. The D firmware may have removed, replaced, or reorganized this code, meaning we can't assume the same region is free.

**Approach to resolve:** In Ghidra on the D firmware, examine what lives at `0x338f28 + 0x1164 = 0x33a08c`. If it's not free space, do a sweep of the D firmware looking for large blocks of NOPs or unused code regions that can be repurposed.

---

## Useful UART Notes

UART debugging was used during January 2026 work. The bootloader is intact on units that survive a bad flash, enabling serial recovery. Key:
- Hardware recovery via UART is possible if bootloader survives
- Boot log output on UART is useful for diagnosing capture pipeline differences
- If doing new sensor analysis, capturing UART output during a normal capture sequence (C vs D side by side if possible) might reveal register-level differences
