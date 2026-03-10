#!/bin/bash

# Find the most recently modified .rbn file
latestFile=$(ls -t *.rbn 2>/dev/null | head -1)

if [ -z "$latestFile" ]; then
    echo "No .rbn files found"
    exit 1
fi

echo "Latest file: $latestFile"

# Replace .rbn extension with .bcl
bclFile="${latestFile%.rbn}.bcl"

# Run the tools (adjust paths as needed)
./utils/ntkcalc -cw "$latestFile"
./utils/bfc4ntk -c "$latestFile" "$bclFile"
./utils/ntkcalc -cw "$bclFile"

# Create output directory and copy files
# Change this path to wherever your SD card mounts
sudo mount -t drvfs 'D:' /mnt/d 2>/dev/null

OUTPUT_DIR="/mnt/d"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/NVTDELFW"
cp "$bclFile" "FWDV280.BIN"
cp "FWDV280.BIN" "$OUTPUT_DIR/"

echo "Done. Output copied to $OUTPUT_DIR/FWDV280.BIN"
