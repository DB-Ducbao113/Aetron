import urllib.request
import struct

ZIP_URL = "https://zenodo.org/records/20525157/files/Outdoor-1.zip?download=1"

# First get Content-Length
req = urllib.request.Request(ZIP_URL, headers={"User-Agent": "curl/8.7.1"}, method="HEAD")
with urllib.request.urlopen(req, timeout=10) as resp:
    total_size = int(resp.headers.get("Content-Length", 0))
    print(f"Total size: {total_size} bytes ({total_size / (1024*1024):.2f} MB)")

# Read last 64 KB to find End of Central Directory (EOCD)
range_size = 65536
req = urllib.request.Request(
    ZIP_URL,
    headers={"Range": f"bytes={total_size - range_size}-{total_size - 1}", "User-Agent": "curl/8.7.1"}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    tail = resp.read()

# Search for EOCD signature: 0x06054b50
eocd_pos = tail.rfind(b"\x50\x4b\x05\x06")
print("EOCD pos in tail:", eocd_pos)
if eocd_pos >= 0:
    # Check if Zip64 locator is present: 0x07064b50
    zip64_loc = tail.rfind(b"\x50\x4b\x06\x07")
    print("Zip64 locator pos:", zip64_loc)
    if zip64_loc >= 0:
        # Zip64 locator structure: 4 bytes sig, 4 bytes disk, 8 bytes zip64 EOCD offset, 4 bytes total disks
        loc_data = tail[zip64_loc:zip64_loc+20]
        sig, disk, eocd64_offset, total_disks = struct.unpack("<4sIQI", loc_data)
        print("Zip64 EOCD offset:", eocd64_offset)
        
        # Read Zip64 EOCD
        req = urllib.request.Request(
            ZIP_URL,
            headers={"Range": f"bytes={eocd64_offset}-{eocd64_offset + 100}", "User-Agent": "curl/8.7.1"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            eocd64 = resp.read()
            # Zip64 EOCD record: sig (4), size (8), ver_made (2), ver_needed (2), disk_num (4), disk_cd (4),
            # total_cd_entries_disk (8), total_cd_entries (8), cd_size (8), cd_offset (8)
            parts = struct.unpack("<4sQHHIIQQQQ", eocd64[:56])
            cd_entries = parts[7]
            cd_size = parts[8]
            cd_offset = parts[9]
            print(f"CD entries: {cd_entries}, CD size: {cd_size}, CD offset: {cd_offset}")
            
            # Fetch Central Directory
            req = urllib.request.Request(
                ZIP_URL,
                headers={"Range": f"bytes={cd_offset}-{cd_offset + cd_size - 1}", "User-Agent": "curl/8.7.1"}
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                cd_data = resp.read()
                
            offset = 0
            while offset < len(cd_data):
                if cd_data[offset:offset+4] != b"\x50\x4b\x01\x02":
                    break
                # CD header
                fields = struct.unpack("<4sHHHHHHIIIHHHHHII", cd_data[offset:offset+46])
                comp_size = fields[8]
                uncomp_size = fields[9]
                name_len = fields[10]
                extra_len = fields[11]
                comment_len = fields[12]
                local_header_offset = fields[16]
                name = cd_data[offset+46:offset+46+name_len].decode("utf-8", errors="replace")
                
                # Check for Zip64 extra field (0x0001)
                extra = cd_data[offset+46+name_len:offset+46+name_len+extra_len]
                extra_offset = 0
                while extra_offset < len(extra):
                    header_id, data_size = struct.unpack("<HH", extra[extra_offset:extra_offset+4])
                    if header_id == 1:
                        # Zip64 extended information
                        z64_data = extra[extra_offset+4:extra_offset+4+data_size]
                        idx = 0
                        if uncomp_size == 0xFFFFFFFF and idx + 8 <= len(z64_data):
                            uncomp_size = struct.unpack("<Q", z64_data[idx:idx+8])[0]
                            idx += 8
                        if comp_size == 0xFFFFFFFF and idx + 8 <= len(z64_data):
                            comp_size = struct.unpack("<Q", z64_data[idx:idx+8])[0]
                            idx += 8
                        if local_header_offset == 0xFFFFFFFF and idx + 8 <= len(z64_data):
                            local_header_offset = struct.unpack("<Q", z64_data[idx:idx+8])[0]
                            idx += 8
                        break
                    extra_offset += 4 + data_size
                    
                print(f"File: {name} (comp: {comp_size}, uncomp: {uncomp_size}, offset: {local_header_offset})")
                offset += 46 + name_len + extra_len + comment_len
