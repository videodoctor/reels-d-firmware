# Firmware Binaries

**Do not commit firmware `.rbn` or `.bin` files to this repository.**

Firmware files are large (~10MB+) and contain proprietary Novatek/Kodak code. Store them locally.

## Where to Get Them

- **Stock Type C firmware:** Available in 0dan0's repo and TinkerDifferent forum
- **Stock Type D firmware:** [TinkerDifferent Post #143](https://tinkerdifferent.com/threads/hacking-the-kodak-reels-8mm-film-digitizer-new-thread.4885/post-43189)
- **0dan0's modded C firmware (v7.7.1):** [TinkerDifferent Post](https://tinkerdifferent.com/threads/hacking-the-kodak-reels-8mm-film-digitizer-new-thread.4885/post-43256)

## Local Storage Convention

Store your firmware files locally as:
```
FWDV280-C-stock.rbn      ← stock Type C
FWDV280-C-mod-v771.rbn   ← 0dan0 modded C v7.7.1
FWDV280-D-stock.rbn      ← stock Type D
FWDV280-D-phase8v3.rbn   ← current stable D build
```

The scripts in `/scripts/` expect these filenames by default but accept arguments.

## Flashing

Rename the target firmware to `FWDV280.BIN`, copy to root of FAT32 SD card (≤32GB), create an `NVTDELFW` folder on the card, insert into powered-off unit, power on.

**Always keep the stock D firmware on a separate SD card for recovery.**
