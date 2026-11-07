#!/usr/bin/env python3
"""
Aetron IOD Training & Validation Study Pipeline
Branch: ekf

Strict Split Discipline:
- Train Sessions: 00..59 (Sessions 1..60)
- Validation Sessions: 60..71 (Sessions 61..72)
- Held-Out Test Sessions: 72..84 (Sessions 73..85) -> UNTOUCHED during model selection!

Evaluates:
1. Class-Balanced Training (WeightedRandomSampler)
2. Weighted BCE Loss (pos_weight > 1.0)
3. Focal Loss (Lin et al. 2017: gamma=2.0, alpha=0.65)
4. Online Hard Example Mining (OHEM - Hard-Negative & Hard-Positive Mining)
5. Sensor Feature Ablations on 4-channel space
6. Post-hoc Calibration & Temporal Hysteresis
"""

import argparse
import csv
import json
import math
import os
import sys
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

# Model C Architecture as defined in reproduce_deepiod.py
class ModelC_DepthwiseSeparableCnn(nn.Module):
    def __init__(self, in_features: int = 4):
        super().__init__()
        self.in_features = in_features
        # Layer 1: DWS-Conv2D (3x3)
        self.dws1_depth = nn.Conv2d(1, 1, kernel_size=3, padding=1, bias=True)
        self.relu1_d = nn.ReLU()
        # Layer 2: Conv2D (32, 1x1)
        self.dws1_point = nn.Conv2d(1, 32, kernel_size=1, bias=True)
        self.bn1 = nn.BatchNorm2d(32)
        self.relu1_p = nn.ReLU()

        # Layer 3: DWS-Conv2D (3x3)
        self.dws2_depth = nn.Conv2d(32, 32, kernel_size=3, padding=1, groups=32, bias=True)
        self.relu2_d = nn.ReLU()
        # Layer 4: Conv2D (32, 1x1)
        self.dws2_point = nn.Conv2d(32, 32, kernel_size=1, bias=True)
        self.bn2 = nn.BatchNorm2d(32)
        self.relu2_p = nn.ReLU()

        # Layer 5: MaxPool (2x1)
        self.maxpool = nn.MaxPool2d(kernel_size=(2, 1))

        # Global average pooling
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
        out = self.sigmoid(self.out(h))
        return out


