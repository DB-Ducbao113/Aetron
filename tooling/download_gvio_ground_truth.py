import urllib.request
import zlib
import os
import struct

ZIP_URL = "https://zenodo.org/records/20525157/files/Outdoor-1.zip?download=1"
LOCAL_DIR = os.path.join(os.path.dirname(__file__), "data", "mobile_gvio", "Outdoor-1")
os.makedirs(LOCAL_DIR, exist_ok=True)

# local header offset is 72
# Read local file header to get extra field length and exact data offset
req = urllib.request.Request(
    ZIP_URL,
    headers={"Range": "bytes=72-172", "User-Agent": "curl/8.7.1"}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    hdr = resp.read()

sig, ver, flags, method, mod_time, mod_date, crc, comp_size, uncomp_size, name_len, extra_len = struct.unpack(
    "<4sHHHHHIIIHH", hdr[:30]
)
print(f"Header: method={method}, comp={comp_size}, uncomp={uncomp_size}, name_len={name_len}, extra_len={extra_len}")
data_start = 72 + 30 + name_len + extra_len
comp_size = 183837
data_end = data_start + comp_size - 1

print(f"Fetching compressed ground_truth.txt from range {data_start}-{data_end} ({comp_size} bytes)...")
req = urllib.request.Request(
    ZIP_URL,
    headers={"Range": f"bytes={data_start}-{data_end}", "User-Agent": "curl/8.7.1"}
)
with urllib.request.urlopen(req, timeout=15) as resp:
    comp_data = resp.read()

# Decompress using raw deflate (wbits = -15)
try:
    decomp = zlib.decompress(comp_data, -15)
    out_path = os.path.join(LOCAL_DIR, "ground_truth.txt")
    with open(out_path, "wb") as f:
        f.write(decomp)
    print(f"Successfully extracted ground_truth.txt to {out_path} ({len(decomp)} bytes)")
    
    # Print first few lines
    lines = decomp.decode("utf-8", errors="replace").splitlines()
    print(f"Total lines: {len(lines)}")
    print("First 5 lines:")
    for l in lines[:5]:
        print(" ", l)
except Exception as e:
    print("Decompression error:", e)
