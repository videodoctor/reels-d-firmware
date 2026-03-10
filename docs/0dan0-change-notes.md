# 0dan0 Change Notes — Type A/B/C Firmware Reference

> **Source:** 0dan0's working notes, lightly edited for clarity and organization.  
> **Scope:** These notes cover Type A, B, and C firmware. They are the primary reference  
> for understanding what needs to be ported to Type D.  
> **Format:** Addresses listed as `A/B/C` where variants differ, or a single address where shared.  
> Virtual addresses assume base `0x80000000`; file offsets are as written.

---

## Boot & Shutdown Images

| Address (A/B/C) | Purpose |
|---|---|
| `0x1079ec` / `0x1079fc` / `0x1079fc` | Pointer to shutdown JPG — now points to first image, freeing code space |
| `0x107afc` / `0x107afc` / `0x107b0c` | Pointer to developer info JPG |
| `0x124af0` / `0x124af0` / `0x124b00` | Size of boot JPG |
| `0x124b10` / `0x124b10` / `0x124b20` | Size of shutdown JPG |
| `0x333f28–0x3376c0` | Replaced boot JPG image (Type C) |
| `0x3376c8–0x33ae70` | Replaced shutdown JPG image (Type C) |

**FW 5.7 note:** The D9 JPG at `0x107b0c` was shrunk from 118KB to 37KB to create additional code space.

---

## Folder / Version Naming

| Address | Change |
|---|---|
| `0x3301c4` and `0xdb12b7` | Folder name changed from `"Filescanner"` to `"Filescan5.5"` — used to track firmware versions by scanning output folder name |

---

## Printf / Console Suppression

### Core Printf NOP
| Address (A/B/C) | Notes |
|---|---|
| `0x1d430` | First change — NOPs a noisy print call |
| `0x1d438` / `0x1dc20` | `"^RERR:%s() Horizontal Scaling down ratio over 2!"` |
| `0x1d450` / `0x1dc38` | `"^RERR:%s() Vertical Scaling down ratio over 2!"` |

### Suppressed Error Messages (NOP the branch/call)
| Address | Message Suppressed |
|---|---|
| `0x239934` | `"ERR:GxImg_MapToISEScaleMethod()"` |
| `0x239980` | `"WRN:GxImg_MapToISEScaleMethod() Not Support"` |
| `0x24c710` / `0x24b728` / `0x24b83c` / `0x24ce50` | `"^RERR:%s() setFolderPath id error %d!"` |
| `0x24c940` / `0x278598` | `"^RERR:%s() IPL_SetDZoom fail (Current Mode = %d)"` |
| `0x278568` | `"^RERR:%s() IPL_SetDZoom fail (cur:%d max:%d)"` |
| `0x22a840` | `"^RERR:%s() This Handle is not created(%d)"` |
| `0x1c6c0c` | `"^RERR:%s() wnd not created"` |
| `0x2c7ce8` | `"^RERR:%s() SIEclk = %d"` |
| `0x30156c` | `"^RERR:%s() ChgMode_AR0330 to %d..."` |
| `0x301a34` | `"^RERR:%s() Chip version is 0x%04x"` |
| `0x2fcb6c` | `"ERR:ramdsk_setParam() No Implement! uiEvt 1"` |
| `0x0eee64` | `"ERR:System_OnStrgInit_FWS() Init failed!"` |
| `0x276198` | `"^RERR:%s() -E- Cmd fail %d"` |
| `0x301b38` | `"ERR:Init_AR0330() ^GOTPM v5"` |
| `0x2eb66c` | `"^RERR:%s() PLL6 selected but not enabled..."` |
| `0x2b99a4` | `"^RERR:%s() ^G3DNR on.."` |
| `0x2b8fd4` | `"^RERR:%s() ^GIPL_FCB_AlgWDR = %d.."` |
| `0x2b966c` | `"^RERR:%s() ^GWDR ON.."` |
| `0x2b9644` | `"^RERR:%s() ^GWDR OFF.."` |
| `0x02ec84` / `0x2ec10` / `0x2f2f4` | `"^RERR:%s() pwm_pwmEnable(), not opened yet!"` |
| `0x02b4e94` | `"^RERR:%s() #Entered AF_Tsk"` |
| `0x26e3a4` | Zeroed — suppresses per-frame "3DNR is disabled" message (FW 5.7) |
| `0x2be8cc` | `"CA VIG Setting not ready"` — lens shading error from changed FOV/lens; harmless |
| `0x2b99a4` | 3DNR-on message |

---

## Frame Rate (FW 5.2+)

| Address (A/B/C) | Notes |
|---|---|
| `0x1ef984`–`0x1ef986` / `0x1ef974`–`0x1ef976` (B) | Sets 18fps vs. stock 20fps. Sample rate 54000 (18fps) vs. 60000 (20fps). This is a **16-bit value** — 18fps=`0xD2F0`, 20fps=`0xEA60`. 24fps requires a 32-bit write for 72000. |
| `0x1ef440` | Pointer to new `avcC` blob |
| `0x1efc1c` | Pointer to new `avcC` blob |

---

