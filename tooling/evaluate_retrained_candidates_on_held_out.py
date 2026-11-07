#!/usr/bin/env python3
"""
Evaluate Retrained Candidates and Hysteresis on Untouched Full Held-Out Test Set (201,731 Epochs).
Preserves untouched held-out test sessions (72..84) with 0 train/val leakage.
Exports full per-sample predictions for independent python verification.
"""

import csv
import json
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset

from train_val_experiments import (
    ModelC_DepthwiseSeparableCnn,
    CiodSessionDataset,
    load_raw_ciod,
    build_mobile_windows,
    train_candidate,
    compute_metrics,
)

def fold_model_c_weights(model: nn.Module, mean_mob: np.ndarray, std_mob: np.ndarray) -> dict:
    model.eval()
    with torch.no_grad():
        gamma1 = model.bn1.weight.cpu().numpy()
        beta1 = model.bn1.bias.cpu().numpy()
        mean1 = model.bn1.running_mean.cpu().numpy()
        var1 = model.bn1.running_var.cpu().numpy()
        eps1 = model.bn1.eps
        scale1 = gamma1 / np.sqrt(var1 + eps1)

        w1_point = model.dws1_point.weight.cpu().numpy().squeeze()
        b1_point = model.dws1_point.bias.cpu().numpy() if model.dws1_point.bias is not None else np.zeros(32)
        w1_point_folded = w1_point * scale1
        b1_point_folded = (b1_point - mean1) * scale1 + beta1

        gamma2 = model.bn2.weight.cpu().numpy()
        beta2 = model.bn2.bias.cpu().numpy()
        mean2 = model.bn2.running_mean.cpu().numpy()
        var2 = model.bn2.running_var.cpu().numpy()
        eps2 = model.bn2.eps
        scale2 = gamma2 / np.sqrt(var2 + eps2)

        w2_point = model.dws2_point.weight.cpu().numpy().squeeze()
        b2_point = model.dws2_point.bias.cpu().numpy() if model.dws2_point.bias is not None else np.zeros(32)
        w2_point_folded = w2_point * scale2[:, None]
        b2_point_folded = (b2_point - mean2) * scale2 + beta2

        return {
            'dws1_depth_w': model.dws1_depth.weight.cpu().numpy().squeeze().tolist(),
            'dws1_depth_b': float(model.dws1_depth.bias.cpu().numpy()[0]),
            'dws1_point_w': w1_point_folded.tolist(),
            'dws1_point_b': b1_point_folded.tolist(),
            'dws2_depth_w': model.dws2_depth.weight.cpu().numpy().squeeze().tolist(),
            'dws2_depth_b': model.dws2_depth.bias.cpu().numpy().tolist(),
            'dws2_point_w': w2_point_folded.tolist(),
            'dws2_point_b': b2_point_folded.tolist(),
            'dense1_w': model.dense1.weight.cpu().numpy().tolist(),
            'dense1_b': model.dense1.bias.cpu().numpy().tolist(),
            'out_w': model.out.weight.cpu().numpy().squeeze().tolist(),
            'out_b': float(model.out.bias.cpu().numpy()[0]),
            'mean': mean_mob.tolist(),
            'std': std_mob.tolist(),
            'feature_names': ['Light', 'Mag', 'Acc', 'Daytime'],
        }


def make_full_test_windows(test_sessions, mean_mob, std_mob, window_size=10):
    mob_indices = [2, 3, 4, 7]
    all_windows = []
    all_labels = []
    all_session_names = []

    for s_idx, s in enumerate(test_sessions):
        sess_name = f"CIOD_session_{73 + s_idx}"
        raw = s['features'][:, mob_indices]
        norm = (raw - mean_mob) / std_mob
        lbls = s['labels']
        n = len(norm)
        
        # Mirror Dart rolling window with prefix-replication padding for first 9 steps
        history = []
        for i in range(n):
            history.append(norm[i])
            if len(history) > window_size:
                history.pop(0)

            # Pad prefix if fewer than window_size
            eval_win = []
            while len(eval_win) + len(history) < window_size:
                eval_win.append(history[0])
            eval_win.extend(history)

            all_windows.append(np.array(eval_win, dtype=np.float32))
            all_labels.append(lbls[i])
            all_session_names.append(sess_name)

    return np.array(all_windows, dtype=np.float32), np.array(all_labels, dtype=np.float32), all_session_names


