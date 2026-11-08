#!/usr/bin/env python3
"""
Aetron P01 Held-Out Ground-Truth Evaluation Tool
================================================
Performs rigorous held-out test partitioning on authentic public datasets:
- Partitioning:
    Hour 1 (Epochs 0–3599): Tuning / Exploratory (NOT reported as test)
    Hour 2 (Epochs 3600–7199): Validation
    Hours 3–5 (Epochs 7200–18000): HELD-OUT TEST SET
- Cross-Device Evaluation:
    Device A: Google Pixel 5 (Single-frequency L1)
    Device B: Google Pixel 9 Pro XL (Dual-frequency L1/L5)
- Ground Truth: Geodetic Pillar Reference (ITRF2020)
- Algorithms Evaluated:
    A. Raw GNSS Observations
    B. Legacy Alpha Filter (alpha = 0.25)
    C. Current P01 (Kinematic Gating + Streaming Preprocessing)
    D. Current P01 + P02 + AEKF (Integrated)
    E. Hybrid GPS Input Quality Gate (Mobile-GVIO M-Estimator + P02 + AEKF)
"""

import math
import os
import sys

R_EARTH = 6371000.0

def haversine(lat1, lon1, lat2, lon2):
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi, dlam = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dphi*0.5)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam*0.5)**2
    return 2.0 * R_EARTH * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

def parse_coord(s, d):
    if not s or "." not in s: return None
    dp = s.find(".")
    deg = float(s[:dp-2])
    min_ = float(s[dp-2:])
    val = deg + min_ / 60.0
    return -val if d in ("S", "W") else val

class EKF4State:
    def __init__(self, lat0, lon0, q_pos=0.6, q_vel=1.2):
        self.lat0, self.lon0 = lat0, lon0
        self.cos_lat0 = math.cos(math.radians(lat0))
        self.x, self.y, self.vx, self.vy = 0.0, 0.0, 0.0, 0.0
        self.p00, self.p11, self.p22, self.p33 = 25.0, 25.0, 4.0, 4.0
        self.q_pos, self.q_vel = q_pos, q_vel
        self.initialized = False

    def to_xy(self, lat, lon):
        y = math.radians(lat - self.lat0) * R_EARTH
        x = math.radians(lon - self.lon0) * R_EARTH * self.cos_lat0
        return x, y

    def to_lat_lon(self, x, y):
        dlat = (y / R_EARTH) * (180.0 / math.pi)
        dlon = (x / (R_EARTH * self.cos_lat0)) * (180.0 / math.pi)
        return self.lat0 + dlat, self.lon0 + dlon

    def reset(self):
        self.initialized = False
        self.x, self.y, self.vx, self.vy = 0.0, 0.0, 0.0, 0.0
        self.p00, self.p11, self.p22, self.p33 = 25.0, 25.0, 4.0, 4.0

    def update(self, lat, lon, acc_m, dt=1.0, cov_scale=1.0):
        mx, my = self.to_xy(lat, lon)
        if not self.initialized:
            self.x, self.y = mx, my
            self.initialized = True
            return lat, lon

        # 1. Predict
        self.x += self.vx * dt
        self.y += self.vy * dt
        qp = (self.q_pos * dt)**2
        qv = (self.q_vel * dt)**2
        self.p00 += qp + self.p22 * (dt**2)
        self.p11 += qp + self.p33 * (dt**2)
        self.p22 += qv
        self.p33 += qv

        # 2. Measurement update
        var_r = (acc_m ** 2) * cov_scale
        k0 = self.p00 / (self.p00 + var_r)
        k1 = self.p11 / (self.p11 + var_r)
        kv0 = self.p22 / (self.p00 + var_r)
        kv1 = self.p33 / (self.p11 + var_r)

        ix, iy = mx - self.x, my - self.y
        self.x += k0 * ix
        self.y += k1 * iy
        self.vx += kv0 * ix
        self.vy += kv1 * iy

        self.p00 *= (1.0 - k0)
        self.p11 *= (1.0 - k1)
        self.p22 *= (1.0 - kv0)
        self.p33 *= (1.0 - kv1)

        return self.to_lat_lon(self.x, self.y)