## Resolution — Preview & Capture (FW 5.0+)

### Preview Resolution Hook
**Address:** `0x2bf908`–`0x2bf9a84`  
A function call is removed and replaced with a jump to custom code at `0x1fb6b0` (`New Preview Res`), which computes the frame size for the large FOV and prints size changes.

**Resolution math:**
```
new_width  = (old_width - 440) * 4
new_height = ((new_width/2 + new_width/4) >> 2) << 2   // 3/4 of width, divisible by 4
new_x_offset = abs(old_x_offset + old_width/2 - new_width/2)
new_y_offset = abs(old_y_offset + old_height/2 - new_height/2)
```

**Example values:**
```
corner: 902, 472  (initial)   →   size: 840, 632
corner: 522, 188  (output)    →   size: 1600, 1200
```

### Capture Resolution Hook
**Address:** `0x2bfe74`–`0x2bfe98`  
Replaces error message `"ERR:%s() error act size (%d %d) < crop Size(%d %d)"` with a jump to `0x1fbf10` (`New Capture Res`). Uses same math as preview but without printout. Code lives between `0x1fbf10` and `0x1fc000`.

### Related — Bayer Phase Fix
**Address:** `0x2a173c`–`0x2a1758`  
Mutes `"CFA need to be R"` (Bayer phase wrong, bizarre colors). Prevents jump to offset calculation and directly sets `$v0 = 0x200`. Reason unknown but required for correct color.

### Related — Conversion Check
**Address:** `0x2bf928`  
Removed a function call to `0x27aee4` and set return `$v0 = 0x0`. Would have printed `"convert 2 sen id fail"`. May now be unnecessary but is harmless.

---

## 3DNR Disable (FW 5.7)

**Address:** `0x26dffc`–`0x26e003`  
Disables 3DNR (multi-frame noise reduction). Also adds a frames-encoded counter at `0x85bf0014`.

---

## White Balance — Fixed/Manual (FW 5.0+)

**Address (A/B/C):** `0x2b7e20` / `0x2b7e20` / `0x2b7e30`  
Replaces auto white balance with hardcoded RGB gains (mode 2 instead of mode 1).

| Address (C) | Channel | Default Value |
|---|---|---|
| `0x2b7e34` | Red | `0x1c0` (448) |
| `0x2b7e38` | Green | `0x100` (256) |
| `0x2b7e3c` | Blue | `0x100` (256) |

---

## Auto Exposure (FW 5.7+)

**Hook addresses:** `0x2b68f8`, `0x2b69fc`, `0x2b6918`  
Hooks the existing Auto Exposure code, jumping to custom AE functions.

**ISO/Exposure range (Type C):**
| Address | Setting | Range |
|---|---|---|
| `0x80e556b4` | ISO | 50–1600 (`0x32`–`0x640`) |
| `0x80e556b8` | Exposure time | 230µs–32767µs (`0xe5`–`0x7fff`) |

**ISO/Exposure range (Type A):**
| Address | Setting |
|---|---|
| `0x80e56134` | ISO 50–1600 |
| `0x80e56138` | Exposure time |

**ISO/Exposure range (Type B):**
| Address | Setting |
|---|---|
| `0x80e56224` | ISO 50–1600 |
| `0x80e56228` | Exposure time |

---

## Rate / Bitrate Control (FW 5.2+)

| Address | Change |
|---|---|
| `0x1b804c` | Was a jump to `0x1b3bbc`; now a hooked call to `0x1fc420` (rate control part 2), which still calls `0x1b3bbc` |
| `0x1b813c` | Was `"[%d]stillBlock = %d"` warning; now calls `0x1fc350` (rate control part 1) |
| `0x23fe00` | Was a call to `0x241be4`; now a hooked call to `0x1fc280` (sets and prints initial Qp value), which still calls `0x241be4` |

---

## Motor Stop on Encoder Crash (FW 5.4+)

**Address:** `0x1a9fe8` / `0x1a9fe8` / `0x1a9ff8`  
Was a call to print `"set 1sok to end file.."` on encoder crash. Now calls custom shutdown code at `0x33a340` (crude version) or uses the cleaner motor-stop approach below.

**Crude shutdown (original):** Sends `0xFF` to `0xb0260000`–`0xb0267fff` — freaks the unit out enough to stop motors.

**Cleaner motor stop:** Write a value greater than `0x2b` to:
- Type A: `0x80ddc12c`
- Type B: `0x80ddc214`
- Type C: `0x80ddb6ac`

**Stop callback hook:**  
`0x1a9df8` / `0x1a9df8` / `0x1a9e08` — hooks `"Stop callback"` printf to a custom stop handler.

**FW 5.9:** Motor stop on encoder crash — hook code at `0x33a350`.

---

## Input Buffer Hooks

**Hook 1:**  
`0x13a2e0` / `0x13a2e0` / `0x13a2f0` — hooks a function call to `0x013b450/50/60` that sets up the input buffer address. Hook code at `0x339420`.

**Hook 2:**  
`0x2eab6c` — hooks a function call to `0x2ea95c` (input buffer address setup). Hook code between `0x1fc0f0`–`0x1fc190`.

