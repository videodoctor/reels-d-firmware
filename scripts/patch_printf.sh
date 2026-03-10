#!/bin/bash
# patch_printf.sh - Builds, extracts, patches, and injects custom code into firmware

echo "========================================================"
echo "  Kodak Reels Type D :: Custom Code Patcher & Injector"
echo "========================================================"
echo ""

FIRMWARE="FWDV280-D-phase9.rbn"
MANWB_OFFSET=$((0x338f28))

if [ ! -f "$FIRMWARE" ]; then
    echo "ERROR: $FIRMWARE not found!"
    echo "Run ./patch_phase9.sh first to create base firmware."
    exit 1
fi

# Build custom code
echo "Building custom code..."
make clean 2>/dev/null
make
if [ $? -ne 0 ]; then
    echo "ERROR: make failed!"
    exit 1
fi
echo ""

# Process manwb
if [ -f "manwb/manwb.bin" ]; then
    echo "Processing manwb/manwb.bin..."
    
    # Extract raw binary using objcopy
    mipsel-linux-gnu-objcopy -O binary manwb/manwb.bin manwb/manwb_objcopy.bin
    
    cut_offset=$(grep -oba "CUT HERE" manwb/manwb_objcopy.bin | cut -d: -f1)
    if [ -z "$cut_offset" ]; then
        echo "  ERROR: CUT HERE marker not found!"
        exit 1
    fi
    
    skip=$((cut_offset + 12))
    echo "  Found CUT HERE at offset $cut_offset, skipping $skip bytes"
    dd if=manwb/manwb_objcopy.bin of=manwb/manwb_raw.bin bs=1 skip=$skip 2>/dev/null
    
    count=0
    for offset in $(grep -oba $'\x58\x00\x02\x0c' manwb/manwb_raw.bin 2>/dev/null | cut -d: -f1); do
        printf '\x18\x03\x02\x0c' | dd of=manwb/manwb_raw.bin bs=1 seek=$offset conv=notrunc 2>/dev/null
        echo "  Patched printf at offset $offset"
        ((count++))
    done
    echo "  manwb: $count printf calls patched"
    
    # NOP out any syscalls
    for offset in $(grep -oba $'\x0c\x38\x00\x00' manwb/manwb_raw.bin 2>/dev/null | cut -d: -f1); do
        printf '\x00\x00\x00\x00' | dd of=manwb/manwb_raw.bin bs=1 seek=$offset conv=notrunc 2>/dev/null
        echo "  NOPed syscall at offset $offset"
    done
    
    manwb_size=$(stat -c%s manwb/manwb_raw.bin)
    echo "  manwb size: $manwb_size bytes"
    
    # Inject manwb
    dd if=manwb/manwb_raw.bin of="$FIRMWARE" bs=1 seek=$MANWB_OFFSET conv=notrunc 2>/dev/null
    printf "  Injected at 0x%x\n" $MANWB_OFFSET
    echo ""
else
    echo "WARNING: manwb/manwb.bin not found, skipping"
    manwb_size=0
fi

# Calculate hist offset
HIST_OFFSET=$((MANWB_OFFSET + manwb_size))

# Process hist
if [ -f "hist/hist.bin" ]; then
    echo "Processing hist/hist.bin..."
    
    # Extract raw binary using objcopy
    mipsel-linux-gnu-objcopy -O binary hist/hist.bin hist/hist_objcopy.bin
    
    cut_offset=$(grep -oba "CUT HERE" hist/hist_objcopy.bin | cut -d: -f1)
    if [ -z "$cut_offset" ]; then
        echo "  ERROR: CUT HERE marker not found!"
        exit 1
    fi
    
    skip=$((cut_offset + 12))
    echo "  Found CUT HERE at offset $cut_offset, skipping $skip bytes"
    dd if=hist/hist_objcopy.bin of=hist/hist_raw.bin bs=1 skip=$skip 2>/dev/null
    
    count=0
    for offset in $(grep -oba $'\x58\x00\x02\x0c' hist/hist_raw.bin 2>/dev/null | cut -d: -f1); do
        printf '\x18\x03\x02\x0c' | dd of=hist/hist_raw.bin bs=1 seek=$offset conv=notrunc 2>/dev/null
        echo "  Patched printf at offset $offset"
        ((count++))
    done
    echo "  hist: $count printf calls patched"
    
    # NOP out any syscalls
    for offset in $(grep -oba $'\x0c\x38\x00\x00' hist/hist_raw.bin 2>/dev/null | cut -d: -f1); do
        printf '\x00\x00\x00\x00' | dd of=hist/hist_raw.bin bs=1 seek=$offset conv=notrunc 2>/dev/null
        echo "  NOPed syscall at offset $offset"
    done
    
    hist_size=$(stat -c%s hist/hist_raw.bin)
    echo "  hist size: $hist_size bytes"
    
    # Inject hist
    dd if=hist/hist_raw.bin of="$FIRMWARE" bs=1 seek=$HIST_OFFSET conv=notrunc 2>/dev/null
    printf "  Injected at 0x%x\n" $HIST_OFFSET
    echo ""
