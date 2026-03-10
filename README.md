# Kodak Reels 8mm Film Scanner — Type D Firmware Mod

Community effort to port [0dan0's custom firmware](https://github.com/0dan0/4reels) to the **Type D** variant of the Kodak Reels Super 8 / Regular 8mm film scanner.

> **Current stable D baseline:** Phase 8 v3 — 1600×1200 @ 18fps working  
> **Status:** Active development. Phase 9 (FPS/rate control) causes capture loop freeze. Under investigation.

---

## Background

The Kodak Reels scanner ships in at least four hardware variants (A, B, C, D). 0dan0 has led firmware modification efforts for Types A, B, and C, achieving significant quality improvements over stock firmware. The **Type D variant** introduced a new imaging sensor, making it a substantially more complex port than previous variants. This repo tracks the Type D porting effort.

**Key community resources:**
- [TinkerDifferent forum thread](https://tinkerdifferent.com/threads/hacking-the-kodak-reels-8mm-film-digitizer-new-thread.4885/)
- [0dan0's firmware repo](https://github.com/0dan0/4reels)
- [User guide & feature reference](https://tinkerdifferent.com/resources/user-guide-and-reference-to-0dan0s-custom-firmware-for-the-reels-8mm-film-digitizer.165/)

**Identifying a Type D unit:** Serial numbers beginning with or similar to `H2825148BKxxxxx`

---

## Repo Structure

```
/docs/
  feature-map.md         ← Master feature port tracking table (start here)
  address-offsets.md     ← Offset methodology, exceptions, D-specific addresses
  sensor-notes.md        ← Notes specific to the new D imaging sensor
  session-notes/         ← Dated session logs (what we tried, what happened)

/scripts/
  compare_fw.py          ← Binary comparison / offset detection script
  find_hooks.py          ← Hook candidate finder
  patch_fw.py            ← Firmware patching utility
  validate_checksum.py   ← Checksum validation after patching

/firmware/
  README.md              ← Instructions — do NOT commit firmware binaries to git
                            (too large; store locally or link to forum post)
```

---

## Quick Start for Contributors

1. You need: Ghidra, Python 3, the stock Type C firmware (`FWDV280-C.rbn`) and stock Type D firmware (`FWDV280-D.rbn`). Stock D firmware is available in [Post #143](https://tinkerdifferent.com/threads/hacking-the-kodak-reels-8mm-film-digitizer-new-thread.4885/post-43189) of the forum thread.
2. Read `docs/address-offsets.md` to understand the C→D offset methodology before doing anything else.
3. Check `docs/feature-map.md` for current port status before exploring any address — don't re-explore ruled-out paths.
4. Log your session in `docs/session-notes/YYYY-MM-DD-description.md` even if nothing worked. Failed attempts are valuable.

---

## Architecture Overview (MIPS 32LE)

The firmware runs on a **Novatek processor (MIPS LE 32-bit)**, loaded at base address `0x80000000`. The firmware is a modified eCos RTOS build with Novatek SDK extensions.

Key architectural notes for D variant:
- New imaging sensor vs. Type C — pipeline register layout differs
- Consistent **+0x1164 offset** found between most C and D addresses
- **Exceptions to the offset exist** — these are where the new sensor code lives and require independent analysis
- Function entry hooks cause motor runaway on D; **internal function hooks are safer**

---

## Contributors

- **0dan0** — original firmware mod author (Types A, B, C); see his [GitHub](https://github.com/0dan0/4reels)
- **videodoctor** — Type D port lead; first working D-variant firmware modification (1600×1200 @ 18fps)

---

## Status Warning

⚠️ **Type D firmware is experimental.** Flashing incorrect or unstable firmware can render the unit non-functional. Always keep the stock D firmware binary on hand for recovery. Hardware recovery via UART is possible if the bootloader is intact.