**Hook 3:**  
`0x2eae08` — hooks another call to `0x2ea95c`. Hook code between `0x1fc040`–`0x1fc1b0`.

---

## avcC Full-Range Fix (FW 5.8)

The camera normally gets `avcC` data from the compression engine but generates it incorrectly. A correct blob (generated by ffmpeg) is placed at firmware offset `0x33A440`.

**Changed addresses:**
| Address | Change |
|---|---|
| `0x1ec104` | Points to new `avcC` at `0x33A440` instead of `0x80e55854` |
| `0x1ef458`, `0x1ef464` | Updated pointer |
| `0x1efc2c`, `0x1efc38` | Updated pointer |

---

## In-Memory Variables (Created by 0dan0)

All at base `0x85bf0000`:

| Address | Contents |
|---|---|
| `0x85bf0000` | Approximate seconds of encoding |
| `0x85bf0004` | Number of solid grey frames detected |
| `0x85bf0008` | Current max luma |
| `0x85bf000c` | Current min luma |
| `0x85bf0010` | Time of last exposure change |
| `0x85bf0014` | Number of frames encoded |
| `0x85bf0018` | Exposure gap frames |
| `0x85bf001c` | Current Qp |
| `0x85bf0020` | RGB gain — Red |
| `0x85bf0024` | RGB gain — Green |
| `0x85bf0028` | RGB gain — Blue |
| `0x85bf002c` | Button read |
| `0x85bf0030` | Width |
| `0x85bf0034` | Height |

---

## In-Memory Variables (Discovered)

| Address | Contents |
|---|---|
| `0x80f82158` | Luma (Y) average, 0–0xfff |
| `0x80f8214c` | Possibly frame counter at 25Hz (frames since boot) |
| `0x80deb17c` | Possibly last luma average, 0–0xfff |
| `0xa56f1f60` | Current Qp level for H264 encoder |
| `0x80DFC54C` (C) | Processing resolution |
| `0x80DFD0BC` (B) | Processing resolution |

---

## Non-Volatile Memory (NVM) Addresses

### Active Settings (RAM)
| Type | Exposure | Sharpness | Tint |
|---|---|---|---|
| A | `0x80DDC11C` | `0x80DDC120` | `0x80DDC124` |
| B | `0x80DDC204` | `0x80DDC208` | `0x80DDC20C` |
| C | `0x80DDB69C` | `0x80DDC2A0` | `0x80DDC2A4` |

Values: 1–8 mapped to +2.0 thru -2.0 EV.

### Non-Volatile (Persistent) Settings
| Type | Exposure | Sharpness | Tint | Free NVM Region |
|---|---|---|---|---|
| A | `0x80E0B87C` | `0x80E0B790` | `0x80E0B794` | `0x80E0B7A0`+ |
| B | `0x80E0B87C` | `0x80E0B880` | `0x80E0B884` | `0x80E0B890`–`0x80E0B8fc` |
| C | `0x80E0AD0C` | `0x80E0AD10` | `0x80E0AD14` | `0x80E0AD20`–`0x80E0AD8C` |

---

## Button Mapping

| Button | Value |
|---|---|
| Up | `0x1` |
| Down | `0x2` |
| Left | `0x4` |
| Right | `0x8` |
| Plus | `0x200` |
| Minus | `0x100` |
| Back | `0x20` |
| OK | `0x800` |

**Button read addresses:**
- Type A: `0x80E8BFF8`
- Type B: `0x80E8C0E8`
- Type C: `0x80E8B578`

---

## Saturation / Tint

**Address:** `0x32cec8`  
Tint -2 sets saturation. Values:
- `0xffffff80` = 0% (full desaturation / B&W)
- `0x0` = 100% (normal)
- `0x58` = ~150% (boosted)

---

## Menu Stride Values (UI Layout)

| Stride | Element |
|---|---|
| 76 | Settings logos |
| 180 | Sharpness (pg 11), Exposure |
| 196 | Film Positive |
| 212 | Film strip image in menu, Playback + play symbol |
| 220 | Frame Adjust |
| 236 | Negative Film |

---

## RTC / Date-Time Functions (FW 6.5)

```
SetTime(Hour, Minute, Second, ??):  FUN_000692d4
SetDate(Year, Month, Day, ??):      FUN_000693a0
get_DateTime():                     FUN_00068d04(&local_10)  (probable)
```

**UART usage:**
```
smrec gt          → get time: "time = 2022/1/1 12:1:47"
smrec st 2025/7/12 13:24:24   → set time
```

---

## Audio LUT Addresses

| Type | Address |
|---|---|
| B | `0xdfbdb0` |
| C | `0xdfb240` |

---

## String Table

**Address:** `0xdbd910`–`0xdbd990`  
All strings used for formatting OSD/debug messages.

---

## Open Questions (from 0dan0's notes)

- `Is FUN_0011a5d8() Stop?` — unresolved function identification
- `0x2bf928` change (remove `0x27aee4` call, set `$v0=0x0`) — may now be unnecessary, listed as harmless
- `0x2a173c`–`0x2a1758` Bayer phase fix — works but reason unknown
