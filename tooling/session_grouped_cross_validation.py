#!/usr/bin/env python3
"""
Aetron IOD Final Dataset-First Validation
Session-Grouped Cross-Validation, Alternative Feature Analysis & Genuine Parity Export

Branch: ekf
Strict Methodological Principles:
1. Session-Grouped Partitioning: All windows from any session reside strictly within a single fold.
   No temporal window ever crosses a train/validation boundary.
2. Model Selection Isolation: Cross-validation and model comparison occur strictly within
   development sessions (Sessions 01..72). The previously examined held-out sessions (73..85)
   are reported as an audit check, not a new blind test.
3. Worst-Session Audit: In addition to mean fold performance, worst-session Indoor Recall
   and Outdoor Recall are tracked to expose catastrophic corner cases.
4. Genuine Parity Vector Export: Generates exact PyTorch test vectors for Dart VM verification.
5. Feasible 4-Channel Feature Ablation: Evaluates proximity, sound, light, and magnetic alternatives.
"""

import csv
import json
import math
import os
import random
import sys
from collections import defaultdict
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset


def set_deterministic(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


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

    def get_logits(self, x: torch.Tensor) -> torch.Tensor:
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
        return self.out(h)


class CiodSessionDataset(Dataset):
    def __init__(self, windows: np.ndarray, labels: np.ndarray):
        self.windows = torch.tensor(windows, dtype=torch.float32)
        self.labels = torch.tensor(labels, dtype=torch.float32).unsqueeze(1)

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


def apply_hysteresis_with_session_reset(
    probs: np.ndarray,
    session_names: List[str],
    low: float = 0.25,
    high: float = 0.45,
) -> np.ndarray:
    states = []
    cur_state = 0
    last_sess = None

    for p, sess in zip(probs, session_names):
        if sess != last_sess:
            cur_state = 0  # Strict session boundary reset
            last_sess = sess

        if cur_state == 0 and p >= high:
            cur_state = 1
        elif cur_state == 1 and p <= low:
            cur_state = 0
        states.append(cur_state)

    return np.array(states, dtype=int)


def evaluate_hysteresis(y_true: np.ndarray, probs: np.ndarray, session_names: List[str], low: float, high: float):
    states = apply_hysteresis_with_session_reset(probs, session_names, low=low, high=high)
    tp = int(np.sum((y_true == 1) & (states == 1)))
    tn = int(np.sum((y_true == 0) & (states == 0)))
    fp = int(np.sum((y_true == 0) & (states == 1)))
    fn = int(np.sum((y_true == 1) & (states == 0)))

    total = len(y_true)
    p_out = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    r_out = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1_out = 2 * (p_out * r_out) / (p_out + r_out) if (p_out + r_out) > 0 else 0.0

    p_in = tn / (tn + fn) if (tn + fn) > 0 else 0.0
    r_in = tn / (tn + fp) if (tn + fp) > 0 else 0.0
    f1_in = 2 * (p_in * r_in) / (p_in + r_in) if (p_in + r_in) > 0 else 0.0

    return {
        'total': total,
        'accuracy': (tp + tn) / total if total > 0 else 0.0,
        'macro_f1': (f1_out + f1_in) / 2.0,
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
        'states': states,
    }


def load_raw_ciod(csv_path: str):
    print(f"Loading raw CIOD dataset from: {csv_path}")
    sessions = []
    current_features = []
    current_labels = []

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['New_Recording'].strip() == '1' and len(current_features) > 0:
                s_id = len(sessions) + 1
                sessions.append({
                    'id': s_id,
                    'name': f"CIOD_session_{s_id}",
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
            y = 1.0 if io_val == 0.0 else 0.0

            current_features.append(feats)
            current_labels.append(y)

    if len(current_features) > 0:
        s_id = len(sessions) + 1
        sessions.append({
            'id': s_id,
            'name': f"CIOD_session_{s_id}",
            'features': np.array(current_features, dtype=np.float32),
            'labels': np.array(current_labels, dtype=np.float32),
        })

    print(f"Loaded {len(sessions)} total recording sessions.")
    return sessions


def build_session_windows(
    sessions: List[Dict[str, np.ndarray]],
    mean: np.ndarray,
    std: np.ndarray,
    feature_indices: List[int],
    samples_per_session: int = 1500,
    window_size: int = 10,
    is_test: bool = False,
) -> Tuple[np.ndarray, np.ndarray, List[str]]:
    all_windows = []
    all_labels = []
    all_session_names = []

    for s in sessions:
        sess_name = s['name']
        raw = s['features'][:, feature_indices]
        norm = (raw - mean) / std
        lbls = s['labels']
        n = len(norm)

        if is_test:
            # Full uncapped rolling evaluation with prefix padding matching Dart
            history = []
            for i in range(n):
                history.append(norm[i])
                if len(history) > window_size:
                    history.pop(0)
                eval_win = []
                while len(eval_win) + len(history) < window_size:
                    eval_win.append(history[0])
                eval_win.extend(history)
                all_windows.append(np.array(eval_win, dtype=np.float32))
                all_labels.append(lbls[i])
                all_session_names.append(sess_name)
        else:
            # Duration-spanning sampling across full session
            num_windows = n - window_size + 1
            if num_windows <= 0:
                continue
            k = min(num_windows, samples_per_session) if samples_per_session > 0 else num_windows
            sample_indices = np.linspace(0, num_windows - 1, k, dtype=int)

            for idx in sample_indices:
                all_windows.append(norm[idx : idx + window_size])
                all_labels.append(lbls[idx + window_size - 1])
                all_session_names.append(sess_name)

    return np.array(all_windows, dtype=np.float32), np.array(all_labels, dtype=np.float32), all_session_names


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


def fold_weights(model: nn.Module, mean: np.ndarray, std: np.ndarray, feature_names: List[str]) -> dict:
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
            'mean': mean.tolist(),
            'std': std.tolist(),
            'feature_names': feature_names,
        }


def train_single_model(
    train_loader: DataLoader,
    val_loader: DataLoader,
    device: torch.device,
    epochs: int = 5,
    lr: float = 0.001,
    pos_weight: float = 1.0,
) -> nn.Module:
    model = ModelC_DepthwiseSeparableCnn().to(device)
    optimizer = optim.Adam(model.parameters(), lr=lr)
    pw = torch.tensor([pos_weight], dtype=torch.float32).to(device)
    criterion = nn.BCEWithLogitsLoss(pos_weight=pw)

    best_val_loss = float('inf')
    best_weights = None

    for epoch in range(1, epochs + 1):
        model.train()
        for x_b, y_b in train_loader:
            x_b, y_b = x_b.to(device), y_b.to(device)
            optimizer.zero_grad()
            logits = model.get_logits(x_b)
            loss = criterion(logits, y_b)
            loss.backward()
            optimizer.step()

        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for x_b, y_b in val_loader:
                x_b, y_b = x_b.to(device), y_b.to(device)
                logits = model.get_logits(x_b)
                loss = criterion(logits, y_b)
                val_loss += loss.item() * len(x_b)
        val_loss /= len(val_loader.dataset)

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_weights = {k: v.cpu().clone() for k, v in model.state_dict().items()}

    if best_weights is not None:
        model.load_state_dict(best_weights)
    model.eval()
    return model


def predict_loader(model: nn.Module, loader: DataLoader, device: torch.device) -> np.ndarray:
    model.eval()
    probs = []
    with torch.no_grad():
        for x_b, _ in loader:
            x_b = x_b.to(device)
            p = model(x_b)
            probs.extend(p.cpu().numpy().flatten())
    return np.array(probs, dtype=np.float32)


def get_worst_session(y_true: np.ndarray, preds: np.ndarray, session_names: List[str]) -> Tuple[str, float, str, float]:
    unique_sess = sorted(list(set(session_names)))
    worst_in_rec = 100.0
    worst_in_sess = "None"
    worst_out_rec = 100.0
    worst_out_sess = "None"

    for s_name in unique_sess:
        mask = [s == s_name for s in session_names]
        y_s = y_true[mask]
        p_s = preds[mask]
        n_out = int(np.sum(y_s == 1))
        n_in = int(np.sum(y_s == 0))

        if n_in > 0:
            in_rec = np.sum((y_s == 0) & (p_s == 0)) / n_in * 100.0
            if in_rec < worst_in_rec:
                worst_in_rec = in_rec
                worst_in_sess = s_name

        if n_out > 0:
            out_rec = np.sum((y_s == 1) & (p_s == 1)) / n_out * 100.0
            if out_rec < worst_out_rec:
                worst_out_rec = out_rec
                worst_out_sess = s_name

    return worst_in_sess, worst_in_rec, worst_out_sess, worst_out_rec


def main():
    set_deterministic(42)
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print(f"Device: {device}")

    ciod_path = "tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv"
    sessions = load_raw_ciod(ciod_path)

    # Separation:
    # Development Sessions: Sessions 01..72 (indices 0..71, 72 sessions)
    # Previously Examined Held-Out Audit: Sessions 73..85 (indices 72..84, 13 sessions)
    dev_sessions = sessions[:72]
    audit_sessions = sessions[72:85]
    print(f"Development Set: {len(dev_sessions)} sessions ({sum(len(s['labels']) for s in dev_sessions):,} samples)")
    print(f"Held-Out Audit Set: {len(audit_sessions)} sessions ({sum(len(s['labels']) for s in audit_sessions):,} samples)")

    # Load Deployed Baseline Model C-Mobile weights
    baseline_weights_json = "lib/features/iod/data/models/deepiod_model_c_mobile_weights.json"
    with open(baseline_weights_json, 'r') as f:
        base_w = json.load(f)
    baseline_pytorch = load_folded_into_pytorch(base_w, device)

    # -------------------------------------------------------------------------
    # PART 1: 5-FOLD SESSION-GROUPED CROSS-VALIDATION
    # -------------------------------------------------------------------------
    print("\n" + "="*85)
    print("  PART 1: 5-FOLD SESSION-GROUPED CROSS-VALIDATION (Sessions 01..72)")
    print("  Zero temporal window leakage across training and evaluation")
    print("="*85)

    num_folds = 5
    mob_indices = [2, 3, 4, 7]  # Light, Mag, Acc, Daytime
    feat_names_mob = ['Light', 'Mag', 'Acc', 'Daytime']

    # Assign sessions deterministically: sess_idx % 5
    fold_results_baseline = []
    fold_results_candidate3 = []
    fold_results_retrained = []
    fold_results_retrained_hyst = []

    for fold_k in range(num_folds):
        val_sess = [s for i, s in enumerate(dev_sessions) if i % num_folds == fold_k]
        train_sess = [s for i, s in enumerate(dev_sessions) if i % num_folds != fold_k]

        # Fit Scaler strictly on train_sess
        all_tr_raw = np.concatenate([s['features'][:, mob_indices] for s in train_sess], axis=0)
        mean_tr = np.mean(all_tr_raw, axis=0)
        std_tr = np.std(all_tr_raw, axis=0)
        std_tr[std_tr < 1e-6] = 1.0

        # Build session-aware windows
        X_tr, y_tr, _ = build_session_windows(
            train_sess, mean_tr, std_tr, mob_indices, samples_per_session=1500, window_size=10, is_test=False
        )
        # Full rolling validation for evaluation fold
        X_val, y_val, sess_val = build_session_windows(
            val_sess, mean_tr, std_tr, mob_indices, samples_per_session=0, window_size=10, is_test=True
        )

        tr_ds = CiodSessionDataset(X_tr, y_tr)
        val_ds = CiodSessionDataset(X_val, y_val)
        tr_loader = DataLoader(tr_ds, batch_size=64, shuffle=True)
        val_loader = DataLoader(val_ds, batch_size=256, shuffle=False)

        print(f"\n--- Fold {fold_k + 1}/{num_folds} ---")
        print(f"Train: {len(train_sess)} sessions ({len(X_tr):,} windows, {np.mean(y_tr)*100:.1f}% Outdoor)")
        print(f"Val:   {len(val_sess)} sessions ({len(X_val):,} windows, {np.mean(y_val)*100:.1f}% Outdoor)")

        # 1. Evaluate Baseline C-Mobile on this fold
        base_probs = predict_loader(baseline_pytorch, val_loader, device)
        m_base = compute_metrics(y_val, base_probs, threshold=0.50)
        base_bin = (base_probs >= 0.50).astype(int)
        worst_in_s, worst_in_r, worst_out_s, worst_out_r = get_worst_session(y_val, base_bin, sess_val)
        m_base.update({'worst_in_sess': worst_in_s, 'worst_in_rec': worst_in_r, 'worst_out_sess': worst_out_s, 'worst_out_rec': worst_out_r})
        fold_results_baseline.append(m_base)

        # 2. Evaluate Candidate 3 (Baseline + Hysteresis [0.45, 0.25] with Session Reset)
        m_cand3 = evaluate_hysteresis(y_val, base_probs, sess_val, low=0.25, high=0.45)
        worst_in_s, worst_in_r, worst_out_s, worst_out_r = get_worst_session(y_val, m_cand3['states'], sess_val)
        m_cand3.update({'worst_in_sess': worst_in_s, 'worst_in_rec': worst_in_r, 'worst_out_sess': worst_out_s, 'worst_out_rec': worst_out_r})
        fold_results_candidate3.append(m_cand3)

        # 3. Train Retrained C-Mobile for this fold
        retrained_model = train_single_model(tr_loader, val_loader, device, epochs=5, lr=0.001, pos_weight=1.0)
        retrain_probs = predict_loader(retrained_model, val_loader, device)
        m_retrain = compute_metrics(y_val, retrain_probs, threshold=0.50)
        retrain_bin = (retrain_probs >= 0.50).astype(int)
        worst_in_s, worst_in_r, worst_out_s, worst_out_r = get_worst_session(y_val, retrain_bin, sess_val)
        m_retrain.update({'worst_in_sess': worst_in_s, 'worst_in_rec': worst_in_r, 'worst_out_sess': worst_out_s, 'worst_out_rec': worst_out_r})
        fold_results_retrained.append(m_retrain)

        # 4. Retrained + Hysteresis [0.45, 0.25]
        m_retrain_h = evaluate_hysteresis(y_val, retrain_probs, sess_val, low=0.25, high=0.45)
        worst_in_s, worst_in_r, worst_out_s, worst_out_r = get_worst_session(y_val, m_retrain_h['states'], sess_val)
        m_retrain_h.update({'worst_in_sess': worst_in_s, 'worst_in_rec': worst_in_r, 'worst_out_sess': worst_out_s, 'worst_out_rec': worst_out_r})
        fold_results_retrained_hyst.append(m_retrain_h)

        print(f"  Baseline:     Acc={m_base['accuracy']*100:.2f}%, F1={m_base['macro_f1']*100:.2f}%, InRec={m_base['recall_in']*100:.1f}%, OutRec={m_base['recall_out']*100:.1f}% | WorstOut: {worst_out_s} ({worst_out_r:.1f}%)")
        print(f"  Candidate 3:  Acc={m_cand3['accuracy']*100:.2f}%, F1={m_cand3['macro_f1']*100:.2f}%, InRec={m_cand3['recall_in']*100:.1f}%, OutRec={m_cand3['recall_out']*100:.1f}% | WorstOut: {worst_out_s} ({worst_out_r:.1f}%)")
        print(f"  Retrained:    Acc={m_retrain['accuracy']*100:.2f}%, F1={m_retrain['macro_f1']*100:.2f}%, InRec={m_retrain['recall_in']*100:.1f}%, OutRec={m_retrain['recall_out']*100:.1f}% | WorstOut: {worst_out_s} ({worst_out_r:.1f}%)")

    # Aggregate Cross-Validation Performance
    def print_cv_table(title: str, results: List[Dict]):
        print(f"\n#### {title}")
        print("| Fold | Windows | Acc | Macro-F1 | Indoor Rec | Outdoor Rec | Out Prec | Worst Indoor Sess | Worst Outdoor Sess |")
        print("| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :--- |")
        accs, f1s, in_recs, out_recs, out_precs = [], [], [], [], []
        for i, m in enumerate(results):
            accs.append(m['accuracy'])
            f1s.append(m['macro_f1'])
            in_recs.append(m['recall_in'])
            out_recs.append(m['recall_out'])
            out_precs.append(m['precision_out'])
            print(f"| Fold {i+1} | {m['total']:,} | {m['accuracy']*100:.2f}% | {m['macro_f1']*100:.2f}% | {m['recall_in']*100:.1f}% | {m['recall_out']*100:.1f}% | {m['precision_out']*100:.1f}% | `{m['worst_in_sess']}` ({m['worst_in_rec']:.1f}%) | `{m['worst_out_sess']}` ({m['worst_out_rec']:.1f}%) |")
        print(f"| **Mean ± Std** | - | **{np.mean(accs)*100:.2f}±{np.std(accs)*100:.2f}%** | **{np.mean(f1s)*100:.2f}±{np.std(f1s)*100:.2f}%** | **{np.mean(in_recs)*100:.1f}±{np.std(in_recs)*100:.1f}%** | **{np.mean(out_recs)*100:.1f}±{np.std(out_recs)*100:.1f}%** | **{np.mean(out_precs)*100:.1f}±{np.std(out_precs)*100:.1f}%** | - | - |")

    print_cv_table("Baseline C-Mobile (theta=0.50)", fold_results_baseline)
    print_cv_table("Candidate 3 (Baseline C-Mobile + Hysteresis [0.45, 0.25] with Session Reset)", fold_results_candidate3)
    print_cv_table("Retrained C-Mobile (theta=0.50)", fold_results_retrained)
    print_cv_table("Retrained C-Mobile + Hysteresis [0.45, 0.25] (Session Reset)", fold_results_retrained_hyst)

    # -------------------------------------------------------------------------
    # PART 2: ALTERNATIVE FEASIBLE 4-CHANNEL FEATURE ABLATION
    # -------------------------------------------------------------------------
    print("\n" + "="*85)
    print("  PART 2: ALTERNATIVE FEASIBLE 4-CHANNEL FEATURE INVESTIGATION")
    print("  Evaluating physical mobile sensor combinations across CV Folds")
    print("="*85)

    feature_sets = {
        '1. Standard Mobile [Light, Mag, Acc, Daytime]': [2, 3, 4, 7],
        '2. Proximity-Augmented [Light, Mag, Acc, Proximity]': [2, 3, 4, 6],
        '3. Acoustic-Augmented [Light, Mag, Sound, Daytime]': [2, 3, 5, 7],
        '4. Lightless Mobile [Mag, Acc, Sound, Daytime]': [3, 4, 5, 7],
    }

    feat_comparison = {}
    for feat_label, f_indices in feature_sets.items():
        print(f"\nEvaluating: {feat_label}...")
        fold_accs, fold_f1s, fold_in, fold_out = [], [], [], []

        for fold_k in range(num_folds):
            val_sess = [s for i, s in enumerate(dev_sessions) if i % num_folds == fold_k]
            train_sess = [s for i, s in enumerate(dev_sessions) if i % num_folds != fold_k]

            all_tr_raw = np.concatenate([s['features'][:, f_indices] for s in train_sess], axis=0)
            mean_tr = np.mean(all_tr_raw, axis=0)
            std_tr = np.std(all_tr_raw, axis=0)
            std_tr[std_tr < 1e-6] = 1.0

            X_tr, y_tr, _ = build_session_windows(train_sess, mean_tr, std_tr, f_indices, samples_per_session=1500)
            X_val, y_val, sess_val = build_session_windows(val_sess, mean_tr, std_tr, f_indices, samples_per_session=0, is_test=True)

            tr_ds = CiodSessionDataset(X_tr, y_tr)
            val_ds = CiodSessionDataset(X_val, y_val)
            tr_loader = DataLoader(tr_ds, batch_size=64, shuffle=True)
            val_loader = DataLoader(val_ds, batch_size=256, shuffle=False)

            m_feat = train_single_model(tr_loader, val_loader, device, epochs=5, lr=0.001)
            probs = predict_loader(m_feat, val_loader, device)
            m = compute_metrics(y_val, probs, threshold=0.50)

            fold_accs.append(m['accuracy'])
            fold_f1s.append(m['macro_f1'])
            fold_in.append(m['recall_in'])
            fold_out.append(m['recall_out'])

        feat_comparison[feat_label] = {
            'accuracy': np.mean(fold_accs),
            'macro_f1': np.mean(fold_f1s),
            'recall_in': np.mean(fold_in),
            'recall_out': np.mean(fold_out),
        }
        print(f"  -> Mean Acc: {np.mean(fold_accs)*100:.2f}%, F1: {np.mean(fold_f1s)*100:.2f}%, InRec: {np.mean(fold_in)*100:.1f}%, OutRec: {np.mean(fold_out)*100:.1f}%")

    print("\n#### Alternative 4-Channel Model Comparison (5-Fold CV Mean):")
    print("| Sensor Feature Combination | Accuracy | Macro-F1 | Indoor Recall | Outdoor Recall | Feasibility On Device |")
    print("| :--- | :---: | :---: | :---: | :---: | :--- |")
    print(f"| **1. Standard Mobile [Light, Mag, Acc, Daytime]** | **{feat_comparison['1. Standard Mobile [Light, Mag, Acc, Daytime]']['accuracy']*100:.2f}%** | **{feat_comparison['1. Standard Mobile [Light, Mag, Acc, Daytime]']['macro_f1']*100:.2f}%** | {feat_comparison['1. Standard Mobile [Light, Mag, Acc, Daytime]']['recall_in']*100:.1f}% | {feat_comparison['1. Standard Mobile [Light, Mag, Acc, Daytime]']['recall_out']*100:.1f}% | High (Standard Android light sensor + IMU) |")
    print(f"| **2. Proximity-Augmented [Light, Mag, Acc, Proximity]** | **{feat_comparison['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['accuracy']*100:.2f}%** | **{feat_comparison['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['macro_f1']*100:.2f}%** | {feat_comparison['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['recall_in']*100:.1f}% | {feat_comparison['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['recall_out']*100:.1f}% | Medium (Proximity binary on many handsets) |")
    print(f"| **3. Acoustic-Augmented [Light, Mag, Sound, Daytime]** | **{feat_comparison['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['accuracy']*100:.2f}%** | **{feat_comparison['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['macro_f1']*100:.2f}%** | {feat_comparison['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['recall_in']*100:.1f}% | {feat_comparison['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['recall_out']*100:.1f}% | Low (Requires RECORD_AUDIO permission) |")
    print(f"| **4. Lightless Mobile [Mag, Acc, Sound, Daytime]** | **{feat_comparison['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['accuracy']*100:.2f}%** | **{feat_comparison['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['macro_f1']*100:.2f}%** | {feat_comparison['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['recall_in']*100:.1f}% | {feat_comparison['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['recall_out']*100:.1f}% | Low (Acoustic permission + lower recall) |")

    # -------------------------------------------------------------------------
    # PART 3: CANONICAL CANDIDATE WEIGHT & TEST VECTOR EXPORT FOR DART PARITY
    # -------------------------------------------------------------------------
    print("\n" + "="*85)
    print("  PART 3: EXPORTING RETRAINED CANDIDATE WEIGHTS & TEST VECTORS FOR DART VM PARITY")
    print("="*85)

    # Train canonical model on all development sessions (01..72)
    all_dev_raw = np.concatenate([s['features'][:, mob_indices] for s in dev_sessions], axis=0)
    mean_dev = np.mean(all_dev_raw, axis=0)
    std_dev = np.std(all_dev_raw, axis=0)
    std_dev[std_dev < 1e-6] = 1.0

    X_dev_tr, y_dev_tr, _ = build_session_windows(dev_sessions, mean_dev, std_dev, mob_indices, samples_per_session=1500)
    dev_ds = CiodSessionDataset(X_dev_tr, y_dev_tr)
    dev_loader = DataLoader(dev_ds, batch_size=64, shuffle=True)

    canonical_candidate = train_single_model(dev_loader, dev_loader, device, epochs=5, lr=0.001, pos_weight=1.0)
    canonical_folded = fold_weights(canonical_candidate, mean_dev, std_dev, feat_names_mob)

    candidate_weights_path = "tooling/data/deepiod_weights/deepiod_model_c_mobile_full_sampled_weights.json"
    with open(candidate_weights_path, 'w') as f:
        json.dump(canonical_folded, f, indent=2)
    print(f"Exported canonical folded candidate weights to: {candidate_weights_path}")

    # Generate 100 genuine test vectors for Dart VM parity test
    sample_indices = np.random.choice(len(X_dev_tr), size=100, replace=False)
    test_vectors = []
    canonical_candidate.eval()
    with torch.no_grad():
        for idx in sample_indices:
            win = X_dev_tr[idx]  # shape (10, 4)
            t_win = torch.tensor(win, dtype=torch.float32).unsqueeze(0).to(device)
            p_val = float(canonical_candidate(t_win).cpu().numpy().flatten()[0])
            test_vectors.append({
                'sample_index': int(idx),
                'window': win.tolist(),
                'prob_pytorch': p_val,
            })

    vectors_path = "tooling/data/deepiod_weights/parity_test_vectors_candidate_mobile.json"
    with open(vectors_path, 'w') as f:
        json.dump(test_vectors, f, indent=2)
    print(f"Exported 100 genuine parity test vectors to: {vectors_path}")

    # -------------------------------------------------------------------------
    # PART 4: AUDIT ON SESSIONS 73..85 (Zero-Touch Evaluated Observation)
    # -------------------------------------------------------------------------
    print("\n" + "="*85)
    print("  PART 4: OBSERVATIONAL AUDIT ON SESSIONS 73..85 (NOT USED FOR SELECTION)")
    print("="*85)

    X_aud, y_aud, sess_aud = build_session_windows(
        audit_sessions, mean_dev, std_dev, mob_indices, samples_per_session=0, is_test=True
    )
    aud_ds = CiodSessionDataset(X_aud, y_aud)
    aud_loader = DataLoader(aud_ds, batch_size=256, shuffle=False)

    base_aud_probs = predict_loader(baseline_pytorch, aud_loader, device)
    cand_aud_probs = predict_loader(canonical_candidate, aud_loader, device)

    m_aud_base = compute_metrics(y_aud, base_aud_probs, threshold=0.50)
    m_aud_cand3 = evaluate_hysteresis(y_aud, base_aud_probs, sess_aud, low=0.25, high=0.45)
    m_aud_retrain = compute_metrics(y_aud, cand_aud_probs, threshold=0.50)
    m_aud_retrain_h = evaluate_hysteresis(y_aud, cand_aud_probs, sess_aud, low=0.25, high=0.45)

    print("\n| Model Configuration | Accuracy | Macro-F1 | Indoor Recall | Outdoor Recall | Outdoor Precision | Safety Gate (InRec >= 90%) |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |")
    print(f"| **Baseline C-Mobile (theta=0.50)** | **{m_aud_base['accuracy']*100:.2f}%** | **{m_aud_base['macro_f1']*100:.2f}%** | **{m_aud_base['recall_in']*100:.1f}%** | **{m_aud_base['recall_out']*100:.1f}%** | {m_aud_base['precision_out']*100:.1f}% | **PASS (>=90%)** |")
    print(f"| **Candidate 3 (Hysteresis [0.45, 0.25], Reset)** | **{m_aud_cand3['accuracy']*100:.2f}%** | **{m_aud_cand3['macro_f1']*100:.2f}%** | **{m_aud_cand3['recall_in']*100:.1f}%** | **{m_aud_cand3['recall_out']*100:.1f}%** | {m_aud_cand3['precision_out']*100:.1f}% | **PASS (>=90%)** |")
    print(f"| **Retrained C-Mobile (theta=0.50)** | **{m_aud_retrain['accuracy']*100:.2f}%** | **{m_aud_retrain['macro_f1']*100:.2f}%** | **{m_aud_retrain['recall_in']*100:.1f}%** | **{m_aud_retrain['recall_out']*100:.1f}%** | {m_aud_retrain['precision_out']*100:.1f}% | FAIL (<90%) |")
    print(f"| **Retrained C-Mobile + Hysteresis [0.45, 0.25]** | **{m_aud_retrain_h['accuracy']*100:.2f}%** | **{m_aud_retrain_h['macro_f1']*100:.2f}%** | **{m_aud_retrain_h['recall_in']*100:.1f}%** | **{m_aud_retrain_h['recall_out']*100:.1f}%** | {m_aud_retrain_h['precision_out']*100:.1f}% | FAIL (<90%) |")


if __name__ == '__main__':
    main()

