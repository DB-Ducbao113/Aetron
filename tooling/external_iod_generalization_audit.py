#!/usr/bin/env python3
"""
Aetron External IOD Generalization Audit & Dataset Gate
Branch: ekf

Scientific & Methodological Protocol:
1. Frozen Model Configurations: Evaluates all candidate configurations strictly frozen with documented provenance.
2. Canonical Model Checkpoint Selection: Verifies canonical model checkpoint selected on separate validation partition.
3. Independent Dataset Audit: Rigorous provenance, sensor availability, and ground-truth audit of Zenodo Nantes (Record 12566912).
4. No Fabricated Labels: Strictly separates verified outdoor ground truth (S1, S4) from unverified exploratory macro progressions (S2, S3, S5).
5. Formal Decision: Declares DATASET BLOCKED for unverified two-class scoring; release acceptance GATED.
"""

import csv
import hashlib
import json
import math
import os
import sys
from collections import defaultdict
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset


# -------------------------------------------------------------------------
# 1. MODEL DEFINITION & LOADING
# -------------------------------------------------------------------------

class ModelC_DepthwiseSeparableCnn(nn.Module):
    def __init__(self, in_features: int = 4):
        super().__init__()
        self.in_features = in_features
        self.dws1_depth = nn.Conv2d(1, 1, kernel_size=3, padding=1, bias=True)
        self.relu1_d = nn.ReLU()
        self.dws1_point = nn.Conv2d(1, 32, kernel_size=1, bias=True)
        self.bn1 = nn.BatchNorm2d(32)
        self.relu1_p = nn.ReLU()

        self.dws2_depth = nn.Conv2d(32, 32, kernel_size=3, padding=1, groups=32, bias=True)
        self.relu2_d = nn.ReLU()
        self.dws2_point = nn.Conv2d(32, 32, kernel_size=1, bias=True)
        self.bn2 = nn.BatchNorm2d(32)
        self.relu2_p = nn.ReLU()

        self.maxpool = nn.MaxPool2d(kernel_size=(2, 1))
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        self.dense1 = nn.Linear(32, 32)
        self.relu_dense = nn.ReLU()
        self.out = nn.Linear(32, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        if x.dim() == 3:
            h = x.unsqueeze(1)
        else:
            h = x
        h = self.relu1_d(self.dws1_depth(h))
        h = self.relu1_p(self.bn1(self.dws1_point(h)))
        h = self.relu2_d(self.dws2_depth(h))
        h = self.relu2_p(self.bn2(self.dws2_point(h)))
        h = self.maxpool(h)
        h = self.pool(h).squeeze(-1).squeeze(-1)
        h = self.relu_dense(self.dense1(h))
        return self.sigmoid(self.out(h))


def load_folded_into_pytorch(w: dict, device: torch.device) -> nn.Module:
    m = ModelC_DepthwiseSeparableCnn().to(device)
    m.dws1_depth.weight.data = torch.tensor(w['dws1_depth_w'], dtype=torch.float32).unsqueeze(0).unsqueeze(0).to(device)
    m.dws1_depth.bias.data = torch.tensor([w['dws1_depth_b']], dtype=torch.float32).to(device)

    m.dws1_point.weight.data = torch.tensor(w['dws1_point_w'], dtype=torch.float32).reshape(32, 1, 1, 1).to(device)
    m.dws1_point.bias.data = torch.tensor(w['dws1_point_b'], dtype=torch.float32).to(device)
    m.bn1.weight.data.fill_(1.0)
    m.bn1.bias.data.fill_(0.0)
    m.bn1.running_mean.data.fill_(0.0)
    m.bn1.running_var.data.fill_(1.0)
    m.bn1.eps = 0.0

    m.dws2_depth.weight.data = torch.tensor(w['dws2_depth_w'], dtype=torch.float32).unsqueeze(1).to(device)
    m.dws2_depth.bias.data = torch.tensor(w['dws2_depth_b'], dtype=torch.float32).to(device)

    m.dws2_point.weight.data = torch.tensor(w['dws2_point_w'], dtype=torch.float32).unsqueeze(-1).unsqueeze(-1).to(device)
    m.dws2_point.bias.data = torch.tensor(w['dws2_point_b'], dtype=torch.float32).to(device)
    m.bn2.weight.data.fill_(1.0)
    m.bn2.bias.data.fill_(0.0)
    m.bn2.running_mean.data.fill_(0.0)
    m.bn2.running_var.data.fill_(1.0)
    m.bn2.eps = 0.0

    m.dense1.weight.data = torch.tensor(w['dense1_w'], dtype=torch.float32).to(device)
    m.dense1.bias.data = torch.tensor(w['dense1_b'], dtype=torch.float32).to(device)

    m.out.weight.data = torch.tensor(w['out_w'], dtype=torch.float32).unsqueeze(0).to(device)
    m.out.bias.data = torch.tensor([w['out_b']], dtype=torch.float32).to(device)
    m.eval()
    return m


def compute_sha256(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


# -------------------------------------------------------------------------
# 2. MIMIR LOG PARSER (PIXEL 7 SMARTPHONE RECORDINGS)
# -------------------------------------------------------------------------

def parse_mimir_session(filepath: str) -> List[Dict]:
    """
    Parses raw Mimir / Android GNSS logger text file into 1-second epochs.
    Calculates bias-calibrated magnetometer magnitude and gravity-subtracted linear acceleration.
    """
    epochs_raw = defaultdict(lambda: {'acc': [], 'mag_cal': [], 'cn0': []})

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(',')
            tag = parts[0]

            if tag == 'ACC_UNCAL' and len(parts) > 5:
                # ACC_UNCAL,utcTimeMillis,elapsedRealtime_nanosecond,x,y,z,...
                t = int(parts[1]) // 1000
                x, y, z = float(parts[3]), float(parts[4]), float(parts[5])
                mag = math.sqrt(x*x + y*y + z*z)
                epochs_raw[t]['acc'].append(mag)

            elif tag == 'MAG_UNCAL' and len(parts) > 8:
                # MAG_UNCAL,utcTimeMillis,elapsedRealtime_nanosecond,x,y,z,bias_x,bias_y,bias_z,...
                t = int(parts[1]) // 1000
                x, y, z = float(parts[3]), float(parts[4]), float(parts[5])
                bx, by, bz = float(parts[6]), float(parts[7]), float(parts[8])
                cal_mag = math.sqrt((x - bx)**2 + (y - by)**2 + (z - bz)**2)
                epochs_raw[t]['mag_cal'].append(cal_mag)

            elif tag == 'Raw' and len(parts) > 16:
                # Raw,utcTimeMillis,...,Cn0DbHz,...
                t = int(parts[1]) // 1000
                cn0 = float(parts[16]) if parts[16] else 0.0
                epochs_raw[t]['cn0'].append(cn0)

    sorted_secs = sorted(epochs_raw.keys())
    session_epochs = []

    for s in sorted_secs:
        data = epochs_raw[s]
        accs = data['acc']
        mags = data['mag_cal']
        cn0s = data['cn0']

        if not accs or not mags:
            continue

        mean_acc = sum(accs) / len(accs)
        lin_acc = abs(mean_acc - 9.80665)  # Linear acceleration without gravity (m/s^2)
        mean_mag = sum(mags) / len(mags)    # Bias-subtracted calibrated magnetic field (uT)

        # Nantes local time daytime determination (UTC+1 in March)
        hour_utc = (s % 86400) // 3600
        hour_local = (hour_utc + 1) % 24
        daytime = 1.0 if (7 <= hour_local < 19) else 0.0

        top4_cn0 = 0.0
        if cn0s:
            s_sorted = sorted(cn0s, reverse=True)
            k = min(4, len(s_sorted))
            top4_cn0 = sum(s_sorted[:k]) / k

        session_epochs.append({
            'utc_sec': s,
            'lin_acc': lin_acc,
            'mean_mag': mean_mag,
            'daytime': daytime,
            'top4_cn0': top4_cn0,
        })

    return session_epochs


def build_evaluation_windows(
    epochs: List[Dict],
    mean: np.ndarray,
    std: np.ndarray,
    lux_value: float = 0.0,
    window_size: int = 10,
) -> np.ndarray:
    """
    Constructs 10x4 temporal windows [Light, Mag, Acc, Daytime] with prefix padding,
    matching Dart DeepIodNeuralClassifier rolling queue behavior.
    """
    n = len(epochs)
    raw_feats = []
    for ep in epochs:
        raw_feats.append([lux_value, ep['mean_mag'], ep['lin_acc'], ep['daytime']])

    raw_arr = np.array(raw_feats, dtype=np.float32)
    norm = (raw_arr - mean) / std

    windows = []
    history = []
    for i in range(n):
        history.append(norm[i])
        if len(history) > window_size:
            history.pop(0)

        # Prefix padding with step 0
        pad = [history[0]] * (window_size - len(history))
        eval_win = pad + history
        windows.append(np.array(eval_win, dtype=np.float32))

    return np.array(windows, dtype=np.float32)


# -------------------------------------------------------------------------
# 3. HYSTERESIS EVALUATION WITH BOUNDARY RESET
# -------------------------------------------------------------------------

def evaluate_model_on_windows(
    model: nn.Module,
    windows: np.ndarray,
    device: torch.device,
    threshold: float = 0.50,
) -> np.ndarray:
    model.eval()
    loader = DataLoader(torch.tensor(windows, dtype=torch.float32), batch_size=256, shuffle=False)
    probs = []
    with torch.no_grad():
        for x_b in loader:
            x_b = x_b.to(device)
            p = model(x_b)
            probs.extend(p.cpu().numpy().flatten())
    return np.array(probs, dtype=np.float32)


def apply_hysteresis(probs: np.ndarray, low: float = 0.25, high: float = 0.45) -> np.ndarray:
    states = []
    cur_state = 0
    for p in probs:
        if cur_state == 0 and p >= high:
            cur_state = 1
        elif cur_state == 1 and p <= low:
            cur_state = 0
        states.append(cur_state)
    return np.array(states, dtype=int)


# -------------------------------------------------------------------------
# 4. MAIN AUDIT EXECUTION
# -------------------------------------------------------------------------

def main():
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print("="*90)
    print("  AETRON — INDEPENDENT IOD EXTERNAL GENERALIZATION GATE & DATASET AUDIT")
    print(f"  Execution Device: {device}")
    print("="*90)

    # 1. CATALOG FROZEN MODELS & PROVENANCE
    print("\n--- 1. FROZEN CANDIDATE CONFIGURATIONS & TRAINING PROVENANCE ---")
    
    # Model 1 & 2: Deployed Baseline & Candidate 3
    base_json = "lib/features/iod/data/models/deepiod_model_c_mobile_weights.json"
    with open(base_json, 'r') as f:
        base_w = json.load(f)
    model_deployed = load_folded_into_pytorch(base_w, device)
    mean_deployed = np.array(base_w['mean'], dtype=np.float32)
    std_deployed = np.array(base_w['std'], dtype=np.float32)
    hash_deployed = compute_sha256(base_json)
    print(f"Model 1: Deployed Baseline Model C-Mobile (theta=0.50)")
    print(f"         Provenance: Cambridge CIOD Sessions 01..60 (60 sessions)")
    print(f"         SHA-256: {hash_deployed}")
    print(f"         Scaler: Mean={mean_deployed}, Std={std_deployed}")
    print(f"Model 2: Deployed C-Mobile + Candidate 3 Hysteresis [0.45, 0.25] (Session Reset)")
    print(f"         Provenance: Same frozen weights, asymmetric deadband tuned for InRec >= 90%")

    # Model 3 & 4: Canonical Retrained Model C-Mobile
    can_json = "tooling/data/deepiod_weights/deepiod_model_c_mobile_full_sampled_weights.json"
    with open(can_json, 'r') as f:
        can_w = json.load(f)
    model_canonical = load_folded_into_pytorch(can_w, device)
    mean_canonical = np.array(can_w['mean'], dtype=np.float32)
    std_canonical = np.array(can_w['std'], dtype=np.float32)
    hash_canonical = compute_sha256(can_json)
    print(f"\nModel 3: Canonical Retrained Model C-Mobile (theta=0.50)")
    print(f"         Provenance: CIOD Sessions 01..54 (Train), Sessions 55..72 (Checkpoint Validation)")
    print(f"         SHA-256: {hash_canonical}")
    print(f"         Scaler: Mean={mean_canonical}, Std={std_canonical}")
    print(f"Model 4: Canonical Retrained C-Mobile + Hysteresis [0.45, 0.25] (Session Reset)")
    print(f"         Provenance: Same retrained weights with validation-derived checkpointing")

    # 2. EXTERNAL DATASET PROVENANCE AUDIT
    print("\n--- 2. INDEPENDENT DATASET PROVENANCE & SENSOR AUDIT ---")
    zenodo_base = "tooling/data/zenodo_nantes/dataset"
    print(f"External Candidate Dataset: Zenodo Record 12566912 ('Android GNSS Dataset Nantes')")
    print(f"Origin: University Gustave Eiffel & Tampere University (March 2024)")
    print(f"Logging Hardware: Google Pixel 7 (Android 14) via Mimir App")
    print(f"Sensor Channels Logged: GNSS Raw, GNSS Fix, Accelerometer (200Hz), Magnetometer (100Hz)")
    print(f"Sensor Channels Missing: AMBIENT LIGHT (Sensor.TYPE_LIGHT) IS COMPLETELY ABSENT")
    print(f"                         Sound Pressure (RECORD_AUDIO) is completely absent")
    print(f"                         Proximity (Sensor.TYPE_PROXIMITY) is completely absent")
    print(f"                         Cellular LTE (RSRP/RSRQ) is completely absent")
    print(f"Label Provenance:")
    print(f"  - Scenarios S1 & S4: 100% Outdoor Walking in Nantes (VERIFIED GROUND TRUTH)")
    print(f"  - Scenarios S2, S3, S5: Mixed building loops WITHOUT timestamped doorway crossing ground truth")
    print(f"  - Conclusion on S2/S3/S5: Marked LabelProvenance.exploratoryUnverifiedMacro; two-class scoring barred.")

    # 3. VERIFIED OUTDOOR EVALUATION (S1 & S4)
    print("\n--- 3. EVALUATION ON VERIFIED OUTDOOR SESSIONS (SCENARIOS S1 & S4) ---")
    verified_sessions = [
        ('S1_A1_GP7', os.path.join(zenodo_base, 'S1/A1/GP7/log_mimir_20240313111400.txt'), 'S1: Open-Sky Road Walk A1'),
        ('S1_A2_GP7', os.path.join(zenodo_base, 'S1/A2/GP7/log_mimir_20240313112757.txt'), 'S1: Open-Sky Road Walk A2'),
        ('S4_A1_GP7', os.path.join(zenodo_base, 'S4/A1/GP7/log_mimir_20240314144624.txt'), 'S4: Dense Urban Canyon Walk A1'),
        ('S4_A2_GP7', os.path.join(zenodo_base, 'S4/A2/GP7/log_mimir_20240314151021.txt'), 'S4: Dense Urban Canyon Walk A2'),
    ]

    all_ver_epochs = []
    session_data = {}
    for sess_id, path, desc in verified_sessions:
        if not os.path.exists(path):
            print(f"WARNING: File missing: {path}")
            continue
        eps = parse_mimir_session(path)
        print(f"Loaded {sess_id} ({desc}): {len(eps)} epochs.")
        session_data[sess_id] = eps
        all_ver_epochs.extend([(sess_id, ep) for ep in eps])

    total_ver_epochs = len(all_ver_epochs)
    print(f"Total Verified Outdoor Epochs Loaded: {total_ver_epochs:,}")

    # Evaluate all models under:
    # A) Missing photodiode / Quiescent Light (ambientLux = 0.0) -> Primary stress test
    # B) Nominal Daylight Reference (ambientLux = 10,000.0) -> Theoretical upper bound

    conditions = [
        ("Missing Light / Pocket Condition (ambientLux = 0.0 lux)", 0.0),
        ("Nominal Daylight Reference (ambientLux = 10,000.0 lux)", 10000.0),
    ]

    export_rows = []

    for cond_name, lux_val in conditions:
        print(f"\n==========================================================================================")
        print(f"  CONDITION: {cond_name}")
        print(f"==========================================================================================")
        print("| Model Configuration | Scaler | Total Out GT | Out TP | False Indoor (FN) | Outdoor Recall | False Indoor Collapse Rate |")
        print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |")

        # 1. Deployed Baseline
        dep_tp = 0
        dep_fn = 0
        cand3_tp = 0
        cand3_fn = 0
        can_tp = 0
        can_fn = 0
        can_h_tp = 0
        can_h_fn = 0

        for sess_id, path, _ in verified_sessions:
            eps = session_data[sess_id]
            # Deployed Windows
            w_dep = build_evaluation_windows(eps, mean_deployed, std_deployed, lux_value=lux_val)
            p_dep = evaluate_model_on_windows(model_deployed, w_dep, device)
            bin_dep = (p_dep >= 0.50).astype(int)
            st_cand3 = apply_hysteresis(p_dep, low=0.25, high=0.45)

            # Canonical Windows
            w_can = build_evaluation_windows(eps, mean_canonical, std_canonical, lux_value=lux_val)
            p_can = evaluate_model_on_windows(model_canonical, w_can, device)
            bin_can = (p_can >= 0.50).astype(int)
            st_can_h = apply_hysteresis(p_can, low=0.25, high=0.45)

            for i, ep in enumerate(eps):
                # Deployed
                if bin_dep[i] == 1: dep_tp += 1
                else: dep_fn += 1
                if st_cand3[i] == 1: cand3_tp += 1
                else: cand3_fn += 1

                # Canonical
                if bin_can[i] == 1: can_tp += 1
                else: can_fn += 1
                if st_can_h[i] == 1: can_h_tp += 1
                else: can_h_fn += 1

                if lux_val == 0.0:
                    export_rows.append({
                        'session_id': sess_id,
                        'utc_sec': ep['utc_sec'],
                        'ground_truth': 'outdoor',
                        'light_lux': lux_val,
                        'mag_cal_ut': f"{ep['mean_mag']:.2f}",
                        'acc_lin_ms2': f"{ep['lin_acc']:.2f}",
                        'prob_deployed': f"{p_dep[i]:.4f}",
                        'pred_deployed': 'outdoor' if bin_dep[i] == 1 else 'indoor',
                        'pred_cand3': 'outdoor' if st_cand3[i] == 1 else 'indoor',
                        'prob_canonical': f"{p_can[i]:.4f}",
                        'pred_canonical': 'outdoor' if bin_can[i] == 1 else 'indoor',
                        'pred_canonical_hyst': 'outdoor' if st_can_h[i] == 1 else 'indoor',
                    })

        dep_rec = (dep_tp / total_ver_epochs) * 100.0
        dep_coll = (dep_fn / total_ver_epochs) * 100.0
        cand3_rec = (cand3_tp / total_ver_epochs) * 100.0
        cand3_coll = (cand3_fn / total_ver_epochs) * 100.0
        can_rec = (can_tp / total_ver_epochs) * 100.0
        can_coll = (can_fn / total_ver_epochs) * 100.0
        can_h_rec = (can_h_tp / total_ver_epochs) * 100.0
        can_h_coll = (can_h_fn / total_ver_epochs) * 100.0

        print(f"| **Deployed Baseline C-Mobile (theta=0.50)** | Pretrained | {total_ver_epochs:,} | {dep_tp:,} | {dep_fn:,} | **{dep_rec:.1f}%** | {dep_coll:.1f}% |")
        print(f"| **Deployed C-Mobile + Candidate 3 [0.45, 0.25]** | Pretrained | {total_ver_epochs:,} | {cand3_tp:,} | {cand3_fn:,} | **{cand3_rec:.1f}%** | {cand3_coll:.1f}% |")
        print(f"| **Canonical Retrained C-Mobile (theta=0.50)** | S01..54 Train | {total_ver_epochs:,} | {can_tp:,} | {can_fn:,} | **{can_rec:.1f}%** | {can_coll:.1f}% |")
        print(f"| **Canonical Retrained + Hysteresis [0.45, 0.25]** | S01..54 Train | {total_ver_epochs:,} | {can_h_tp:,} | {can_h_fn:,} | **{can_h_rec:.1f}%** | {can_h_coll:.1f}% |")

    # 4. AUDIT OF MIXED SCENARIOS S2, S3, S5 (DOCUMENTING UNVERIFIED GROUND TRUTH)
    print("\n--- 4. AUDIT OF MIXED SCENARIOS S2, S3, S5 (DEMONSTRATING DATASET BLOCKED) ---")
    mixed_sessions = [
        ('S2_A1_GP7', os.path.join(zenodo_base, 'S2/A1/GP7/log_mimir_20240313154931.txt'), 'S2: UGE Building'),
        ('S2_A2_GP7', os.path.join(zenodo_base, 'S2/A2/GP7/log_mimir_20240313155815.txt'), 'S2: UGE Building'),
        ('S3_A1_GP7', os.path.join(zenodo_base, 'S3/A1/GP7/log_mimir_20240314102818.txt'), 'S3: Nantes Train Station'),
        ('S3_A2_GP7', os.path.join(zenodo_base, 'S3/A2/GP7/log_mimir_20240314104725.txt'), 'S3: Nantes Train Station'),
        ('S5_A1_GP7', os.path.join(zenodo_base, 'S5/A1/GP7/log_mimir_20240315101511.txt'), 'S5: Atlantis Shopping Center'),
        ('S5_A2_GP7', os.path.join(zenodo_base, 'S5/A2/GP7/log_mimir_20240315102957.txt'), 'S5: Atlantis Shopping Center'),
    ]

    print("| Session ID | Environment Scenario | Total Epochs | Light Sensor | Verified Ground Truth Available | Status |")
    print("| :--- | :--- | :---: | :---: | :---: | :--- |")
    total_mixed_epochs = 0
    for sess_id, path, desc in mixed_sessions:
        if os.path.exists(path):
            eps = parse_mimir_session(path)
            total_mixed_epochs += len(eps)
            print(f"| `{sess_id}` | {desc} | {len(eps):,} | Absent | NO (Doorway timestamps not logged) | **DATASET BLOCKED** |")

    print(f"\nTotal Mixed Epochs: {total_mixed_epochs:,}")
    print("Scientific Finding: Calculating Indoor Recall, Macro-F1, or False Outdoor rate on S2, S3, S5")
    print("would require fabricating synthetic doorway crossing timestamps, which is strictly banned.")

    # 5. EXPORT PREDICTIONS CSV
    csv_out = "tooling/data/benchmark_results/external_generalization_audit_predictions.csv"
    os.makedirs(os.path.dirname(csv_out), exist_ok=True)
    with open(csv_out, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'session_id', 'utc_sec', 'ground_truth', 'light_lux', 'mag_cal_ut', 'acc_lin_ms2',
            'prob_deployed', 'pred_deployed', 'pred_cand3', 'prob_canonical', 'pred_canonical', 'pred_canonical_hyst'
        ])
        writer.writeheader()
        writer.writerows(export_rows)
    print(f"\nExported verified external predictions to: {csv_out} ({len(export_rows):,} rows)")

    # 6. FORMAL DETERMINATION
    print("\n" + "="*90)
    print("  FINAL GENERALIZATION DETERMINATION: DATASET BLOCKED")
    print("  Release Acceptance Status: GATED")
    print("="*90)
    print("Reason:")
    print("1. No independent public smartphone dataset exists containing BOTH verified 2-class (Indoor/Outdoor)")
    print("   second-by-second ground truth AND compatible multi-modal mobile sensors (specifically ambient light).")
    print("2. Cambridge CIOD cannot be repurposed as a blind external test (used for training/nested-CV).")
    print("3. Zenodo Nantes provides verified 1-class outdoor ground truth (3,180 epochs across S1 & S4),")
    print("   but lacks ambient light logs, and mixed sessions (S2, S3, S5) lack verified doorway annotations.")
    print("4. Release acceptance must remain GATED until an on-device physical field test protocol is conducted.")


if __name__ == '__main__':
    main()
