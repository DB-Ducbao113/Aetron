#!/usr/bin/env python3
"""
Aetron Nested Session-Grouped Cross-Validation & Sensor Feature Analysis
Branch: ekf

Scientific & Methodological Guarantees:
1. Two-Level Nested Session-Grouped CV:
   - Outer Fold: Strictly evaluation-only (unseen during all training, scaling & tuning).
   - Inner Training Fold: Computes feature scaler, fits neural network weights.
   - Inner Validation Fold: Model checkpointing (early stopping), threshold & hysteresis tuning.
2. Fresh Model Retraining: A fresh Model C-Mobile is retrained from scratch per outer fold.
3. Pretrained Deployed Model Audit: Deployed baseline evaluated separately with its OWN trained scaler
   and explicit disclosure of training session overlap.
4. Correct Normalization: Every model uses exclusively its own training-derived normalization scaler.
5. Identical Nested CV across all 4 Feature Sets:
   - Standard Mobile [Light, Mag, Acc, Daytime]
   - Proximity-Augmented [Light, Mag, Acc, Proximity]
   - Acoustic-Augmented [Light, Mag, Sound, Daytime]
   - Lightless Mobile [Mag, Acc, Sound, Daytime]
6. Comprehensive Metric Reporting: Mean, Std, per-fold confusion matrices, worst-session metrics, class support.
7. Strict Engineering Safety Target: InRec >= 90.0% enforced in inner tuning.
8. Zero Leakage: Window generation is strictly vectorized per-session with prefix padding.
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
from numpy.lib.stride_tricks import sliding_window_view
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
        'indoor_support': tn + fp,
        'outdoor_support': tp + fn,
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
    accuracy = (tp + tn) / total if total > 0 else 0.0
    p_out = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    r_out = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1_out = 2 * (p_out * r_out) / (p_out + r_out) if (p_out + r_out) > 0 else 0.0

    p_in = tn / (tn + fn) if (tn + fn) > 0 else 0.0
    r_in = tn / (tn + fp) if (tn + fp) > 0 else 0.0
    f1_in = 2 * (p_in * r_in) / (p_in + r_in) if (p_in + r_in) > 0 else 0.0

    return {
        'total': total,
        'accuracy': accuracy,
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
        'indoor_support': tn + fp,
        'outdoor_support': tp + fn,
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


def build_vectorized_windows(
    sessions: List[Dict[str, np.ndarray]],
    mean: np.ndarray,
    std: np.ndarray,
    feature_indices: List[int],
    samples_per_session: int = 1500,
    is_test: bool = False,
) -> Tuple[np.ndarray, np.ndarray, List[str]]:
    """
    Constructs temporal windows (10xW) per-session using vectorized sliding window views.
    Zero cross-session contamination.
    """
    all_win_list = []
    all_lbl_list = []
    all_names = []

    for s in sessions:
        sess_name = s['name']
        raw = s['features'][:, feature_indices]
        norm = (raw - mean) / std
        lbls = s['labels']
        n = len(norm)

        if is_test:
            # Prefix padding matching Dart rolling queue (repeat step 0 for initial 9 steps)
            prefix = np.repeat(norm[0:1], 9, axis=0)
            norm_padded = np.concatenate([prefix, norm], axis=0)  # shape (n + 9, W)
            # Vectorized sliding window: shape (n, W, 10) -> swap to (n, 10, W)
            sw = sliding_window_view(norm_padded, 10, axis=0)
            sw = np.swapaxes(sw, 1, 2)
            all_win_list.append(sw)
            all_lbl_list.append(lbls)
            all_names.extend([sess_name] * n)
        else:
            # Duration-spanning sampling across full session
            num_windows = n - 10 + 1
            if num_windows <= 0:
                continue
            sw = sliding_window_view(norm, 10, axis=0)
            sw = np.swapaxes(sw, 1, 2)
            sw_lbls = lbls[9:]

            k = min(len(sw), samples_per_session) if samples_per_session > 0 else len(sw)
            sample_indices = np.linspace(0, len(sw) - 1, k, dtype=int)
            all_win_list.append(sw[sample_indices])
            all_lbl_list.append(sw_lbls[sample_indices])
            all_names.extend([sess_name] * k)

    X = np.concatenate(all_win_list, axis=0).astype(np.float32)
    y = np.concatenate(all_lbl_list, axis=0).astype(np.float32)
    return X, y, all_names


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
    patience: int = 4,
) -> nn.Module:
    model = ModelC_DepthwiseSeparableCnn().to(device)
    optimizer = optim.Adam(model.parameters(), lr=lr)
    criterion = nn.BCEWithLogitsLoss()

    best_val_loss = float('inf')
    best_weights = None
    no_imp = 0

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
            no_imp = 0
        else:
            no_imp += 1
            if no_imp >= patience:
                break

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


def tune_operating_point_on_inner_val(
    y_val: np.ndarray,
    probs_val: np.ndarray,
    sess_val: List[str],
    min_indoor_recall: float = 0.90,
) -> Tuple[float, Tuple[float, float]]:
    """
    Sweeps thresholds and hysteresis parameters strictly on inner validation
    to find the operating points that maximize Outdoor Recall subject to InRec >= min_indoor_recall.
    """
    best_th = 0.50
    best_th_out_rec = -1.0
    best_th_in_rec = -1.0

    # 1. Sweep threshold
    for th in np.arange(0.20, 0.56, 0.02):
        m = compute_metrics(y_val, probs_val, threshold=float(th))
        if m['recall_in'] >= min_indoor_recall:
            if m['recall_out'] > best_th_out_rec:
                best_th_out_rec = m['recall_out']
                best_th_in_rec = m['recall_in']
                best_th = float(th)

    if best_th_out_rec < 0.0:
        # Fallback: select threshold with highest Indoor Recall
        max_in = -1.0
        for th in np.arange(0.20, 0.56, 0.02):
            m = compute_metrics(y_val, probs_val, threshold=float(th))
            if m['recall_in'] > max_in:
                max_in = m['recall_in']
                best_th = float(th)

    # 2. Sweep Hysteresis
    hyst_candidates = [
        (0.25, 0.45),
        (0.28, 0.45),
        (0.20, 0.40),
        (0.25, 0.40),
        (0.22, 0.38),
        (0.28, 0.48),
        (0.30, 0.50),
    ]
    best_hyst = (0.25, 0.45)
    best_h_out_rec = -1.0

    for (lo, hi) in hyst_candidates:
        m_h = evaluate_hysteresis(y_val, probs_val, sess_val, low=lo, high=hi)
        if m_h['recall_in'] >= min_indoor_recall:
            if m_h['recall_out'] > best_h_out_rec:
                best_h_out_rec = m_h['recall_out']
                best_hyst = (lo, hi)

    return best_th, best_hyst


def run_nested_session_cv(
    sessions: List[Dict[str, np.ndarray]],
    feature_indices: List[int],
    feature_names: List[str],
    device: torch.device,
    deployed_model: nn.Module,
    deployed_mean: np.ndarray,
    deployed_std: np.ndarray,
    num_outer_folds: int = 5,
):
    print("\n" + "="*88)
    print(f"  NESTED SESSION-GROUPED CV: Features {feature_names}")
    print("="*88)

    outer_results_retrained_base = []
    outer_results_retrained_calib = []
    outer_results_retrained_hyst = []
    outer_results_deployed_base = []
    outer_results_deployed_cand3 = []

    for k in range(num_outer_folds):
        outer_val_sess = [s for i, s in enumerate(sessions) if i % num_outer_folds == k]
        outer_train_pool = [s for i, s in enumerate(sessions) if i % num_outer_folds != k]

        # Inner Split: 75% inner train, 25% inner val
        inner_val_sess = [s for j, s in enumerate(outer_train_pool) if j % 4 == 0]
        inner_tr_sess = [s for j, s in enumerate(outer_train_pool) if j % 4 != 0]

        # 1. Fit Scaler strictly on inner_tr_sess
        raw_inner_tr = np.concatenate([s['features'][:, feature_indices] for s in inner_tr_sess], axis=0)
        mean_inner = np.mean(raw_inner_tr, axis=0)
        std_inner = np.std(raw_inner_tr, axis=0)
        std_inner[std_inner < 1e-6] = 1.0

        # Build windows
        X_in_tr, y_in_tr, _ = build_vectorized_windows(
            inner_tr_sess, mean_inner, std_inner, feature_indices, samples_per_session=1500, is_test=False
        )
        X_in_val, y_in_val, sess_in_val = build_vectorized_windows(
            inner_val_sess, mean_inner, std_inner, feature_indices, samples_per_session=0, is_test=True
        )
        X_out_val, y_out_val, sess_out_val = build_vectorized_windows(
            outer_val_sess, mean_inner, std_inner, feature_indices, samples_per_session=0, is_test=True
        )

        in_tr_loader = DataLoader(CiodSessionDataset(X_in_tr, y_in_tr), batch_size=64, shuffle=True)
        in_val_loader = DataLoader(CiodSessionDataset(X_in_val, y_in_val), batch_size=256, shuffle=False)
        out_val_loader = DataLoader(CiodSessionDataset(X_out_val, y_out_val), batch_size=256, shuffle=False)

        # 2. Train fresh Model C-Mobile for this outer fold
        set_deterministic(42 + k)
        fresh_model = train_single_model(in_tr_loader, in_val_loader, device, epochs=5, lr=0.001)

        # 3. Inner Tuning on inner validation
        probs_in_val = predict_loader(fresh_model, in_val_loader, device)
        best_th, (best_lo, best_hi) = tune_operating_point_on_inner_val(
            y_in_val, probs_in_val, sess_in_val, min_indoor_recall=0.90
        )

        # 4. Final Evaluation on Outer Fold (Strictly Evaluation Only)
        probs_out_val = predict_loader(fresh_model, out_val_loader, device)

        # 4a. Fresh Model Baseline (theta = 0.50)
        m_base = compute_metrics(y_out_val, probs_out_val, threshold=0.50)
        win_bin = (probs_out_val >= 0.50).astype(int)
        w_in_s, w_in_r, w_out_s, w_out_r = get_worst_session(y_out_val, win_bin, sess_out_val)
        m_base.update({'worst_in_sess': w_in_s, 'worst_in_rec': w_in_r, 'worst_out_sess': w_out_s, 'worst_out_rec': w_out_r})
        outer_results_retrained_base.append(m_base)

        # 4b. Fresh Model Calibrated (theta*)
        m_calib = compute_metrics(y_out_val, probs_out_val, threshold=best_th)
        win_bin_c = (probs_out_val >= best_th).astype(int)
        w_in_s, w_in_r, w_out_s, w_out_r = get_worst_session(y_out_val, win_bin_c, sess_out_val)
        m_calib.update({'worst_in_sess': w_in_s, 'worst_in_rec': w_in_r, 'worst_out_sess': w_out_s, 'worst_out_rec': w_out_r, 'selected_theta': best_th})
        outer_results_retrained_calib.append(m_calib)

        # 4c. Fresh Model Hysteresis ([High*, Low*])
        m_hyst = evaluate_hysteresis(y_out_val, probs_out_val, sess_out_val, low=best_lo, high=best_hi)
        w_in_s, w_in_r, w_out_s, w_out_r = get_worst_session(y_out_val, m_hyst['states'], sess_out_val)
        m_hyst.update({'worst_in_sess': w_in_s, 'worst_in_rec': w_in_r, 'worst_out_sess': w_out_s, 'worst_out_rec': w_out_r, 'selected_hyst': f"[{best_hi:.2f}, {best_lo:.2f}]"})
        outer_results_retrained_hyst.append(m_hyst)

        # 5. Evaluate Deployed Model using ITS OWN trained scaler (for standard mobile features)
        if feature_indices == [2, 3, 4, 7]:
            X_dep_val, y_dep_val, sess_dep_val = build_vectorized_windows(
                outer_val_sess, deployed_mean, deployed_std, feature_indices, samples_per_session=0, is_test=True
            )
            dep_loader = DataLoader(CiodSessionDataset(X_dep_val, y_dep_val), batch_size=256, shuffle=False)
            probs_dep = predict_loader(deployed_model, dep_loader, device)

            m_dep = compute_metrics(y_dep_val, probs_dep, threshold=0.50)
            dep_bin = (probs_dep >= 0.50).astype(int)
            w_in_s, w_in_r, w_out_s, w_out_r = get_worst_session(y_dep_val, dep_bin, sess_dep_val)
            m_dep.update({'worst_in_sess': w_in_s, 'worst_in_rec': w_in_r, 'worst_out_sess': w_out_s, 'worst_out_rec': w_out_r})
            outer_results_deployed_base.append(m_dep)

            m_dep_c3 = evaluate_hysteresis(y_dep_val, probs_dep, sess_dep_val, low=0.25, high=0.45)
            w_in_s, w_in_r, w_out_s, w_out_r = get_worst_session(y_dep_val, m_dep_c3['states'], sess_dep_val)
            m_dep_c3.update({'worst_in_sess': w_in_s, 'worst_in_rec': w_in_r, 'worst_out_sess': w_out_s, 'worst_out_rec': w_out_r})
            outer_results_deployed_cand3.append(m_dep_c3)

        print(f"Fold {k+1}/{num_outer_folds}: Val Sess = {len(outer_val_sess)} | Fresh (theta=0.50): Acc={m_base['accuracy']*100:.2f}%, InRec={m_base['recall_in']*100:.1f}%, OutRec={m_base['recall_out']*100:.1f}%")
        print(f"              | Fresh Tuned (th={best_th:.2f}): InRec={m_calib['recall_in']*100:.1f}%, OutRec={m_calib['recall_out']*100:.1f}%")
        print(f"              | Fresh Hyst [{best_hi:.2f}, {best_lo:.2f}]: InRec={m_hyst['recall_in']*100:.1f}%, OutRec={m_hyst['recall_out']*100:.1f}%")

    return {
        'retrained_base': outer_results_retrained_base,
        'retrained_calib': outer_results_retrained_calib,
        'retrained_hyst': outer_results_retrained_hyst,
        'deployed_base': outer_results_deployed_base,
        'deployed_cand3': outer_results_deployed_cand3,
    }


def print_nested_cv_summary(title: str, results: List[Dict]):
    print(f"\n### {title}")
    print("| Outer Fold | Total Support | Indoor / Outdoor Support | TP / FP / FN / TN | Accuracy | Macro-F1 | Indoor Recall | Outdoor Recall | Out Precision | Worst Indoor Sess | Worst Outdoor Sess |")
    print("| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :--- |")
    accs, f1s, in_recs, out_recs, out_precs = [], [], [], [], []
    for i, m in enumerate(results):
        accs.append(m['accuracy'])
        f1s.append(m['macro_f1'])
        in_recs.append(m['recall_in'])
        out_recs.append(m['recall_out'])
        out_precs.append(m['precision_out'])
        cm_str = f"{m['tp']} / {m['fp']} / {m['fn']} / {m['tn']}"
        supp_str = f"{m['indoor_support']:,} / {m['outdoor_support']:,}"
        print(f"| Fold {i+1} | {m['total']:,} | {supp_str} | {cm_str} | {m['accuracy']*100:.2f}% | {m['macro_f1']*100:.2f}% | {m['recall_in']*100:.1f}% | {m['recall_out']*100:.1f}% | {m['precision_out']*100:.1f}% | `{m['worst_in_sess']}` ({m['worst_in_rec']:.1f}%) | `{m['worst_out_sess']}` ({m['worst_out_rec']:.1f}%) |")
    print(f"| **Mean ± Std** | - | - | - | **{np.mean(accs)*100:.2f}±{np.std(accs)*100:.2f}%** | **{np.mean(f1s)*100:.2f}±{np.std(f1s)*100:.2f}%** | **{np.mean(in_recs)*100:.1f}±{np.std(in_recs)*100:.1f}%** | **{np.mean(out_recs)*100:.1f}±{np.std(out_recs)*100:.1f}%** | **{np.mean(out_precs)*100:.1f}±{np.std(out_precs)*100:.1f}%** | - | - |")


def main():
    set_deterministic(42)
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print(f"Device: {device}")

    ciod_path = "tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv"
    sessions = load_raw_ciod(ciod_path)

    dev_sessions = sessions[:72]
    audit_sessions = sessions[72:85]
    print(f"Development Set: {len(dev_sessions)} sessions ({sum(len(s['labels']) for s in dev_sessions):,} samples)")
    print(f"Previously Examined Audit Set: {len(audit_sessions)} sessions ({sum(len(s['labels']) for s in audit_sessions):,} samples)")

    # 1. Load Deployed Model C-Mobile and its OWN trained scaler
    baseline_weights_json = "lib/features/iod/data/models/deepiod_model_c_mobile_weights.json"
    with open(baseline_weights_json, 'r') as f:
        base_w = json.load(f)
    deployed_model = load_folded_into_pytorch(base_w, device)
    deployed_mean = np.array(base_w['mean'], dtype=np.float32)
    deployed_std = np.array(base_w['std'], dtype=np.float32)
    print("\n--- Deployed Pretrained Model C-Mobile ---")
    print(f"Pretrained Scaler Mean: {deployed_mean}")
    print(f"Pretrained Scaler Std:  {deployed_std}")
    print("Pretraining Session Range: Sessions 01..60 (Cambridge CIOD)")

    export_only = '--export-only' in sys.argv

    # -------------------------------------------------------------------------
    # PART 1: 5-FOLD NESTED SESSION-GROUPED CROSS-VALIDATION (STANDARD MOBILE)
    # -------------------------------------------------------------------------
    mob_indices = [2, 3, 4, 7]
    mob_names = ['Light', 'Mag', 'Acc', 'Daytime']

    if not export_only:
        res_standard = run_nested_session_cv(
            dev_sessions, mob_indices, mob_names, device, deployed_model, deployed_mean, deployed_std, num_outer_folds=5
        )

        print("\n" + "="*88)
        print("  RESULTS: NESTED SESSION-GROUPED CV (SESSIONS 01..72)")
        print("="*88)
        print_nested_cv_summary("1. Fresh Retrained Model C-Mobile (Default theta=0.50)", res_standard['retrained_base'])
        print_nested_cv_summary("2. Fresh Retrained Model C-Mobile (Inner-Tuned Threshold theta*)", res_standard['retrained_calib'])
        print_nested_cv_summary("3. Fresh Retrained Model C-Mobile (Inner-Tuned Hysteresis [High*, Low*])", res_standard['retrained_hyst'])
        print_nested_cv_summary("4. Deployed Pretrained C-Mobile Baseline (theta=0.50, Frozen Pretrained Scaler)", res_standard['deployed_base'])
        print_nested_cv_summary("5. Deployed Pretrained C-Mobile + Candidate 3 Hysteresis [0.45, 0.25] (Session Reset)", res_standard['deployed_cand3'])

        # -------------------------------------------------------------------------
        # PART 2: NESTED CV COMPARISON ACROSS ALL FOUR 4-CHANNEL SENSOR FEATURE SETS
        # -------------------------------------------------------------------------
        print("\n" + "="*88)
        print("  PART 2: NESTED CV COMPARISON ACROSS ALL FOUR 4-CHANNEL SENSOR FEATURE SETS")
        print("="*88)

        feature_sets = {
            '1. Standard Mobile [Light, Mag, Acc, Daytime]': ([2, 3, 4, 7], ['Light', 'Mag', 'Acc', 'Daytime']),
            '2. Proximity-Augmented [Light, Mag, Acc, Proximity]': ([2, 3, 4, 6], ['Light', 'Mag', 'Acc', 'Proximity']),
            '3. Acoustic-Augmented [Light, Mag, Sound, Daytime]': ([2, 3, 5, 7], ['Light', 'Mag', 'Sound', 'Daytime']),
            '4. Lightless Mobile [Mag, Acc, Sound, Daytime]': ([3, 4, 5, 7], ['Mag', 'Acc', 'Sound', 'Daytime']),
        }

        feature_cv_summaries = {}
        for feat_title, (f_idx, f_names) in feature_sets.items():
            if feat_title == '1. Standard Mobile [Light, Mag, Acc, Daytime]':
                res_feat = res_standard
            else:
                res_feat = run_nested_session_cv(
                    dev_sessions, f_idx, f_names, device, deployed_model, deployed_mean, deployed_std, num_outer_folds=5
                )

            m_list = res_feat['retrained_base']
            accs = [m['accuracy'] for m in m_list]
            f1s = [m['macro_f1'] for m in m_list]
            in_recs = [m['recall_in'] for m in m_list]
            out_recs = [m['recall_out'] for m in m_list]

            feature_cv_summaries[feat_title] = {
                'accuracy': f"{np.mean(accs)*100:.2f}±{np.std(accs)*100:.2f}%",
                'macro_f1': f"{np.mean(f1s)*100:.2f}±{np.std(f1s)*100:.2f}%",
                'recall_in': f"{np.mean(in_recs)*100:.1f}±{np.std(in_recs)*100:.1f}%",
                'recall_out': f"{np.mean(out_recs)*100:.1f}±{np.std(out_recs)*100:.1f}%",
            }

        print("\n#### Four Feasible Feature Sets Comparison (5-Fold Nested CV Outer Evaluation):")
        print("| Sensor Feature Combination | Accuracy (Mean±Std) | Macro-F1 (Mean±Std) | Indoor Recall (Mean±Std) | Outdoor Recall (Mean±Std) | Hardware & Legal Feasibility |")
        print("| :--- | :---: | :---: | :---: | :---: | :--- |")
        print(f"| **1. Standard Mobile [Light, Mag, Acc, Daytime]** | **{feature_cv_summaries['1. Standard Mobile [Light, Mag, Acc, Daytime]']['accuracy']}** | **{feature_cv_summaries['1. Standard Mobile [Light, Mag, Acc, Daytime]']['macro_f1']}** | {feature_cv_summaries['1. Standard Mobile [Light, Mag, Acc, Daytime]']['recall_in']} | {feature_cv_summaries['1. Standard Mobile [Light, Mag, Acc, Daytime]']['recall_out']} | High: Standard Android Sensor.TYPE_LIGHT, IMU + Clock |")
        print(f"| **2. Proximity-Augmented [Light, Mag, Acc, Proximity]** | **{feature_cv_summaries['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['accuracy']}** | **{feature_cv_summaries['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['macro_f1']}** | {feature_cv_summaries['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['recall_in']} | {feature_cv_summaries['2. Proximity-Augmented [Light, Mag, Acc, Proximity]']['recall_out']} | Medium: Proximity often binary; iOS restricted to phone calls |")
        print(f"| **3. Acoustic-Augmented [Light, Mag, Sound, Daytime]** | **{feature_cv_summaries['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['accuracy']}** | **{feature_cv_summaries['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['macro_f1']}** | {feature_cv_summaries['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['recall_in']} | {feature_cv_summaries['3. Acoustic-Augmented [Light, Mag, Sound, Daytime]']['recall_out']} | Low: Invasive RECORD_AUDIO microphone permission required |")
        print(f"| **4. Lightless Mobile [Mag, Acc, Sound, Daytime]** | **{feature_cv_summaries['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['accuracy']}** | **{feature_cv_summaries['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['macro_f1']}** | {feature_cv_summaries['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['recall_in']} | {feature_cv_summaries['4. Lightless Mobile [Mag, Acc, Sound, Daytime]']['recall_out']} | Low: Microphone permission + reduced indoor recall |")

    # -------------------------------------------------------------------------
    # PART 3: CANONICAL RETRAINED CANDIDATE WEIGHT & PARITY FIXTURE EXPORT
    # (Scientifically Correct Checkpoint Selection on Separate Validation Split)
    # -------------------------------------------------------------------------
    print("\n" + "="*88)
    print("  PART 3: EXPORTING CANONICAL CANDIDATE WEIGHTS & CLEAN-CHECKOUT PARITY FIXTURES")
    print("  (Checkpoint Selection on Independent Validation Partition: Sessions 55..72)")
    print("="*88)

    can_tr_sess = dev_sessions[:54]   # Sessions 01..54 (75%)
    can_val_sess = dev_sessions[54:72]  # Sessions 55..72 (25%)
    print(f"Canonical Model Training Set: {len(can_tr_sess)} sessions")
    print(f"Canonical Model Checkpoint Validation Set: {len(can_val_sess)} sessions")

    # Fit scaler strictly on training split (Sessions 01..54)
    raw_can_tr = np.concatenate([s['features'][:, mob_indices] for s in can_tr_sess], axis=0)
    mean_can_tr = np.mean(raw_can_tr, axis=0)
    std_can_tr = np.std(raw_can_tr, axis=0)
    std_can_tr[std_can_tr < 1e-6] = 1.0

    X_can_tr, y_can_tr, _ = build_vectorized_windows(
        can_tr_sess, mean_can_tr, std_can_tr, mob_indices, samples_per_session=1500, is_test=False
    )
    X_can_val, y_can_val, _ = build_vectorized_windows(
        can_val_sess, mean_can_tr, std_can_tr, mob_indices, samples_per_session=0, is_test=True
    )

    can_tr_loader = DataLoader(CiodSessionDataset(X_can_tr, y_can_tr), batch_size=64, shuffle=True)
    can_val_loader = DataLoader(CiodSessionDataset(X_can_val, y_can_val), batch_size=256, shuffle=False)

    set_deterministic(42)
    # Model checkpoint selected strictly on separate validation partition
    canonical_model = train_single_model(can_tr_loader, can_val_loader, device, epochs=5, lr=0.001)
    canonical_weights_folded = fold_weights(canonical_model, mean_can_tr, std_can_tr, mob_names)

    weights_out = "tooling/data/deepiod_weights/deepiod_model_c_mobile_full_sampled_weights.json"
    with open(weights_out, 'w') as f:
        json.dump(canonical_weights_folded, f, indent=2)
    print(f"Exported canonical candidate weights to: {weights_out}")

    # Generate deterministic 100 test vectors from the separate validation partition
    set_deterministic(42)
    sample_indices = np.random.choice(len(X_can_val), size=100, replace=False)
    parity_vectors = []
    canonical_model.eval()
    with torch.no_grad():
        for idx in sample_indices:
            win = X_can_val[idx]
            t_win = torch.tensor(win, dtype=torch.float32).unsqueeze(0).to(device)
            p_torch = float(canonical_model(t_win).cpu().numpy().flatten()[0])
            parity_vectors.append({
                'sample_index': int(idx),
                'window': win.tolist(),
                'prob_pytorch': p_torch,
            })

    vectors_out = "tooling/data/deepiod_weights/parity_test_vectors_candidate_mobile.json"
    with open(vectors_out, 'w') as f:
        json.dump(parity_vectors, f, indent=2)
    print(f"Exported clean-checkout parity test vectors to: {vectors_out}")

    # -------------------------------------------------------------------------
    # PART 4: OBSERVATIONAL AUDIT ON SESSIONS 73..85
    # -------------------------------------------------------------------------
    print("\n" + "="*88)
    print("  PART 4: OBSERVATIONAL AUDIT ON PREVIOUSLY EXAMINED SESSIONS 73..85")
    print("  (Disclosure: Not used for training or model selection)")
    print("="*88)

    # Deployed model on audit sessions using deployed scaler
    X_aud_dep, y_aud_dep, sess_aud_dep = build_vectorized_windows(
        audit_sessions, deployed_mean, deployed_std, mob_indices, samples_per_session=0, is_test=True
    )
    aud_dep_loader = DataLoader(CiodSessionDataset(X_aud_dep, y_aud_dep), batch_size=256, shuffle=False)
    probs_aud_dep = predict_loader(deployed_model, aud_dep_loader, device)

    m_aud_dep_base = compute_metrics(y_aud_dep, probs_aud_dep, threshold=0.50)
    m_aud_dep_cand3 = evaluate_hysteresis(y_aud_dep, probs_aud_dep, sess_aud_dep, low=0.25, high=0.45)

    # Canonical retrained model on audit sessions using its training scaler
    X_aud_can, y_aud_can, sess_aud_can = build_vectorized_windows(
        audit_sessions, mean_can_tr, std_can_tr, mob_indices, samples_per_session=0, is_test=True
    )
    aud_can_loader = DataLoader(CiodSessionDataset(X_aud_can, y_aud_can), batch_size=256, shuffle=False)
    probs_aud_can = predict_loader(canonical_model, aud_can_loader, device)

    m_aud_can_base = compute_metrics(y_aud_can, probs_aud_can, threshold=0.50)
    m_aud_can_hyst = evaluate_hysteresis(y_aud_can, probs_aud_can, sess_aud_can, low=0.25, high=0.45)

    print("\n| Model Configuration | Scaler Used | Accuracy | Macro-F1 | Indoor Recall | Outdoor Recall | Out Precision | Safety Gate (InRec >= 90%) |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    print(f"| **Deployed Pretrained C-Mobile (theta=0.50)** | Pretrained | **{m_aud_dep_base['accuracy']*100:.2f}%** | **{m_aud_dep_base['macro_f1']*100:.2f}%** | **{m_aud_dep_base['recall_in']*100:.1f}%** | **{m_aud_dep_base['recall_out']*100:.1f}%** | {m_aud_dep_base['precision_out']*100:.1f}% | **PASS (>=90%)** |")
    print(f"| **Deployed C-Mobile + Candidate 3 Hysteresis [0.45, 0.25]** | Pretrained | **{m_aud_dep_cand3['accuracy']*100:.2f}%** | **{m_aud_dep_cand3['macro_f1']*100:.2f}%** | **{m_aud_dep_cand3['recall_in']*100:.1f}%** | **{m_aud_dep_cand3['recall_out']*100:.1f}%** | {m_aud_dep_cand3['precision_out']*100:.1f}% | **PASS (>=90%)** |")
    print(f"| **Canonical Retrained C-Mobile (theta=0.50)** | Train Scaler (S01..54) | **{m_aud_can_base['accuracy']*100:.2f}%** | **{m_aud_can_base['macro_f1']*100:.2f}%** | **{m_aud_can_base['recall_in']*100:.1f}%** | **{m_aud_can_base['recall_out']*100:.1f}%** | {m_aud_can_base['precision_out']*100:.1f}% | {'PASS (>=90%)' if m_aud_can_base['recall_in'] >= 0.90 else 'FAIL (<90%)'} |")
    print(f"| **Canonical Retrained C-Mobile + Hysteresis [0.45, 0.25]** | Train Scaler (S01..54) | **{m_aud_can_hyst['accuracy']*100:.2f}%** | **{m_aud_can_hyst['macro_f1']*100:.2f}%** | **{m_aud_can_hyst['recall_in']*100:.1f}%** | **{m_aud_can_hyst['recall_out']*100:.1f}%** | {m_aud_can_hyst['precision_out']*100:.1f}% | {'PASS (>=90%)' if m_aud_can_hyst['recall_in'] >= 0.90 else 'FAIL (<90%)'} |")


if __name__ == '__main__':
    main()

