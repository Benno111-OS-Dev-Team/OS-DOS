#!/usr/bin/env python3

import argparse
import math
from pathlib import Path


def mz_to_flat_binary(data: bytes, load_segment: int, name: str) -> bytes:
    if len(data) < 0x1C or data[0:2] != b"MZ":
        raise RuntimeError(f"{name}: expected an MZ executable header")

    header_paragraphs = int.from_bytes(data[8:10], "little")
    header_size = header_paragraphs * 16
    relocation_count = int.from_bytes(data[6:8], "little")
    relocation_table = int.from_bytes(data[0x18:0x1A], "little")

    if header_size > len(data):
        raise RuntimeError(f"{name}: invalid MZ header size")
    if relocation_table + relocation_count * 4 > header_size:
        raise RuntimeError(f"{name}: relocation table falls outside the header")

    image = bytearray(data[header_size:])
    for index in range(relocation_count):
        entry = relocation_table + index * 4
        rel_off = int.from_bytes(data[entry:entry + 2], "little")
        rel_seg = int.from_bytes(data[entry + 2:entry + 4], "little")
        fixup = rel_seg * 16 + rel_off
        if fixup + 2 > len(image):
            raise RuntimeError(f"{name}: relocation fixup {index} points past the image")
        word = int.from_bytes(image[fixup:fixup + 2], "little")
        image[fixup:fixup + 2] = ((word + load_segment) & 0xFFFF).to_bytes(2, "little")

    return bytes(image)