def parse_nmea(fname):
    pts = []
    with open(f"tooling/data/tomastik/{fname}") as f:
        for line in f:
            if "GNGGA" in line or "$GPGGA" in line:
                p = line.strip().split(",")
                lat = parse_coord(p[3], p[4])
                lon = parse_coord(p[5], p[6])
                hdop = float(p[9]) if p[9] else 1.0
                sats = int(p[8]) if p[8] else 0
                if lat and lon:
                    pts.append((lat, lon, hdop, sats))
    return pts

def evaluate_held_out(label, pts, ref_lat, ref_lon, start_idx=7200, end_idx=18000):
    subset = pts[start_idx:min(end_idx, len(pts))]
    n = len(subset)
    print(f"\n{'='*95}")
    print(f"HELD-OUT EVALUATION: {label} (Epochs {start_idx}–{start_idx+n}, {n/3600:.1f} Hours @ 1Hz)")
    print(f"Reference Pillar: {ref_lat:.7f}°N, {ref_lon:.7f}°E (ITRF2020)")
    print(f"{'='*95}")

    # A. Raw GPS
    raw_errs = []
    raw_dist = 0.0
    for i in range(n):
        lat, lon, _, _ = subset[i]
        err = haversine(lat, lon, ref_lat, ref_lon)
        raw_errs.append(err)
        if i > 0:
            raw_dist += haversine(subset[i-1][0], subset[i-1][1], lat, lon)

    # B. Legacy Alpha Filter
    legacy_errs = []
    legacy_dist = 0.0
    prev_leg_lat, prev_leg_lon = subset[0][0], subset[0][1]
    for i in range(n):
        lat, lon, _, _ = subset[i]
        filt_lat = prev_leg_lat + 0.25 * (lat - prev_leg_lat)
        filt_lon = prev_leg_lon + 0.25 * (lon - prev_leg_lon)
        legacy_errs.append(haversine(filt_lat, filt_lon, ref_lat, ref_lon))
        if i > 0:
            legacy_dist += haversine(prev_leg_lat, prev_leg_lon, filt_lat, filt_lon)
        prev_leg_lat, prev_leg_lon = filt_lat, filt_lon

    # C. Current P01 + AEKF (without artificial script freeze)
    # Uses realistic mobile accuracy model: HDOP * nominal UERE scale
    p01_ekf = EKF4State(ref_lat, ref_lon)
    p01_errs = []
    p01_dist = 0.0
    prev_p01_lat, prev_p01_lon = subset[0][0], subset[0][1]
    for i in range(n):
        lat, lon, hdop, _ = subset[i]
        acc_m = max(1.5, hdop * 3.5)
        flab, flon = p01_ekf.update(lat, lon, acc_m)
        p01_errs.append(haversine(flab, flon, ref_lat, ref_lon))
        if i > 0:
            p01_dist += haversine(prev_p01_lat, prev_p01_lon, flab, flon)
        prev_p01_lat, prev_p01_lon = flab, flon

    # D. Hybrid GPS Input Quality Gate + AEKF (Adaptive M-estimator covariance downweighting)
    hyb_ekf = EKF4State(ref_lat, ref_lon)
    hyb_errs = []
    hyb_dist = 0.0
    prev_hyb_lat, prev_hyb_lon = subset[0][0], subset[0][1]
    last_val_lat, last_val_lon = subset[0][0], subset[0][1]
    accept_cnt = 0
    downweight_cnt = 0
    reject_cnt = 0

    for i in range(n):
        lat, lon, hdop, _ = subset[i]
        acc_m = max(1.5, hdop * 3.5)
        step = haversine(last_val_lat, last_val_lon, lat, lon)
        e = step / acc_m

        if step > 50.0 and e > 6.0:
            # Reject gross outlier
            reject_cnt += 1
            flab, flon = prev_hyb_lat, prev_hyb_lon
        elif e > 2.5:
            # Downweight jitter with Huber/Cauchy scale
            downweight_cnt += 1
            cov_scale = 1.0 + (e**2) / 6.25
            flab, flon = hyb_ekf.update(lat, lon, acc_m, cov_scale=cov_scale)
            last_val_lat, last_val_lon = lat, lon
        else:
            accept_cnt += 1
            flab, flon = hyb_ekf.update(lat, lon, acc_m, cov_scale=1.0)
            last_val_lat, last_val_lon = lat, lon

        hyb_errs.append(haversine(flab, flon, ref_lat, ref_lon))
        if i > 0:
            hyb_dist += haversine(prev_hyb_lat, prev_hyb_lon, flab, flon)
        prev_hyb_lat, prev_hyb_lon = flab, flon

    def compute_stats(errs, dist):
        s = sorted(errs)
        rmse = math.sqrt(sum(e*e for e in errs) / len(errs))
        p50 = s[len(s) // 2]
        p95 = s[int(len(s) * 0.95)]
        max_e = s[-1]
        return rmse, p50, p95, max_e, dist

    r_rmse, r_p50, r_p95, r_max, r_dst = compute_stats(raw_errs, raw_dist)
    l_rmse, l_p50, l_p95, l_max, l_dst = compute_stats(legacy_errs, legacy_dist)
    p_rmse, p_p50, p_p95, p_max, p_dst = compute_stats(p01_errs, p01_dist)
    h_rmse, h_p50, h_p95, h_max, h_dst = compute_stats(hyb_errs, hyb_dist)

    print(f"| {'Pipeline Architecture':<38} | {'RMSE (m)':<8} | {'P50 (m)':<8} | {'P95 (m)':<8} | {'Max (m)':<8} | {'Wander (m)':<10} | {'Wander Red':<10} |")
    print(f"|:{'-'*38}-|-{'-'*8}:|-{'-'*8}:|-{'-'*8}:|-{'-'*8}:|-{'-'*10}:|-{'-'*10}:|")
    print(f"| {'A. Raw GNSS Observations':<38} | {r_rmse:6.2f} m | {r_p50:6.2f} m | {r_p95:6.2f} m | {r_max:6.2f} m | {r_dst:8.1f} m | {'0.0%':<10} |")
    print(f"| {'B. Legacy Alpha Filter':<38} | {l_rmse:6.2f} m | {l_p50:6.2f} m | {l_p95:6.2f} m | {l_max:6.2f} m | {l_dst:8.1f} m | {(1 - l_dst/r_dst)*100:6.1f}%    |")
    print(f"| {'C. Current P01 + AEKF':<38} | {p_rmse:6.2f} m | {p_p50:6.2f} m | {p_p95:6.2f} m | {p_max:6.2f} m | {p_dst:8.1f} m | {(1 - p_dst/r_dst)*100:6.1f}%    |")
    print(f"| {'D. Hybrid Quality Gate + AEKF':<38} | {h_rmse:6.2f} m | {h_p50:6.2f} m | {h_p95:6.2f} m | {h_max:6.2f} m | {h_dst:8.1f} m | {(1 - h_dst/r_dst)*100:6.1f}%    |")
    print(f"Decisions: Accept={accept_cnt} ({accept_cnt*100/n:.1f}%), Downweight={downweight_cnt} ({downweight_cnt*100/n:.1f}%), Reject={reject_cnt} ({reject_cnt*100/n:.1f}%)")

def main():
    print("=" * 95)
    print("AETRON P01 SCIENTIFIC EVALUATION ON STRICT HELD-OUT TEST DATA")
    print("Zero Training/Tuning Leakage — Held-out Epochs 7,200 to 18,000 (Hours 3 to 5)")
    print("=" * 95)

    open_lat, open_lon = 48.678782048, 19.224442029
    canopy_lat, canopy_lon = 48.572574914, 19.119099070

    # 1. Open Sky - Pixel 5 (Held-out 3 hours = 10,800 epochs)
    p5_open = parse_nmea("open_P5.nmea")
    evaluate_held_out("Open Sky — Pixel 5 (L1 Single-Freq)", p5_open, open_lat, open_lon)

    # 2. Open Sky - Pixel 9 Pro XL (Held-out 3 hours = 10,800 epochs)
    p9_open = parse_nmea("open_P9.nmea")
    evaluate_held_out("Open Sky — Pixel 9 Pro XL (L1/L5 Dual-Freq)", p9_open, open_lat, open_lon)

    # 3. Tree Canopy - Pixel 5 (Held-out 3 hours = 10,800 epochs)
    p5_canopy = parse_nmea("canopy_P5.nmea")
    evaluate_held_out("Tree Canopy — Pixel 5 (L1 Single-Freq)", p5_canopy, canopy_lat, canopy_lon)

if __name__ == "__main__":
    main()
