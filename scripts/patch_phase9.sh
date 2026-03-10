#!/bin/bash
# Kodak Reels Type D - Resolution and Framerate Patch Script

echo "========================================================"
echo "  Kodak Reels Firmware D Patches :: 1600x1200 @ 18 fps"
echo "========================================================"
echo ""

SOURCE="${1:-FWDV280-D_0dan0.rbn}"
OUTPUT="FWDV280-D-phase9.rbn"

echo "Source: $SOURCE"
echo "Output: $OUTPUT"
echo ""

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: Source file not found: $SOURCE"
    exit 1
fi

cp "$SOURCE" "$OUTPUT"

echo "Applying patches..."

# ============================================
# DEVICE TYPE AND NVM ADDRESS (at 0x340000)
# ============================================

# Device type = 4 (Type D)
printf '\x04\x00\x00\x00' | dd of="$OUTPUT" bs=1 seek=$((0x340000)) conv=notrunc 2>/dev/null

# NVM base address = 0x80E0ADA4
printf '\xa4\xad\xe0\x80' | dd of="$OUTPUT" bs=1 seek=$((0x340004)) conv=notrunc 2>/dev/null

# ============================================
# NOP OUT PRINTF (0dan0's first code change)
# ============================================
printf '\x00\x00\x00\x00' | dd of="$OUTPUT" bs=1 seek=$((0x1d430)) conv=notrunc 2>/dev/null

# ============================================
# RESOLUTION PATCHES (1600x1200)
# ============================================
printf '\x40\x06' | dd of="$OUTPUT" bs=1 seek=$((0x1c5c48)) conv=notrunc 2>/dev/null
printf '\xb0\x04' | dd of="$OUTPUT" bs=1 seek=$((0x1c5c50)) conv=notrunc 2>/dev/null
printf '\x40\x06' | dd of="$OUTPUT" bs=1 seek=$((0x1c5cac)) conv=notrunc 2>/dev/null
printf '\xb0\x04' | dd of="$OUTPUT" bs=1 seek=$((0x1c5cb4)) conv=notrunc 2>/dev/null
printf '\x40\x06' | dd of="$OUTPUT" bs=1 seek=$((0x1c7170)) conv=notrunc 2>/dev/null
printf '\xb0\x04' | dd of="$OUTPUT" bs=1 seek=$((0x1c7178)) conv=notrunc 2>/dev/null

# ============================================
# FRAMERATE PATCH (18fps)
# ============================================
printf '\x12' | dd of="$OUTPUT" bs=1 seek=$((0x1015e8)) conv=notrunc 2>/dev/null

# ============================================
# VERIFICATION
# ============================================
echo ""
echo "Verifying patches..."
echo ""

echo "Device type and NVM (04000000 = Type D, a4ade080 = NVM addr):"
echo -n "  0x340000: "; xxd -s $((0x340000)) -l 8 "$OUTPUT" | cut -d: -f2 | cut -c1-20

echo ""
echo "NOP printf (should show 0000 0000):"
echo -n "  0x1d430:  "; xxd -s $((0x1d430)) -l 4 "$OUTPUT" | cut -d: -f2 | cut -c1-10

echo ""
echo "Resolution (4006=width, b004=height):"
echo -n "  0x1c5c48: "; xxd -s $((0x1c5c48)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5
echo -n "  0x1c5c50: "; xxd -s $((0x1c5c50)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5
echo -n "  0x1c5cac: "; xxd -s $((0x1c5cac)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5
echo -n "  0x1c5cb4: "; xxd -s $((0x1c5cb4)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5
echo -n "  0x1c7170: "; xxd -s $((0x1c7170)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5
echo -n "  0x1c7178: "; xxd -s $((0x1c7178)) -l 2 "$OUTPUT" | cut -d: -f2 | cut -c1-5

echo ""
echo "Framerate (12 = 18fps):"
echo -n "  0x1015e8: "; xxd -s $((0x1015e8)) -l 1 "$OUTPUT" | cut -d: -f2 | cut -c1-3

echo ""
echo "Done! Output: $OUTPUT"
echo "Run build_local.bat to create final firmware package."