def build_boot_image(kernel_exe: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # FAT12 1.44MB geometry
    bps = 512
    total_sectors = 2880
    sectors_per_cluster = 1
    reserved_sectors = 1
    num_fats = 2
    root_entries = 224
    sectors_per_fat = 9
    root_dir_sectors = (root_entries * 32 + (bps - 1)) // bps
    first_data_sector = reserved_sectors + num_fats * sectors_per_fat + root_dir_sectors
    data_sectors = total_sectors - first_data_sector
    total_clusters = data_sectors // sectors_per_cluster

    if not kernel_exe.exists():
        raise RuntimeError(f"Missing kernel executable: {kernel_exe}")

    kernel = mz_to_flat_binary(kernel_exe.read_bytes(), 0x00C0, "IO.SYS")
    if len(kernel) < 0x2000:
        kernel = kernel + (b"\x00" * (0x2000 - len(kernel)))

    files = [
        ("IO.SYS", 0x06, kernel),
    ]

    file_data = []
    for name, attr, data in files:
        clusters = max(1, math.ceil(len(data) / (bps * sectors_per_cluster)))
        file_data.append((name, attr, data, clusters))

    io_name, io_attr, io_data, io_clusters = file_data[0]
    io_start_lba = first_data_sector
    io_sector_count = io_clusters * sectors_per_cluster
    if io_sector_count > 0xFFFF:
        raise RuntimeError("IO.SYS load is too large for 16-bit sector counter")

    image = bytearray(total_sectors * bps)

    # Boot sector (FAT12 BPB + bootstrap that loads IO.SYS and jumps to it)
    bs = bytearray(512)
    bs[0:3] = b"\xEB\x3C\x90"
    bs[3:11] = b"OSDOS5.0"
    bs[11:13] = (bps).to_bytes(2, "little")
    bs[13] = sectors_per_cluster
    bs[14:16] = (reserved_sectors).to_bytes(2, "little")
    bs[16] = num_fats
    bs[17:19] = (root_entries).to_bytes(2, "little")
    bs[19:21] = (total_sectors).to_bytes(2, "little")
    bs[21] = 0xF0
    bs[22:24] = (sectors_per_fat).to_bytes(2, "little")
    bs[24:26] = (18).to_bytes(2, "little")   # sectors/track
    bs[26:28] = (2).to_bytes(2, "little")    # heads
    bs[28:32] = (0).to_bytes(4, "little")    # hidden sectors
    bs[32:36] = (0).to_bytes(4, "little")    # big total sectors
    bs[36] = 0x00
    bs[37] = 0x00
    bs[38] = 0x29
    bs[39:43] = (0x12345678).to_bytes(4, "little")
    bs[43:54] = b"OSDOSBOOT  "
    bs[54:62] = b"FAT12   "
    boot_code = bytearray([
        0xFA,0x31,0xC0,0x8E,0xD8,0x8E,0xD0,0xBC,0x00,0x7C,0xFB,0x88,0x16,0xDA,0x7C,0x8B,
        0x2E,0xDB,0x7C,0x8B,0x3E,0xDD,0x7C,0xB8,0xC0,0x00,0x8E,0xC0,0x31,0xDB,0xBE,0xDF,
        0x7C,0xE8,0x6C,0x00,0x83,0xFF,0x00,0x74,0x3A,0x89,0xE8,0x31,0xD2,0xBE,0x12,0x00,
        0xF7,0xF6,0x88,0xD1,0xFE,0xC1,0x31,0xD2,0xBE,0x02,0x00,0xF7,0xF6,0x88,0xC5,0x88,
        0xD6,0x8A,0x16,0xDA,0x7C,0xB8,0x01,0x02,0xCD,0x13,0x72,0x3A,0xB0,0x2E,0xB4,0x0E,
        0xCD,0x10,0x81,0xC3,0x00,0x02,0x73,0x07,0x8C,0xC0,0x2D,0x00,0xF0,0x8E,0xC0,0x45,
        0x4F,0xEB,0xC1,0xBE,0xEF,0x7C,0xE8,0x27,0x00,0xFA,0x31,0xC0,0x8E,0xD8,0xC7,0x06,
        0x13,0x04,0x80,0x02,0xB8,0xC0,0x00,0x8E,0xD8,0x8E,0xC0,0x8E,0xD0,0xBC,0xFE,0xFF,
        0xFB,0xEA,0x00,0x00,0xC0,0x00,0xBE,0x02,0x7D,0xE8,0x04,0x00,0xFA,0xF4,0xEB,0xFC,
        0xAC,0x08,0xC0,0x74,0x06,0xB4,0x0E,0xCD,0x10,0xEB,0xF5,0xC3,0x00,0xAA,0xAA,0xBB,
        0xBB,0x4C,0x6F,0x61,0x64,0x69,0x6E,0x67,0x20,0x49,0x4F,0x2E,0x53,0x59,0x53,0x20,
        0x00,0x0D,0x0A,0x42,0x6F,0x6F,0x74,0x69,0x6E,0x67,0x20,0x49,0x4F,0x2E,0x53,0x59,
        0x53,0x0D,0x0A,0x00,0x0D,0x0A,0x44,0x69,0x73,0x6B,0x20,0x72,0x65,0x61,0x64,0x20,
        0x65,0x72,0x72,0x6F,0x72,0x0D,0x0A,0x00
    ])
    if 62 + len(boot_code) > 510:
        raise RuntimeError("Boot code overflow: exceeds 510-byte limit")
    boot_code[157:159] = io_start_lba.to_bytes(2, "little")
    boot_code[159:161] = io_sector_count.to_bytes(2, "little")
    bs[62:62 + len(boot_code)] = boot_code
    bs[510:512] = b"\x55\xAA"
    image[0:512] = bs

    # FAT12 table
    fat = bytearray(sectors_per_fat * bps)
    fat[0] = 0xF0
    fat[1] = 0xFF
    fat[2] = 0xFF

    def set_fat12_entry(cluster, value):
        offset = (cluster * 3) // 2
        if cluster & 1:
            fat[offset] = (fat[offset] & 0x0F) | ((value << 4) & 0xF0)
            fat[offset + 1] = (value >> 4) & 0xFF
        else:
            fat[offset] = value & 0xFF
            fat[offset + 1] = (fat[offset + 1] & 0xF0) | ((value >> 8) & 0x0F)

    next_cluster = 2
    allocation = []
    for name, attr, data, clusters in file_data:
        start = next_cluster
        chain = list(range(start, start + clusters))
        next_cluster += clusters
        allocation.append((name, attr, data, chain))

    if next_cluster - 2 > total_clusters:
        raise RuntimeError("Not enough space for files in 1.44MB image")

    for _, _, _, chain in allocation:
        for i, cluster in enumerate(chain):
            nxt = 0xFFF if i == len(chain) - 1 else chain[i + 1]
            set_fat12_entry(cluster, nxt)

    fat1_start = reserved_sectors * bps
    fat2_start = (reserved_sectors + sectors_per_fat) * bps
    image[fat1_start:fat1_start + len(fat)] = fat
    image[fat2_start:fat2_start + len(fat)] = fat

    # Root directory
    root_start = (reserved_sectors + num_fats * sectors_per_fat) * bps
    root = bytearray(root_dir_sectors * bps)

    def dos_name(name):
        n, e = name.split(".")
        return (n[:8].ljust(8) + e[:3].ljust(3)).encode("ascii")

    for idx, (name, attr, data, chain) in enumerate(allocation):
        e = bytearray(32)
        e[0:11] = dos_name(name.upper())
        e[11] = attr
        e[26:28] = chain[0].to_bytes(2, "little")
        e[28:32] = len(data).to_bytes(4, "little")
        root[idx * 32:(idx + 1) * 32] = e

    image[root_start:root_start + len(root)] = root

    # Data area
    for _, _, data, chain in allocation:
        for i, cluster in enumerate(chain):
            sector = first_data_sector + (cluster - 2) * sectors_per_cluster
            off = sector * bps
            chunk = data[i * bps:(i + 1) * bps]
            image[off:off + len(chunk)] = chunk

    output_path.write_bytes(image)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the bootable floppy image")
    parser.add_argument("--kernel", required=True, type=Path, help="Path to kernel.exe")
    parser.add_argument("--output", required=True, type=Path, help="Boot image output path")
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    build_boot_image(args.kernel, args.output)
    print(f"Created {args.output}")


if __name__ == "__main__":
    main()
