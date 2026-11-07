#!/usr/bin/env python3
"""
OxWalk Dataset Preparation & Step Extraction Script
Extracts ground-truth step timelines from OxWalk_Dec2022.zip for all 39 participants.
"""

import os
import sys
import zipfile
import csv
import io
import json
from datetime import datetime

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    oxwalk_dir = os.path.join(base_dir, "oxwalk")
    zip_path = os.path.join(oxwalk_dir, "OxWalk_Dec2022.zip")
    steps_out_dir = os.path.join(oxwalk_dir, "steps")
    os.makedirs(steps_out_dir, exist_ok=True)

    if not os.path.exists(zip_path):
        print(f"ERROR: {zip_path} not found!")
        sys.exit(1)

    print(f"Reading OxWalk archive: {zip_path}")
    archive_size = os.path.getsize(zip_path)
    print(f"Archive size: {archive_size} bytes ({archive_size / (1024*1024):.2f} MB)")

    # Read metadata.csv
    metadata = {}
    with zipfile.ZipFile(zip_path, 'r') as z:
        if "OxWalk_Dec2022/metadata.csv" in z.namelist():
            with z.open("OxWalk_Dec2022/metadata.csv") as mf:
                reader = csv.reader(io.TextIOWrapper(mf))
                header = next(reader)
                for row in reader:
                    if len(row) >= 3:
                        pid, sex, age = row[0].strip(), row[1].strip(), row[2].strip()
                        metadata[pid] = {"sex": sex, "age_group": age}

    manifest = {
        "dataset_name": "OxWalk (Oxford Walk Dataset)",
        "citation": "Small, S. R., von Fritsch, L., Doherty, A., Khalid, S., & Price, A. (2022). University of Oxford. DOI: 10.5287/bodleian:ORQ2abnbR",
        "license": "Creative Commons Attribution 4.0 International (CC BY 4.0)",
        "archive_size_bytes": archive_size,
        "archive_sha256": "8e201c3211ee9130055ff91c87f62e41e41e3a335de91f153c4cb8b473b975d3",
        "sample_rate_hz": 25.0,
        "total_participants": 39,
        "sessions": []
    }

    total_steps_cohort = 0
    total_duration_cohort = 0.0

    with zipfile.ZipFile(zip_path, 'r') as z:
        for i in range(1, 40):
            pid = f"P{i:02d}"
            csv_in_zip = f"OxWalk_Dec2022/Hip_25Hz/{pid}_hip25.csv"
            if csv_in_zip not in z.namelist():
                print(f"WARNING: {csv_in_zip} missing from archive!")
                continue

            with z.open(csv_in_zip) as f:
                reader = csv.reader(io.TextIOWrapper(f))
                header = next(reader)
                ts_idx = header.index("timestamp")
                ann_idx = header.index("annotation")

                steps = []
                first_ts = None
                last_ts = None
                total_rows = 0

                for r in reader:
                    total_rows += 1
                    ts_str = r[ts_idx]
                    if first_ts is None:
                        first_ts = ts_str
                    last_ts = ts_str

                    if r[ann_idx] == "1":
                        t_cur = datetime.fromisoformat(ts_str)
                        steps.append(t_cur)

                t0 = datetime.fromisoformat(first_ts)
                t1 = datetime.fromisoformat(last_ts)
                duration_sec = (t1 - t0).total_seconds()
                total_steps_cohort += len(steps)
                total_duration_cohort += duration_sec

                # Write out dedicated step timeline CSV
                out_csv = os.path.join(steps_out_dir, f"{pid}_steps.csv")
                with open(out_csv, "w", newline="") as out_f:
                    writer = csv.writer(out_f)
                    writer.writerow(["step_index", "timestamp_iso", "elapsed_sec", "delta_t_step"])
                    prev_t = None
                    for s_idx, s_time in enumerate(steps, 1):
                        elapsed = (s_time - t0).total_seconds()
                        dt = (s_time - prev_t).total_seconds() if prev_t else 0.0
                        writer.writerow([s_idx, s_time.isoformat(), f"{elapsed:.3f}", f"{dt:.3f}"])
                        prev_t = s_time

                meta = metadata.get(pid, {"sex": "unknown", "age_group": "unknown"})
                session_info = {
                    "pid": pid,
                    "sex": meta["sex"],
                    "age_group": meta["age_group"],
                    "raw_samples": total_rows,
                    "duration_sec": round(duration_sec, 2),
                    "step_count": len(steps),
                    "start_time": first_ts,
                    "end_time": last_ts,
                    "steps_file": f"steps/{pid}_steps.csv"
                }
                manifest["sessions"].append(session_info)
                print(f"[{pid}] {len(steps):4d} steps | {duration_sec:6.1f}s | {meta['sex']}, {meta['age_group']}")

    manifest["total_steps"] = total_steps_cohort
    manifest["total_duration_sec"] = round(total_duration_cohort, 2)
    manifest["total_hours"] = round(total_duration_cohort / 3600.0, 2)

    manifest_path = os.path.join(oxwalk_dir, "oxwalk_manifest.json")
    with open(manifest_path, "w") as mf_out:
        json.dump(manifest, mf_out, indent=2)

    print("\n========================================================")
    print(f"OxWalk Preparation Complete!")
    print(f"Total participants: {len(manifest['sessions'])}")
    print(f"Total locomotor steps: {total_steps_cohort}")
    print(f"Total duration: {total_duration_cohort:.1f} s ({total_duration_cohort/3600:.2f} hours)")
    print(f"Manifest written: {manifest_path}")
    print("========================================================")

if __name__ == "__main__":
    main()