else
    echo "WARNING: hist/hist.bin not found, skipping"
    HIST_OFFSET=0
fi

# Install hooks
echo "Installing hooks..."

# Calculate JAL for hist entry point (0x80000000 + HIST_OFFSET)
HIST_ENTRY=$((0x80000000 + HIST_OFFSET))
HIST_JAL=$(((HIST_ENTRY >> 2) & 0x03FFFFFF | 0x0C000000))

# AE hook at 0x2b6cec -> hist
#AE_HOOK_OFFSET=$((0x2b6cec))
AE_HOOK_OFFSET=$((0x2b6a60)) # Replace  MODULUS code
#AE_HOOK_OFFSET=$((0x2b6a38))  # Earlier hook, before modulo 3 check
printf "  AE hook at 0x%x -> 0x%x\n" $AE_HOOK_OFFSET $HIST_ENTRY

# Convert JAL to little-endian bytes
byte0=$(printf '\\x%02x' $((HIST_JAL & 0xFF)))
byte1=$(printf '\\x%02x' $(((HIST_JAL >> 8) & 0xFF)))
byte2=$(printf '\\x%02x' $(((HIST_JAL >> 16) & 0xFF)))
byte3=$(printf '\\x%02x' $(((HIST_JAL >> 24) & 0xFF)))

printf "${byte0}${byte1}${byte2}${byte3}" | dd of="$FIRMWARE" bs=1 seek=$AE_HOOK_OFFSET conv=notrunc 2>/dev/null

# WB hook at 0x2b7e14 -> manwb (0x80338f28)
MANWB_ENTRY=$((0x80000000 + MANWB_OFFSET))
MANWB_JAL=$(((MANWB_ENTRY >> 2) & 0x03FFFFFF | 0x0C000000))
WB_HOOK_OFFSET=$((0x2b7e14))
printf "  WB hook at 0x%x -> 0x%x\n" $WB_HOOK_OFFSET $MANWB_ENTRY

byte0=$(printf '\\x%02x' $((MANWB_JAL & 0xFF)))
byte1=$(printf '\\x%02x' $(((MANWB_JAL >> 8) & 0xFF)))
byte2=$(printf '\\x%02x' $(((MANWB_JAL >> 16) & 0xFF)))
byte3=$(printf '\\x%02x' $(((MANWB_JAL >> 24) & 0xFF)))

printf "${byte0}${byte1}${byte2}${byte3}" | dd of="$FIRMWARE" bs=1 seek=$WB_HOOK_OFFSET conv=notrunc 2>/dev/null

# NOP the modulo 3 branch to run every frame
#MODULO_BRANCH=$((0x2b6a60))
#printf '\x00\x00\x00\x00' | dd of="$FIRMWARE" bs=1 seek=$MODULO_BRANCH conv=notrunc 2>/dev/null
#echo "  NOPed modulo 3 branch at 0x2b6a60"

# NOP the modulo bran at the end of the AE task function
# LAST_BRANCH=$((0x2b6d00))
# printf '\x00\x00\x00\x00' | dd of="$FIRMWARE" bs=1 seek=$LAST_BRANCH conv=notrunc 2>/dev/null
# echo "  NOPed last branch at 0x2b6d00"


echo ""
echo "Verifying..."
echo -n "  AE hook:  "; xxd -s $AE_HOOK_OFFSET -l 4 "$FIRMWARE" | cut -d: -f2 | cut -c1-12
echo -n "  WB hook:  "; xxd -s $WB_HOOK_OFFSET -l 4 "$FIRMWARE" | cut -d: -f2 | cut -c1-12
echo -n "  manwb:    "; xxd -s $MANWB_OFFSET -l 8 "$FIRMWARE" | cut -d: -f2 | cut -c1-20
echo -n "  hist:     "; xxd -s $HIST_OFFSET -l 8 "$FIRMWARE" | cut -d: -f2 | cut -c1-20

echo ""
echo "Done!"

# Check if D drive is mounted and prompt to build
if [ -d "/mnt/d" ]; then
    echo ""
    echo "SD card detected at /mnt/d"
    read -p "Run build_local.bat to flash? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -f "build_local.bat" ]; then
            cmd.exe /c build_local.bat
        elif [ -f "build_local.sh" ]; then
            ./build_local.sh
        else
            echo "ERROR: build_local.bat/sh not found!"
        fi
    fi
else
    echo ""
    echo "Run build_local.bat to create final firmware package."
fi
