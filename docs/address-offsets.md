# Address Offsets — Type C → Type D

---

## The Primary Offset

A consistent **+0x1164** offset exists between most Type C and Type D function addresses.

**Example:**
```
C preview resolution hook:  0x2bf908
D preview resolution hook:  0x2c0a6c  (0x2bf908 + 0x1164 = 0x2c0a6c ✓)

C capture resolution hook:  0x2bfe74
D capture resolution hook:  0x2c0fd8  (0x2bfe74 + 0x1164 = 0x2c0fd8 ✓)
```

This offset was discovered in January 2026 by comparing Ghidra-exported symbol tables of the stock C and stock D firmwares using binary diffing scripts (see `/scripts/compare_fw.py`).

---

## How to Apply the Offset

For any known C address, **try D = C + 0x1164 first**. Then verify in Ghidra that:
1. The function at the D address has a similar shape (same argument count, similar register usage, similar adjacent calls)
2. The surrounding code context makes sense for the feature you're hooking

Do not assume the offset is correct just because the math works. Always verify in Ghidra.

---

## Known Exceptions to the Offset

These are addresses where the offset does NOT apply, indicating new or restructured code for the Type D sensor:

| Area | Notes |
|---|---|
| Capture timing / FPS registers | Phase 9 failure suggests the timing pipeline is structurally different. The FPS write in C at `0x1ef984` does NOT have a simple offset equivalent in D. |
| OSD code space | 0dan0's extension region (`0x338f28–0x33a190` in C) is repurposed dashcam audio code. The equivalent free region in D has not been located. |
| Encoder crash handler | `0x1a9ff8` in C (call to error print, rerouted to motor shutdown). D equivalent not yet mapped. |

**General rule:** If a feature worked perfectly in C but behaves wrong in D even after applying the offset, you've found an exception. Log it here.

---

## How to Find D Addresses Independently (Without Offset)

When the offset doesn't apply, use **function shape matching** in Ghidra:

1. In C firmware, find the function containing the feature you want
2. Note: number of arguments, register usage pattern, what functions it calls, what calls it
3. In D firmware, search for functions with similar shape
4. Cross-reference with known-good offset-mapped neighbors to triangulate

This is slower but necessary for the new-sensor pipeline code.

---

## Base Address & Architecture

- **Processor:** Novatek (MIPS LE 32-bit)
- **Load base address:** `0x80000000`
- **RTOS:** eCos with Novatek SDK
- **Firmware file:** `FWDV280.BIN` (rename to this for flashing)
- **Stock D binary:** Available in TinkerDifferent [Post #143](https://tinkerdifferent.com/threads/hacking-the-kodak-reels-8mm-film-digitizer-new-thread.4885/post-43189)

---

## Patching Reference

0dan0's patching approach uses `NktTool` (a 64-bit version was shared in v7.4.1 release) to handle checksums after binary modification. The Python scripts in `/scripts/` replicate this for automation.

**Critical:** Always validate the checksum after patching. A firmware file with a bad checksum will fail to flash or may brick the unit.

---

## Confirmed D Addresses (Phase 8 v3 Baseline)

| Purpose | C Address | D Address | Verified |
|---|---|---|---|
| Preview resolution calculation | `0x2bf908` | `0x2c0a6c` | ✅ Jan 2026 |
| Capture resolution calculation | `0x2bfe74` | `0x2c0fd8` | ✅ Jan 2026 |
| AE hook point 1 | `0x2b68f8` | `0x2b7a5c` | ⚠️ Partial |
| AE hook point 2 | `0x2b69fc` | `0x2b7b60` | ⚠️ Partial |
| AE hook point 3 | `0x2b6918` | `0x2b7a7c` | ⚠️ Partial |
| Phase 8 hook (motor issue if entry hook) | `0x2bfeb8` | TBD | ❌ |

---

## Hook Safety Rule (Critical)

**Function entry hooks cause the motor to continuously advance on Type D.**

Always inject hooks **inside** functions, not at their entry points. This was discovered empirically during Phase 8 development in January 2026 and is a D-specific behavior — entry hooks work fine on Type C.