# Focal Loss for Binary Classification
class BinaryFocalLoss(nn.Module):
    def __init__(self, alpha: float = 0.65, gamma: float = 2.0):
        super().__init__()
        self.alpha = alpha
        self.gamma = gamma
        self.eps = 1e-7

    def forward(self, preds: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        preds = preds.clamp(self.eps, 1.0 - self.eps)
        # pt = p if y=1 else (1 - p)
        pt = torch.where(targets == 1.0, preds, 1.0 - preds)
        alpha_t = torch.where(targets == 1.0, self.alpha, 1.0 - self.alpha)
        loss = -alpha_t * torch.pow(1.0 - pt, self.gamma) * torch.log(pt)
        return loss.mean()


class CiodSessionDataset(Dataset):
    def __init__(self, windows: np.ndarray, labels: np.ndarray, session_ids: List[int]):
        self.windows = torch.tensor(windows, dtype=torch.float32)
        self.labels = torch.tensor(labels, dtype=torch.float32).unsqueeze(1)
        self.session_ids = session_ids

    def __len__(self):
        return len(self.windows)

    def __getitem__(self, idx):
        return self.windows[idx], self.labels[idx]


def compute_metrics(y_true: np.ndarray, y_pred_prob: np.ndarray, threshold: float = 0.50) -> Dict[str, float]:
    y_pred_bin = (y_pred_prob >= threshold).astype(int)
    y_true_int = y_true.astype(int)

    tp = int(np.sum((y_true_int == 1) & (y_pred_bin == 1)))
    tn = int(np.sum((y_true_int == 0) & (y_pred_bin == 0)))
    fp = int(np.sum((y_true_int == 0) & (y_pred_bin == 1)))
    fn = int(np.sum((y_true_int == 1) & (y_pred_bin == 0)))

    total = len(y_true)
    accuracy = (tp + tn) / total if total > 0 else 0.0

    p_out = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    r_out = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1_out = 2 * (p_out * r_out) / (p_out + r_out) if (p_out + r_out) > 0 else 0.0

    p_in = tn / (tn + fn) if (tn + fn) > 0 else 0.0
    r_in = tn / (tn + fp) if (tn + fp) > 0 else 0.0
    f1_in = 2 * (p_in * r_in) / (p_in + r_in) if (p_in + r_in) > 0 else 0.0

    macro_f1 = (f1_out + f1_in) / 2.0

    return {
        'total': total,
        'accuracy': accuracy,
        'macro_f1': macro_f1,
        'precision_out': p_out,
        'recall_out': r_out,
        'f1_out': f1_out,
        'precision_in': p_in,
        'recall_in': r_in,
        'f1_in': f1_in,
        'tp': tp,
        'tn': tn,
        'fp': fp,
        'fn': fn,
    }


def load_raw_ciod(csv_path: str):
    print(f"Loading raw CIOD dataset from: {csv_path}")
    sessions = []
    current_features = []
    current_labels = []

    # Features: ['RSRP', 'RSRQ', 'Light', 'Mag', 'Acc', 'Sound', 'Proximity', 'Daytime']
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['New_Recording'].strip() == '1' and len(current_features) > 0:
                sessions.append({
                    'features': np.array(current_features, dtype=np.float32),
                    'labels': np.array(current_labels, dtype=np.float32),
                })
                current_features = []
                current_labels = []

            feats = [
                float(row['RSRP']),
                float(row['RSRQ']),
                float(row['Light']),
                float(row['Mag']),
                float(row['Acc']),
                float(row['Sound']),
                float(row['Proximity']),
                float(row['Daytime']),
            ]
            io_val = float(row['IO'])
            y = 1.0 if io_val == 0.0 else 0.0 # 1.0 = Outdoor

            current_features.append(feats)
            current_labels.append(y)

    if len(current_features) > 0:
        sessions.append({
            'features': np.array(current_features, dtype=np.float32),
            'labels': np.array(current_labels, dtype=np.float32),
        })

    print(f"Loaded {len(sessions)} total recording sessions.")
    return sessions


def build_mobile_windows(sessions, mean_mob, std_mob, window_size=10, stride=2, max_windows=800):
    mob_indices = [2, 3, 4, 7] # Light, Mag, Acc, Daytime
    all_windows = []
    all_labels = []
    all_ids = []

    for s_idx, s in enumerate(sessions):
        raw = s['features'][:, mob_indices]
        norm = (raw - mean_mob) / std_mob
        lbls = s['labels']
        n = len(norm)
        if n < window_size:
            continue
        count = 0
        for i in range(0, n - window_size + 1, stride):
            all_windows.append(norm[i : i + window_size])
            all_labels.append(lbls[i + window_size - 1])
            all_ids.append(s_idx)
            count += 1
            if max_windows > 0 and count >= max_windows:
                break

    return np.array(all_windows, dtype=np.float32), np.array(all_labels, dtype=np.float32), all_ids


def train_candidate(
    model: nn.Module,
    train_loader: DataLoader,
    val_loader: DataLoader,
    loss_type: str = 'bce', # 'bce', 'weighted_bce', 'focal', 'ohem'
    pos_weight_val: float = 1.0,
    epochs: int = 12,
    lr: float = 0.001,
    patience: int = 4,
    device: torch.device = torch.device('cpu'),
    label: str = 'Model',
) -> Tuple[nn.Module, float, np.ndarray, np.ndarray]:
    model.to(device)
    optimizer = optim.Adam(model.parameters(), lr=lr)

    if loss_type == 'focal':
        criterion = BinaryFocalLoss(alpha=0.65, gamma=2.0)
    elif loss_type == 'weighted_bce':
        pw = torch.tensor([pos_weight_val], dtype=torch.float32).to(device)
        criterion = nn.BCEWithLogitsLoss(pos_weight=pw)
    else:
        criterion = nn.BCELoss()

    best_val_loss = float('inf')
    best_weights = None
    epochs_no_imp = 0

    print(f"\n--- Training {label} (Loss={loss_type}, Epochs={epochs}, LR={lr}) ---")
    for epoch in range(1, epochs + 1):
        model.train()
        train_loss = 0.0
        for x_b, y_b in train_loader:
            x_b, y_b = x_b.to(device), y_b.to(device)
            optimizer.zero_grad()

            if loss_type == 'weighted_bce':
                # Use raw logit before sigmoid
                if x_b.dim() == 3:
                    h = x_b.unsqueeze(1)
                else:
                    h = x_b
                h = model.relu1_d(model.dws1_depth(h))
                h = model.relu1_p(model.bn1(model.dws1_point(h)))
                h = model.relu2_d(model.dws2_depth(h))
                h = model.relu2_p(model.bn2(model.dws2_point(h)))
                h = model.maxpool(h)
                h = model.pool(h).squeeze(-1).squeeze(-1)
                h = model.relu_dense(model.dense1(h))
                logits = model.out(h)
                loss = criterion(logits, y_b)
            elif loss_type == 'ohem':
                preds = model(x_b)
                # Online Hard Example Mining: compute per-element BCE, keep top 50%
                bce_elem = nn.functional.binary_cross_entropy(preds, y_b, reduction='none')
                k = max(1, int(len(bce_elem) * 0.5))
                topk_loss, _ = torch.topk(bce_elem.squeeze(), k)
                loss = topk_loss.mean()
            else:
                preds = model(x_b)
                loss = criterion(preds, y_b)

            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(x_b)

        train_loss /= len(train_loader.dataset)

        # Validation Loss
        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for x_b, y_b in val_loader:
                x_b, y_b = x_b.to(device), y_b.to(device)
                preds = model(x_b)
                v_loss = nn.functional.binary_cross_entropy(preds, y_b)
                val_loss += v_loss.item() * len(x_b)
        val_loss /= len(val_loader.dataset)

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_weights = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            epochs_no_imp = 0
        else:
            epochs_no_imp += 1
            if epochs_no_imp >= patience:
                print(f"  Early stopped at epoch {epoch} (Best Val Loss: {best_val_loss:.4f})")
                break

    if best_weights is not None:
        model.load_state_dict(best_weights)

    # Compute validation predictions
    model.eval()
    val_preds = []
    val_targets = []
    with torch.no_grad():
        for x_b, y_b in val_loader:
            x_b = x_b.to(device)
            p = model(x_b)
            val_preds.extend(p.cpu().numpy().flatten())
            val_targets.extend(y_b.numpy().flatten())

    val_preds_arr = np.array(val_preds, dtype=np.float32)
    val_targets_arr = np.array(val_targets, dtype=np.float32)
    m = compute_metrics(val_targets_arr, val_preds_arr, threshold=0.50)
    print(f"  Validation Result: Acc={m['accuracy']*100:.2f}%, Macro-F1={m['macro_f1']*100:.2f}%, OutRec={m['recall_out']*100:.1f}%, InRec={m['recall_in']*100:.1f}%")
    return model, best_val_loss, val_preds_arr, val_targets_arr


def main():
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print(f"Using compute device: {device}")

    ciod_path = "tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv"
    sessions = load_raw_ciod(ciod_path)

    # Strict isolation:
    # Train: 00..59 (Sessions 1..60)
    # Val:   60..71 (Sessions 61..72)
    # Test:  72..84 (Sessions 73..85) -> NEVER TOUCHED IN THIS SCRIPT!
    train_sessions = sessions[:60]
    val_sessions = sessions[60:72]
    test_sessions = sessions[72:85]

    print(f"Partition Counts: Train={len(train_sessions)}, Val={len(val_sessions)}, Held-Out Test={len(test_sessions)}")

    # Compute scaler strictly on Train Sessions
    mob_indices = [2, 3, 4, 7]
    all_train_raw = np.concatenate([s['features'][:, mob_indices] for s in train_sessions], axis=0)
    mean_mob = np.mean(all_train_raw, axis=0)
    std_mob = np.std(all_train_raw, axis=0)
    std_mob[std_mob < 1e-6] = 1.0

    print(f"Train Scaler Mean: {mean_mob}")
    print(f"Train Scaler Std:  {std_mob}")

    # Build windows for train and val
    X_train, y_train, ids_train = build_mobile_windows(train_sessions, mean_mob, std_mob, max_windows=800)
    X_val, y_val, ids_val = build_mobile_windows(val_sessions, mean_mob, std_mob, max_windows=800)

    n_train_out = int(y_train.sum())
    n_train_in = int(len(y_train) - n_train_out)
    n_val_out = int(y_val.sum())
    n_val_in = int(len(y_val) - n_val_out)

    print(f"Train Windows: Total={len(y_train):,}, Outdoor={n_train_out:,} ({n_train_out/len(y_train)*100:.1f}%), Indoor={n_train_in:,} ({n_train_in/len(y_train)*100:.1f}%)")
    print(f"Val Windows:   Total={len(y_val):,}, Outdoor={n_val_out:,} ({n_val_out/len(y_val)*100:.1f}%), Indoor={n_val_in:,} ({n_val_in/len(y_val)*100:.1f}%)")

    train_ds = CiodSessionDataset(X_train, y_train, ids_train)
    val_ds = CiodSessionDataset(X_val, y_val, ids_val)

    val_loader = DataLoader(val_ds, batch_size=64, shuffle=False)

    # 1. Standard DataLoader
    train_loader_standard = DataLoader(train_ds, batch_size=64, shuffle=True)

    # 2. Class-Balanced Sampler DataLoader
    class_counts = [n_train_in, n_train_out]
    class_weights = [1.0 / c for c in class_counts]
    sample_weights = [class_weights[int(lbl)] for lbl in y_train]
    sampler = WeightedRandomSampler(weights=sample_weights, num_samples=len(sample_weights), replacement=True)
    train_loader_balanced = DataLoader(train_ds, batch_size=64, sampler=sampler)

    # Calculate class imbalance ratio for weighted loss
    imbalance_ratio = n_train_in / n_train_out if n_train_out > 0 else 1.0
    print(f"Class Imbalance Ratio (Indoor / Outdoor): {imbalance_ratio:.2f}x")

    results_table = {}

    # Experiment 1: Standard BCE Baseline
    torch.manual_seed(42)
    np.random.seed(42)
    m1 = ModelC_DepthwiseSeparableCnn()
    m1, _, p_val_1, _ = train_candidate(
        m1, train_loader_standard, val_loader, loss_type='bce', device=device, label="1. Standard BCE Baseline"
    )
    results_table['1. Standard BCE Baseline'] = compute_metrics(y_val, p_val_1, threshold=0.50)

    # Experiment 2: Class-Balanced Sampling
    torch.manual_seed(42)
    m2 = ModelC_DepthwiseSeparableCnn()
    m2, _, p_val_2, _ = train_candidate(
        m2, train_loader_balanced, val_loader, loss_type='bce', device=device, label="2. Class-Balanced Sampling"
    )
    results_table['2. Class-Balanced Sampling'] = compute_metrics(y_val, p_val_2, threshold=0.50)

    # Experiment 3: Weighted BCE Loss (pos_weight = 1.5)
    torch.manual_seed(42)
    m3 = ModelC_DepthwiseSeparableCnn()
    m3, _, p_val_3, _ = train_candidate(
        m3, train_loader_standard, val_loader, loss_type='weighted_bce', pos_weight_val=1.5, device=device, label="3. Weighted BCE (pos_weight=1.5)"
    )
    results_table['3. Weighted BCE (pos_weight=1.5)'] = compute_metrics(y_val, p_val_3, threshold=0.50)

    # Experiment 4: Focal Loss (gamma=2.0, alpha=0.65)
    torch.manual_seed(42)
    m4 = ModelC_DepthwiseSeparableCnn()
    m4, _, p_val_4, _ = train_candidate(
        m4, train_loader_standard, val_loader, loss_type='focal', device=device, label="4. Focal Loss (gamma=2.0, alpha=0.65)"
    )
    results_table['4. Focal Loss (gamma=2.0, alpha=0.65)'] = compute_metrics(y_val, p_val_4, threshold=0.50)

    # Experiment 5: Online Hard Example Mining (OHEM)
    torch.manual_seed(42)
    m5 = ModelC_DepthwiseSeparableCnn()
    m5, _, p_val_5, _ = train_candidate(
        m5, train_loader_standard, val_loader, loss_type='ohem', device=device, label="5. Online Hard Example Mining (OHEM)"
    )
    results_table['5. OHEM Hard Mining'] = compute_metrics(y_val, p_val_5, threshold=0.50)

    # Experiment 6: Post-Hoc Threshold Calibration on Baseline Model
    print("\n--- Sweeping Thresholds on Baseline Validation Predictions ---")
    best_th = 0.50
    best_macro = 0.0
    for th in [0.45, 0.40, 0.35, 0.30, 0.25, 0.20, 0.15]:
        m_th = compute_metrics(y_val, p_val_1, threshold=th)
        label_th = f"6. Baseline + Calibrated (theta={th:.2f})"
        results_table[label_th] = m_th
        if m_th['macro_f1'] > best_macro:
            best_macro = m_th['macro_f1']
            best_th = th

    # Experiment 7: Temporal Hysteresis Filter on Baseline Model
    def apply_hysteresis(probs, low=0.20, high=0.40):
        states = []
        cur = 0 # 0=Indoor
        for p in probs:
            if cur == 0 and p >= high:
                cur = 1
            elif cur == 1 and p < low:
                cur = 0
            states.append(cur)
        return np.array(states, dtype=int)

    h_states = apply_hysteresis(p_val_1, low=0.20, high=0.40)
    tp_h = int(np.sum((y_val == 1) & (h_states == 1)))
    tn_h = int(np.sum((y_val == 0) & (h_states == 0)))
    fp_h = int(np.sum((y_val == 0) & (h_states == 1)))
    fn_h = int(np.sum((y_val == 1) & (h_states == 0)))
    p_out_h = tp_h / (tp_h + fp_h) if (tp_h + fp_h) > 0 else 0.0
    r_out_h = tp_h / (tp_h + fn_h) if (tp_h + fn_h) > 0 else 0.0
    f1_out_h = 2 * (p_out_h * r_out_h) / (p_out_h + r_out_h) if (p_out_h + r_out_h) > 0 else 0.0
    p_in_h = tn_h / (tn_h + fn_h) if (tn_h + fn_h) > 0 else 0.0
    r_in_h = tn_h / (tn_h + fp_h) if (tn_h + fp_h) > 0 else 0.0
    f1_in_h = 2 * (p_in_h * r_in_h) / (p_in_h + r_in_h) if (p_in_h + r_in_h) > 0 else 0.0
    macro_h = (f1_out_h + f1_in_h) / 2.0
    results_table['7. Baseline + Hysteresis [0.40, 0.20]'] = {
        'total': len(y_val),
        'accuracy': (tp_h + tn_h) / len(y_val),
        'macro_f1': macro_h,
        'precision_out': p_out_h,
        'recall_out': r_out_h,
        'f1_out': f1_out_h,
        'precision_in': p_in_h,
        'recall_in': r_in_h,
        'f1_in': f1_in_h,
        'tp': tp_h,
        'tn': tn_h,
        'fp': fp_h,
        'fn': fn_h,
    }

    # Print Validation Comparison Table
    print("\n" + "=" * 95)
    print("      VALIDATION SET EXPERIMENT COMPARISON TABLE (SESSIONS 60..71)")
    print("=" * 95)
    print("| Candidate Strategy / Model | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Outdoor Prec | Outdoor F1 |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |")
    for name, m in results_table.items():
        print(
            f"| **{name}** | **{m['accuracy']*100:.2f}%** | **{m['macro_f1']*100:.2f}%** | "
            f"{m['recall_in']*100:.1f}% | {m['recall_out']*100:.1f}% | "
            f"{m['precision_out']*100:.1f}% | {m['f1_out']*100:.1f}% |"
        )

    # Save validation experiment results to JSON
    val_export = {k: {k2: float(v2) for k2, v2 in v.items()} for k, v in results_table.items()}
    with open("tooling/data/benchmark_results/validation_study_results.json", 'w') as f:
        json.dump(val_export, f, indent=2)
    print(f"\nSaved validation experiment results to: tooling/data/benchmark_results/validation_study_results.json")


if __name__ == '__main__':
    main()
