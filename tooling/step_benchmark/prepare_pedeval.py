#!/usr/bin/env python3
"""
PedEval Dataset Preparation Script
Combines partial downloads, extracts Data.zip, and inspects participant directories.
"""

import os
import sys
import zipfile
import subprocess

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    pedeval_dir = os.path.join(base_dir, "pedeval")
    data_zip = os.path.join(pedeval_dir, "Data.zip")
    part2 = os.path.join(pedeval_dir, "part2.bin")
    extract_dir = os.path.join(pedeval_dir, "Data")

    # If part2 exists, append it to Data.zip if needed
    target_size = 31661301
    current_size = os.path.getsize(data_zip) if os.path.exists(data_zip) else 0

    print(f"Current Data.zip size: {current_size} bytes (target: {target_size})")

    if current_size < target_size and os.path.exists(part2):
        part2_size = os.path.getsize(part2)
        print(f"Found part2.bin with {part2_size} bytes.")
        # If current_size + part2_size == target_size
        if current_size + part2_size == target_size:
            print("Combining Data.zip and part2.bin...")
            with open(data_zip, "ab") as f_out, open(part2, "rb") as f_in:
                f_out.write(f_in.read())
            print(f"Combined size: {os.path.getsize(data_zip)} bytes.")
            os.remove(part2)

    if os.path.getsize(data_zip) == target_size:
        print("Data.zip is complete! Extracting...")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(data_zip, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        print(f"Successfully extracted to {extract_dir}.")
        
        # Verify participants
        items = sorted(os.listdir(extract_dir))
        print(f"Extracted {len(items)} items: {items[:10]} ... {items[-5:]}")
    else:
        print(f"Data.zip not yet complete: {os.path.getsize(data_zip)} / {target_size}")

if __name__ == "__main__":
    main()
