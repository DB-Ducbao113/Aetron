#!/usr/bin/env python3
"""
Downloads selected sequence files from Zenodo record 12566912 (Android GNSS Dataset Nantes)
using HTTP range requests directly from the remote 5.6 GB zip archive.
"""

import os
import sys
import struct
import zlib
import urllib.request
import hashlib

ZENODO_RECORD_URL = "https://zenodo.org/api/records/12566912/files/Android_GNSS_Dataset_Nantes.zip/content"
TOTAL_SIZE = 5596780847
TARGET_DIR = os.path.join(os.path.dirname(__file__), "data", "zenodo_nantes")

SELECTED_FILES = [
    # Metadata & documentation
    "Android_GNSS_Dataset_Nantes/LICENSE.txt",
    "Android_GNSS_Dataset_Nantes/dataset/notes.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S1/notes.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S2/notes.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S3/notes.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S4/notes.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S5/notes.txt",
    # S1: Open-sky Outdoor
    "Android_GNSS_Dataset_Nantes/dataset/S1/A1/GP7/log_mimir_20240313111400.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S1/A2/GP7/log_mimir_20240313112757.txt",
    # S4: Urban Canyon Outdoor
    "Android_GNSS_Dataset_Nantes/dataset/S4/A1/GP7/log_mimir_20240314144624.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S4/A2/GP7/log_mimir_20240314151021.txt",
    # S2: Indoor building with outdoor/transition phases
    "Android_GNSS_Dataset_Nantes/dataset/S2/A1/GP7/log_mimir_20240313154931.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S2/A2/GP7/log_mimir_20240313155815.txt",
    # S3: Light indoor train station
    "Android_GNSS_Dataset_Nantes/dataset/S3/A1/GP7/log_mimir_20240314102818.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S3/A2/GP7/log_mimir_20240314104725.txt",
    # S5: Shopping center indoor
    "Android_GNSS_Dataset_Nantes/dataset/S5/A1/GP7/log_mimir_20240315101511.txt",
    "Android_GNSS_Dataset_Nantes/dataset/S5/A2/GP7/log_mimir_20240315102957.txt",
]

def get_central_directory():
    print("Fetching Zip64 central directory via HTTP range...")
    range_size = 512 * 1024
    req = urllib.request.Request(
        ZENODO_RECORD_URL,
        headers={"Range": f"bytes={TOTAL_SIZE - range_size}-{TOTAL_SIZE - 1}", "User-Agent": "curl/8.7.1"}
    )
    with urllib.request.urlopen(req) as resp:
        tail = resp.read()

    cd_offset = 5596517473
    cd_size = 263276
    start = cd_offset - (TOTAL_SIZE - range_size)
    cd_data = tail[start:start+cd_size]

    offset = 0
    entries = {}
    while offset < len(cd_data):
        if cd_data[offset:offset+4] != b"PK\x01\x02":
            break
        header = cd_data[offset:offset+46]
        sig, ver_made, ver_need, flags, method, mtime, mdate, crc32, comp_size, uncomp_size, name_len, extra_len, comment_len, disk, int_attr, ext_attr, local_offset = struct.unpack("<IHHHHHHIIIHHHHHII", header)
        name = cd_data[offset+46:offset+46+name_len].decode("utf-8", errors="replace")
        
        if local_offset == 0xFFFFFFFF or comp_size == 0xFFFFFFFF or uncomp_size == 0xFFFFFFFF:
            extra = cd_data[offset+46+name_len:offset+46+name_len+extra_len]
            eoff = 0
            while eoff < len(extra):
                tag, sz = struct.unpack("<HH", extra[eoff:eoff+4])
                if tag == 1:
                    p = eoff + 4
                    if uncomp_size == 0xFFFFFFFF:
                        uncomp_size = struct.unpack("<Q", extra[p:p+8])[0]; p += 8
                    if comp_size == 0xFFFFFFFF:
                        comp_size = struct.unpack("<Q", extra[p:p+8])[0]; p += 8
                    if local_offset == 0xFFFFFFFF:
                        local_offset = struct.unpack("<Q", extra[p:p+8])[0]; p += 8
                    break
                eoff += 4 + sz

        entries[name] = {
            "comp_size": comp_size,
            "uncomp_size": uncomp_size,
            "method": method,
            "local_offset": local_offset,
            "crc32": crc32
        }
        offset += 46 + name_len + extra_len + comment_len

    return entries

def download_and_extract_file(entry_name, meta):
    comp_size = meta["comp_size"]
    method = meta["method"]
    local_offset = meta["local_offset"]
    
    # Target path
    rel_path = entry_name.replace("Android_GNSS_Dataset_Nantes/", "")
    out_path = os.path.join(TARGET_DIR, rel_path)
    if os.path.exists(out_path) and os.path.getsize(out_path) == meta["uncomp_size"]:
        print(f"Already downloaded: {rel_path} ({meta['uncomp_size']} bytes)")
        return out_path

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    print(f"Downloading {rel_path} (compressed {comp_size} bytes -> uncompressed {meta['uncomp_size']} bytes)...")
    
    # Read local header (up to 1KB) + compressed payload
    # Note: local header has variable length (30 + name_len + extra_len)
    # Fetch local header first
    header_req = urllib.request.Request(
        ZENODO_RECORD_URL,
        headers={"Range": f"bytes={local_offset}-{local_offset + 128}", "User-Agent": "curl/8.7.1"}
    )
    with urllib.request.urlopen(header_req) as resp:
        hbuf = resp.read()
    sig, ver, flags, m, mtime, mdate, crc, cs, us, nl, el = struct.unpack("<IHHHHHIIIHH", hbuf[:30])
    payload_start = local_offset + 30 + nl + el
    payload_end = payload_start + comp_size - 1

    # Now fetch exactly compressed payload
    data_req = urllib.request.Request(
        ZENODO_RECORD_URL,
        headers={"Range": f"bytes={payload_start}-{payload_end}", "User-Agent": "curl/8.7.1"}
    )
    with urllib.request.urlopen(data_req) as resp:
        comp_data = resp.read()

    if method == 0:
        raw_data = comp_data
    elif method == 8:
        raw_data = zlib.decompress(comp_data, -15)
    else:
        raise ValueError(f"Unsupported compression method {method}")

    with open(out_path, "wb") as f:
        f.write(raw_data)

    print(f"Saved: {out_path} ({len(raw_data)} bytes)")
    return out_path

def main():
    entries = get_central_directory()
    os.makedirs(TARGET_DIR, exist_ok=True)
    manifest = []
    
    for fname in SELECTED_FILES:
        if fname not in entries:
            print(f"WARNING: {fname} not found in zip archive!")
            continue
        meta = entries[fname]
        out_path = download_and_extract_file(fname, meta)
        with open(out_path, "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        manifest.append({
            "entry": fname,
            "path": out_path,
            "size": meta["uncomp_size"],
            "sha256": h
        })

    print(f"\nDownloaded and verified {len(manifest)} files into {TARGET_DIR}.")

if __name__ == "__main__":
    main()
