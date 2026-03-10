#!/usr/bin/env python3
"""
compare_fw.py — Kodak Reels firmware binary comparison tool

Compares two firmware files (typically Type C and Type D) to:
1. Find consistent address offsets between variants
2. Identify regions that differ (new sensor code, restructured pipeline)
3. Validate known offsets

Usage:
    python3 compare_fw.py --fw-c FWDV280-C-stock.rbn --fw-d FWDV280-D-stock.rbn
    python3 compare_fw.py --fw-c FWDV280-C-stock.rbn --fw-d FWDV280-D-stock.rbn --check-offset 0x1164
    python3 compare_fw.py --fw-c FWDV280-C-stock.rbn --fw-d FWDV280-D-stock.rbn --find-addr 0x2bf908
"""

import argparse
import struct
import sys
from pathlib import Path

BASE_ADDR = 0x80000000
KNOWN_OFFSET = 0x1164  # Confirmed C→D offset for most functions


def load_firmware(path):
    """Load firmware file as bytes."""
    p = Path(path)
    if not p.exists():
        print(f"ERROR: File not found: {path}")
        sys.exit(1)
    data = p.read_bytes()
    print(f"Loaded {path}: {len(data):,} bytes ({len(data)/1024/1024:.2f} MB)")
    return data


def vaddr_to_offset(vaddr):
    """Convert virtual address to file offset."""
    return vaddr - BASE_ADDR


def offset_to_vaddr(offset):
    """Convert file offset to virtual address."""
    return offset + BASE_ADDR


def read_word(data, vaddr):
    """Read a 32-bit little-endian word at a virtual address."""
    offset = vaddr_to_offset(vaddr)
    if offset < 0 or offset + 4 > len(data):
        return None
    return struct.unpack_from('<I', data, offset)[0]


def read_bytes(data, vaddr, length=16):
    """Read bytes at a virtual address."""
    offset = vaddr_to_offset(vaddr)
    if offset < 0 or offset + length > len(data):
        return None
    return data[offset:offset + length]


def hexdump(data, vaddr_start, length=64):
    """Print a hexdump with virtual addresses."""
    offset = vaddr_to_offset(vaddr_start)
    for i in range(0, length, 16):
        chunk = data[offset + i:offset + i + 16]
        if not chunk:
            break
        hex_part = ' '.join(f'{b:02x}' for b in chunk)
        addr = vaddr_start + i
        print(f"  {addr:08x}: {hex_part}")


def check_offset(fw_c, fw_d, c_addr, offset=KNOWN_OFFSET):
    """
    Check if the bytes at c_addr in fw_c match the bytes at (c_addr + offset) in fw_d.
    """
    d_addr = c_addr + offset
    c_bytes = read_bytes(fw_c, c_addr, 32)
    d_bytes = read_bytes(fw_d, d_addr, 32)

    if c_bytes is None:
        print(f"  C address 0x{c_addr:08x} is out of range")
        return False
    if d_bytes is None:
        print(f"  D address 0x{d_addr:08x} is out of range")
        return False

    match_bytes = sum(1 for a, b in zip(c_bytes, d_bytes) if a == b)
    pct = match_bytes / len(c_bytes) * 100

    print(f"\nOffset check: C=0x{c_addr:08x} → D=0x{d_addr:08x} (offset +0x{offset:x})")
    print(f"  Match: {match_bytes}/{len(c_bytes)} bytes ({pct:.0f}%)")
    print(f"  C bytes: {' '.join(f'{b:02x}' for b in c_bytes)}")
    print(f"  D bytes: {' '.join(f'{b:02x}' for b in d_bytes)}")

    return pct > 70  # 70%+ byte match = likely same function


