#!/usr/bin/env python3
"""
patch_fw.py — Kodak Reels firmware patching utility

Apply patches to a firmware file and recalculate the checksum.

Usage:
    # Patch a single address
    python3 patch_fw.py --input FWDV280-D-stock.rbn --output FWDV280-D-phase9test.rbn \
        --patch 0x2c10e8:0xF0D2

    # Apply a patch set from a JSON file
    python3 patch_fw.py --input FWDV280-D-stock.rbn --output FWDV280-D-phase9test.rbn \
        --patch-file patches/phase9-fps.json

    # Dry run (show what would be patched, don't write)
    python3 patch_fw.py --input FWDV280-D-stock.rbn --patch 0x2c10e8:0xF0D2 --dry-run

Patch file format (JSON):
    {
        "description": "Phase 9 FPS test - 18fps",
        "base": "phase8v3",
        "patches": [
            {"addr": "0x2c10e8", "bytes": "F0D2", "comment": "18fps timing value"},
            {"addr": "0x2c10ec", "bytes": "AABB", "comment": "related register"}
        ]
    }
"""

import argparse
import json
import struct
import shutil
from pathlib import Path
from datetime import datetime

BASE_ADDR = 0x80000000


def vaddr_to_offset(vaddr):
    return vaddr - BASE_ADDR


def load_firmware(path):
    data = bytearray(Path(path).read_bytes())
    print(f"Loaded: {path} ({len(data):,} bytes)")
    return data


def apply_patch(data, vaddr, patch_bytes, dry_run=False):
    """Apply a byte patch at a virtual address."""
    offset = vaddr_to_offset(vaddr)
    if offset < 0 or offset + len(patch_bytes) > len(data):
        print(f"  ERROR: Address 0x{vaddr:08x} out of range")
        return False

    original = data[offset:offset + len(patch_bytes)]
    orig_hex = ' '.join(f'{b:02x}' for b in original)
    new_hex = ' '.join(f'{b:02x}' for b in patch_bytes)

    print(f"  0x{vaddr:08x}: {orig_hex} → {new_hex}", end="")

    if original == patch_bytes:
        print(" (no change)")
        return True

    if not dry_run:
        data[offset:offset + len(patch_bytes)] = patch_bytes
        print(" ✓")
    else:
        print(" [DRY RUN]")

    return True


def recalculate_checksum(data):
    """
    Recalculate the Novatek firmware checksum.
    
    NOTE: The exact checksum algorithm depends on firmware version.
    NktTool handles this properly. This is a placeholder implementation.
    If checksums don't match after patching, use NktTool directly.
    
    The checksum is typically stored in the last 4 bytes or in a header field.
    """
    # TODO: Implement proper Novatek checksum algorithm
    # For now, print a warning — use NktTool for production patches
    print("\n⚠️  WARNING: Checksum recalculation not yet implemented.")
    print("   Use NktTool to fix the checksum before flashing:")
    print("   NktTool.exe FWDV280.BIN")
    print("   (64-bit NktTool shared by 0dan0 in v7.4.1 release)")


def main():
    parser = argparse.ArgumentParser(description='Kodak Reels firmware patcher')
    parser.add_argument('--input', required=True, help='Input firmware file')
    parser.add_argument('--output', help='Output firmware file (default: input-patched.rbn)')
    parser.add_argument('--patch', action='append', metavar='ADDR:HEXBYTES',
                        help='Patch: address:hexbytes (e.g. 0x2c10e8:F0D2)')
    parser.add_argument('--patch-file', help='JSON patch file')
    parser.add_argument('--dry-run', action='store_true', help='Show patches without writing')
    args = parser.parse_args()

    data = load_firmware(args.input)

    patches = []

    # Command line patches
    if args.patch:
        for p in args.patch:
            addr_str, bytes_str = p.split(':', 1)
            addr = int(addr_str, 16)
            patch_bytes = bytes.fromhex(bytes_str)
            patches.append({'addr': addr, 'bytes': patch_bytes, 'comment': ''})

    # JSON patch file
    if args.patch_file:
        with open(args.patch_file) as f:
            pf = json.load(f)
        print(f"Patch file: {pf.get('description', 'unnamed')}")
        for p in pf.get('patches', []):
            patches.append({
                'addr': int(p['addr'], 16),
                'bytes': bytes.fromhex(p['bytes']),
                'comment': p.get('comment', '')
            })

    if not patches:
        print("No patches specified. Use --patch or --patch-file.")
        return

    print(f"\nApplying {len(patches)} patch(es):")
    success = True
    for p in patches:
        if p['comment']:
            print(f"  # {p['comment']}")
        if not apply_patch(data, p['addr'], p['bytes'], args.dry_run):
            success = False

    if not success:
        print("\nERROR: Some patches failed. Output not written.")
        return

    if args.dry_run:
        print("\nDry run complete. No files written.")
        return

    # Determine output path
    if args.output:
        out_path = args.output
    else:
        stem = Path(args.input).stem
        out_path = f"{stem}-patched.rbn"

    Path(out_path).write_bytes(data)
    print(f"\nWritten: {out_path}")

    recalculate_checksum(data)

    # Log the patch
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "input": args.input,
        "output": out_path,
        "patches": [
            {"addr": hex(p['addr']), "bytes": p['bytes'].hex(), "comment": p['comment']}
            for p in patches
        ]
    }
    log_path = "patch-log.json"
    try:
        existing = json.loads(Path(log_path).read_text()) if Path(log_path).exists() else []
        existing.append(log_entry)
        Path(log_path).write_text(json.dumps(existing, indent=2))
        print(f"Logged to: {log_path}")
    except Exception as e:
        print(f"(Log write failed: {e})")


if __name__ == '__main__':
    main()