def main():
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print(f"Using compute device: {device}")

    ciod_path = "tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv"
    sessions = load_raw_ciod(ciod_path)

    train_sessions = sessions[:60]
    val_sessions = sessions[60:72]
    test_sessions = sessions[72:85]

    mob_indices = [2, 3, 4, 7]
    all_train_raw = np.concatenate([s['features'][:, mob_indices] for s in train_sessions], axis=0)
    mean_mob = np.mean(all_train_raw, axis=0)
    std_mob = np.std(all_train_raw, axis=0)
    std_mob[std_mob < 1e-6] = 1.0

    # Build full test windows (all 201,731 samples)
    print("\nBuilding full uncapped test windows (Sessions 72..84, stride=1)...")
    X_test_full, y_test_full, sess_names_test = make_full_test_windows(test_sessions, mean_mob, std_mob, window_size=10)
    print(f"Full Test Set Loaded: {len(X_test_full):,} windows across {len(set(sess_names_test))} sessions.")

    # 1. Train Weighted BCE Model on Train Set (Sessions 00..59)
    print("\nTraining Weighted BCE Model (pos_weight=1.5) on Train Sessions...")
    X_train, y_train, ids_train = build_mobile_windows(train_sessions, mean_mob, std_mob, max_windows=800)
    X_val, y_val, ids_val = build_mobile_windows(val_sessions, mean_mob, std_mob, max_windows=800)

    train_ds = CiodSessionDataset(X_train, y_train, ids_train)
    val_ds = CiodSessionDataset(X_val, y_val, ids_val)
    train_loader = DataLoader(train_ds, batch_size=64, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=64, shuffle=False)

    torch.manual_seed(42)
    model_weighted = ModelC_DepthwiseSeparableCnn()
    model_weighted, _, _, _ = train_candidate(
        model_weighted, train_loader, val_loader, loss_type='weighted_bce', pos_weight_val=1.5, epochs=12, device=device, label="Weighted BCE (pos_weight=1.5)"
    )

    # Fold and save weights
    folded_w = fold_model_c_weights(model_weighted, mean_mob, std_mob)
    out_weights_path = "tooling/data/deepiod_weights/deepiod_model_c_mobile_weighted_bce_weights.json"
    with open(out_weights_path, 'w') as f:
        json.dump(folded_w, f)
    print(f"Exported folded weighted BCE weights to: {out_weights_path}")

    # Predict on Full Held-Out Test Set
    test_ds = CiodSessionDataset(X_test_full, y_test_full, [0] * len(y_test_full))
    test_loader = DataLoader(test_ds, batch_size=128, shuffle=False)

    model_weighted.eval()
    test_probs = []
    with torch.no_grad():
        for x_b, _ in test_loader:
            x_b = x_b.to(device)
            p = model_weighted(x_b)
            test_probs.extend(p.cpu().numpy().flatten())
    test_probs = np.array(test_probs, dtype=np.float32)

    # Also load baseline Model C-Mobile predictions for direct comparison
    baseline_pred_csv = "tooling/data/benchmark_results/ciod_full_held_out_mobile_predictions.csv"
    baseline_probs = []
    with open(baseline_pred_csv, 'r') as f:
        reader = csv.DictReader(f)
        for r in reader:
            baseline_probs.append(float(r['deepiod_outdoor_score']))
    baseline_probs = np.array(baseline_probs, dtype=np.float32)

    # Evaluate multiple candidate strategies on Full Held-Out Test Set
    candidates = {}

    # 1. Baseline C-Mobile (theta=0.50)
    candidates['Baseline C-Mobile (theta=0.50)'] = compute_metrics(y_test_full, baseline_probs, threshold=0.50)

    # 2. Baseline C-Mobile Calibrated (theta=0.25)
    candidates['Baseline C-Mobile Calibrated (theta=0.25)'] = compute_metrics(y_test_full, baseline_probs, threshold=0.25)

    # 3. Baseline C-Mobile Hysteresis [0.40, 0.20]
    def apply_h(probs, low=0.20, high=0.40):
        states = []
        cur = 0
        for p in probs:
            if cur == 0 and p >= high:
                cur = 1
            elif cur == 1 and p < low:
                cur = 0
            states.append(cur)
        return np.array(states, dtype=int)

    h_baseline = apply_h(baseline_probs, low=0.20, high=0.40)
    tp = int(np.sum((y_test_full == 1) & (h_baseline == 1)))
    tn = int(np.sum((y_test_full == 0) & (h_baseline == 0)))
    fp = int(np.sum((y_test_full == 0) & (h_baseline == 1)))
    fn = int(np.sum((y_test_full == 1) & (h_baseline == 0)))
    p_out = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    r_out = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1_out = 2 * (p_out * r_out) / (p_out + r_out) if (p_out + r_out) > 0 else 0.0
    p_in = tn / (tn + fn) if (tn + fn) > 0 else 0.0
    r_in = tn / (tn + fp) if (tn + fp) > 0 else 0.0
    f1_in = 2 * (p_in * r_in) / (p_in + r_in) if (p_in + r_in) > 0 else 0.0
    candidates['Baseline C-Mobile Hysteresis [0.40, 0.20]'] = {
        'total': len(y_test_full),
        'accuracy': (tp + tn) / len(y_test_full),
        'macro_f1': (f1_out + f1_in) / 2.0,
        'precision_out': p_out,
        'recall_out': r_out,
        'f1_out': f1_out,
        'precision_in': p_in,
        'recall_in': r_in,
        'f1_in': f1_in,
        'tp': tp, 'tn': tn, 'fp': fp, 'fn': fn,
    }

    # 4. Retrained Weighted BCE (theta=0.50)
    candidates['Retrained Weighted BCE (theta=0.50)'] = compute_metrics(y_test_full, test_probs, threshold=0.50)

    # 5. Retrained Weighted BCE Calibrated (theta=0.35)
    candidates['Retrained Weighted BCE (theta=0.35)'] = compute_metrics(y_test_full, test_probs, threshold=0.35)

    # 6. Retrained Weighted BCE Hysteresis [0.45, 0.25]
    h_weighted = apply_h(test_probs, low=0.25, high=0.45)
    tp_w = int(np.sum((y_test_full == 1) & (h_weighted == 1)))
    tn_w = int(np.sum((y_test_full == 0) & (h_weighted == 0)))
    fp_w = int(np.sum((y_test_full == 0) & (h_weighted == 1)))
    fn_w = int(np.sum((y_test_full == 1) & (h_weighted == 0)))
    p_out_w = tp_w / (tp_w + fp_w) if (tp_w + fp_w) > 0 else 0.0
    r_out_w = tp_w / (tp_w + fn_w) if (tp_w + fn_w) > 0 else 0.0
    f1_out_w = 2 * (p_out_w * r_out_w) / (p_out_w + r_out_w) if (p_out_w + r_out_w) > 0 else 0.0
    p_in_w = tn_w / (tn_w + fn_w) if (tn_w + fn_w) > 0 else 0.0
    r_in_w = tn_w / (tn_w + fp_w) if (tn_w + fp_w) > 0 else 0.0
    f1_in_w = 2 * (p_in_w * r_in_w) / (p_in_w + r_in_w) if (p_in_w + r_in_w) > 0 else 0.0
    candidates['Retrained Weighted BCE Hysteresis [0.45, 0.25]'] = {
        'total': len(y_test_full),
        'accuracy': (tp_w + tn_w) / len(y_test_full),
        'macro_f1': (f1_out_w + f1_in_w) / 2.0,
        'precision_out': p_out_w,
        'recall_out': r_out_w,
        'f1_out': f1_out_w,
        'precision_in': p_in_w,
        'recall_in': r_in_w,
        'f1_in': f1_in_w,
        'tp': tp_w, 'tn': tn_w, 'fp': fp_w, 'fn': fn_w,
    }

    print("\n" + "=" * 105)
    print("      HELD-OUT TEST GENERALIZATION EVALUATION (ALL 201,731 EPOCHS, SESSIONS 72..84)")
    print("=" * 105)
    print("| Candidate Strategy / Model | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Outdoor Prec | Outdoor F1 | Indoor Prec |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    for name, m in candidates.items():
        print(
            f"| **{name}** | **{m['accuracy']*100:.2f}%** | **{m['macro_f1']*100:.2f}%** | "
            f"{m['recall_in']*100:.1f}% | {m['recall_out']*100:.1f}% | "
            f"{m['precision_out']*100:.1f}% | {m['f1_out']*100:.1f}% | {m['precision_in']*100:.1f}% |"
        )

    # Export Retrained Weighted BCE Predictions to CSV for independent verifier
    out_csv = "tooling/data/benchmark_results/ciod_full_held_out_mobile_weighted_bce_predictions.csv"
    with open(out_csv, 'w', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['session_id', 'ground_truth', 'predicted_state', 'class_probability', 'model_version'])
        for s_name, y_true, prob in zip(sess_names_test, y_test_full, test_probs):
            gt_str = 'outdoor' if y_true == 1.0 else 'indoor'
            pred_str = 'outdoor' if prob >= 0.50 else 'indoor'
            writer.writerow([s_name, gt_str, pred_str, f"{prob:.4f}", 'deepiod-neural-c-mobile-weighted-bce-v1.0'])

    print(f"\nExported {len(test_probs):,} predictions to: {out_csv}")


if __name__ == '__main__':
    main()