def find_in_d(fw_c, fw_d, c_addr, search_window=0x5000):
    """
    Given a C address, search for the matching function in D firmware.
    Searches around the expected offset location first, then widens.
    """
    c_bytes = read_bytes(fw_c, c_addr, 32)
    if c_bytes is None:
        print(f"ERROR: C address 0x{c_addr:08x} out of range")
        return

    expected_d = c_addr + KNOWN_OFFSET
    print(f"\nSearching for C:0x{c_addr:08x} in D firmware")
    print(f"  Expected D address (offset): 0x{expected_d:08x}")
    print(f"  C bytes: {' '.join(f'{b:02x}' for b in c_bytes)}")

    # Search around expected location
    search_start = max(BASE_ADDR, expected_d - search_window // 2)
    search_end = min(BASE_ADDR + len(fw_d) - 32, expected_d + search_window // 2)

    best_match = None
    best_pct = 0

    step = 4  # MIPS instructions are 4-byte aligned
    offset_start = vaddr_to_offset(search_start)
    offset_end = vaddr_to_offset(search_end)

    for i in range(offset_start, offset_end, step):
        candidate = fw_d[i:i + 32]
        if len(candidate) < 32:
            break
        matches = sum(1 for a, b in zip(c_bytes, candidate) if a == b)
        pct = matches / 32 * 100
        if pct > best_pct:
            best_pct = pct
            best_match = offset_to_vaddr(i)

    if best_match:
        actual_offset = best_match - c_addr
        print(f"  Best match: D=0x{best_match:08x} ({best_pct:.0f}% byte match)")
        print(f"  Actual offset: +0x{actual_offset:x} (expected +0x{KNOWN_OFFSET:x})")
        if actual_offset != KNOWN_OFFSET:
            print(f"  ⚠️  OFFSET EXCEPTION — this address does not follow the standard offset!")
    else:
        print(f"  No strong match found in search window ±0x{search_window//2:x}")


def compare_region(fw_c, fw_d, c_start, length=256, offset=KNOWN_OFFSET):
    """Compare a region of C firmware to the offset-equivalent region in D."""
    d_start = c_start + offset
    print(f"\nRegion comparison: C=0x{c_start:08x}, D=0x{d_start:08x}, length=0x{length:x}")

    c_data = read_bytes(fw_c, c_start, length)
    d_data = read_bytes(fw_d, d_start, length)

    if c_data is None or d_data is None:
        print("  Out of range")
        return

    diffs = [(i, c_data[i], d_data[i]) for i in range(length) if c_data[i] != d_data[i]]
    print(f"  {len(diffs)}/{length} bytes differ ({len(diffs)/length*100:.1f}%)")

    if diffs:
        print(f"  First 10 differences:")
        for i, c_byte, d_byte in diffs[:10]:
            addr = c_start + i
            print(f"    offset +0x{i:03x} (C:0x{addr:08x}): C=0x{c_byte:02x} D=0x{d_byte:02x}")


def main():
    parser = argparse.ArgumentParser(description='Kodak Reels firmware comparison tool')
    parser.add_argument('--fw-c', required=True, help='Type C firmware file')
    parser.add_argument('--fw-d', required=True, help='Type D firmware file')
    parser.add_argument('--check-offset', type=lambda x: int(x, 16), default=None,
                        help='Check a specific offset (hex)')
    parser.add_argument('--find-addr', type=lambda x: int(x, 16), default=None,
                        help='Find a C address in D firmware (hex)')
    parser.add_argument('--compare-region', type=lambda x: int(x, 16), default=None,
                        help='Compare region starting at C address (hex)')
    parser.add_argument('--length', type=lambda x: int(x, 16), default=0x100,
                        help='Length for region comparison (hex, default 0x100)')
    args = parser.parse_args()

    fw_c = load_firmware(args.fw_c)
    fw_d = load_firmware(args.fw_d)

    print(f"\nSize difference: {len(fw_d) - len(fw_c):+,} bytes")
    print(f"Known offset: +0x{KNOWN_OFFSET:x}")

    # Run checks on all known confirmed addresses
    print("\n--- Validating known confirmed addresses ---")
    known_addresses = [
        (0x2bf908, "Preview resolution"),
        (0x2bfe74, "Capture resolution"),
        (0x2b68f8, "AE hook point 1"),
        (0x2b69fc, "AE hook point 2"),
        (0x2b6918, "AE hook point 3"),
    ]
    for addr, label in known_addresses:
        result = check_offset(fw_c, fw_d, addr)
        status = "✅" if result else "⚠️ "
        print(f"  {status} {label}: 0x{addr:08x}")

    # Optional specific checks
    if args.check_offset:
        check_offset(fw_c, fw_d, args.check_offset)

    if args.find_addr:
        find_in_d(fw_c, fw_d, args.find_addr)

    if args.compare_region:
        compare_region(fw_c, fw_d, args.compare_region, args.length)


if __name__ == '__main__':
    main()
