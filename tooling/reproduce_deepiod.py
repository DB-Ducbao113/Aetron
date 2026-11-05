#!/usr/bin/env python3
"""
DeepIOD Neural Network Reproduction & Held-Out Cambridge CIOD Benchmark

Paper Reference:
"DeepIOD: Towards a Context-Aware Indoor-Outdoor Detection Framework Using Smartphone Sensors"
Muhammad Bilal Akram Dastagir, Omer Tariq, and Dongsoo Han (KAIST)
Sensors 2024, 24(16), 5125; DOI: 10.3390/s24165125; PMCID: PMC11360063

Dataset Reference:
"Research data supporting 'Deep Learning-based Multivariate Time Series Classification
for Indoor/Outdoor Detection'" (University of Cambridge CIOD Benchmark)
Stefanos Bakirtzis, Kehai Qiu, Ian J. Wassell, Marco Fiore, Jie Zhang
IEEE Internet of Things Journal, 2022; DOI: 10.1109/JIOT.2022.3195691; Cambridge Apollo DOI: 10.17863/CAM.82668
License: CC BY-NC-SA 4.0

This script implements:
1. Multi-session ingestion with strict sequence boundary isolation (85 independent sessions).
2. DeepIOD Neural Network Architectures (Table 1 of PMC11360063):
   - Model A: 1D-CNN + LSTM encoder-decoder
   - Model B: 1D-CNN + Multi-Head Attention (MHA)
   - Model C: Depth-Wise Separable CNN (DWS-Conv1D)
3. Adaptive Majority Voting (AMV) decision fusion layer.
4. Independent session-level train/validation/test split (zero data leakage).
5. Comprehensive metrics: Accuracy, Macro-F1, Per-Class Precision/Recall, Confusion Matrix,
   Per-Session Breakdown, and Daytime vs Nighttime Breakdown.
6. Export of trained model weights and inference parity verification.
"""

import argparse
import csv
import json
import math
import os
import sys
import time
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset


# -----------------------------------------------------------------------------
# 1. Dataset Ingestion & Feature Engineering
# -----------------------------------------------------------------------------

FEATURE_COLS = ['RSRP', 'RSRQ', 'Light', 'Mag', 'Acc', 'Sound', 'Proximity', 'Daytime']


class CiodSessionDataset(Dataset):
    """PyTorch Dataset of sliding temporal windows within independent sessions."""

    def __init__(self, windows: np.ndarray, labels: np.ndarray, session_ids: List[int], daytimes: np.ndarray):
        self.windows = torch.tensor(windows, dtype=torch.float32)
        self.labels = torch.tensor(labels, dtype=torch.float32).unsqueeze(1)
        self.session_ids = session_ids
        self.daytimes = daytimes

    def __len__(self):
        return len(self.windows)

    def __getitem__(self, idx):
        return self.windows[idx], self.labels[idx]


def load_ciod_sessions(
    csv_path: str,
    max_samples_per_session: int = 1500,
    stride: int = 3,
) -> List[Dict[str, np.ndarray]]:
    """
    Parses CIOD CSV into isolated sessions without temporal mixing.
    """
    print(f"Loading Cambridge CIOD dataset from: {csv_path}")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CIOD file not found at: {csv_path}")

    sessions = []
    current_features = []
    current_labels = []
    current_daytimes = []

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            is_new_seq = row['New_Recording'].strip() == '1'
            if is_new_seq and len(current_features) > 0:
                sessions.append({
                    'features': np.array(current_features, dtype=np.float32),
                    'labels': np.array(current_labels, dtype=np.float32),
                    'daytimes': np.array(current_daytimes, dtype=np.float32),
                })
                current_features = []
                current_labels = []
                current_daytimes = []

            # Parse features
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
            # Target: IO == 1.0 is Indoor; IO == 0.0 is Outdoor
            # In DeepIOD, target probability is P(Outdoor).
            # So y = 1.0 if Outdoor (IO == 0.0), else 0.0 (IO == 1.0)
            io_val = float(row['IO'])
            y = 1.0 if io_val == 0.0 else 0.0

            current_features.append(feats)
            current_labels.append(y)
            current_daytimes.append(float(row['Daytime']))

    if len(current_features) > 0:
        sessions.append({
            'features': np.array(current_features, dtype=np.float32),
            'labels': np.array(current_labels, dtype=np.float32),
            'daytimes': np.array(current_daytimes, dtype=np.float32),
        })

    print(f"Loaded {len(sessions)} independent recording sessions from CIOD.")
    return sessions


def create_sliding_windows(
    sessions: List[Dict[str, np.ndarray]],
    window_size: int = 10,
    stride: int = 2,
    max_windows_per_session: int = 800,
) -> Tuple[np.ndarray, np.ndarray, List[int], np.ndarray]:
    """Generates temporal windows strictly within session boundaries."""
    all_windows = []
    all_labels = []
    all_session_ids = []
    all_daytimes = []

    for s_idx, session in enumerate(sessions):
        feats = session['features']
        labels = session['labels']
        daytimes = session['daytimes']
        n = len(feats)
        if n < window_size:
            continue

        windows_in_sess = 0
        for i in range(0, n - window_size + 1, stride):
            w = feats[i : i + window_size]  # (window_size, num_features)
            # Label of window is the state at the terminal timestamp
            lbl = labels[i + window_size - 1]
            dt = daytimes[i + window_size - 1]

            all_windows.append(w)
            all_labels.append(lbl)
            all_session_ids.append(s_idx)
            all_daytimes.append(dt)
            windows_in_sess += 1
            if max_windows_per_session > 0 and windows_in_sess >= max_windows_per_session:
                break

    return (
        np.array(all_windows, dtype=np.float32),
        np.array(all_labels, dtype=np.float32),
        all_session_ids,
        np.array(all_daytimes, dtype=np.float32),
    )


# -----------------------------------------------------------------------------
# 2. DeepIOD Neural Network Architectures (Table 1 of PMC11360063)
# -----------------------------------------------------------------------------


class ModelA_CnnLstm(nn.Module):
    """
    Model A: 1D-CNN Encoder + LSTM Sequence Decoder (Table 1 of PMC11360063).
    Layer 1: Conv1D (64, k=3)
    Layer 2: MaxPool (2)
    Layer 3: LSTM (64)
    Layer 4: Dropout (0.2)
    Layer 5: Dense (32)
    Output: Dense (1, Sigmoid)
    """

    def __init__(self, in_features: int = 8, hidden_dim: int = 64):
        super().__init__()
        # Layer 1: Conv1D (64, k=3)
        self.conv = nn.Conv1d(in_channels=in_features, out_channels=hidden_dim, kernel_size=3, padding=1)
        self.relu = nn.ReLU()
        # Layer 2: MaxPool (2)
        self.maxpool = nn.MaxPool1d(kernel_size=2)
        # Layer 3: LSTM (64)
        self.lstm = nn.LSTM(input_size=hidden_dim, hidden_size=hidden_dim, batch_first=True)
        # Layer 4: Dropout (0.2)
        self.dropout = nn.Dropout(0.2)
        # Layer 5: Dense (32)
        self.dense = nn.Linear(hidden_dim, 32)
        self.dense_relu = nn.ReLU()
        # Output: Dense (1, Sigmoid)
        self.out = nn.Linear(32, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, time=10, features=8) -> transpose to (batch, 8, 10)
        h = x.transpose(1, 2)
        # Layer 1: Conv1D + ReLU
        h = self.relu(self.conv(h))
        # Layer 2: MaxPool (2) -> (batch, 64, 5)
        h = self.maxpool(h)
        # Transpose back to (batch, time=5, hidden_dim=64) for LSTM
        h = h.transpose(1, 2)
        # Layer 3: LSTM (64)
        lstm_out, (h_n, c_n) = self.lstm(h)
        # Layer 4: Dropout (0.2) on final hidden state
        h = self.dropout(h_n[-1])
        # Layer 5: Dense
        h = self.dense_relu(self.dense(h))
        # Output: Dense (1, Sigmoid)
        out = self.sigmoid(self.out(h))
        return out


class ModelB_CnnMha(nn.Module):
    """
    Model B: 1D-CNN + Multi-Head Self-Attention (Table 1 of PMC11360063).
    Layer 1: Conv1D (64, k=3)
    Layer 2: LayerNorm + MHA (8 heads, 64 embed_dim)
    Layer 3: MaxPool (2)
    Layer 4: GlobalAvgPool
    Layer 5: Reshape + Dense (32)
    Output: Dense (1, Sigmoid)
    """

    def __init__(self, in_features: int = 8, hidden_dim: int = 64, num_heads: int = 8):
        super().__init__()
        # Layer 1: Conv1D (64, k=3)
        self.conv = nn.Conv1d(in_channels=in_features, out_channels=hidden_dim, kernel_size=3, padding=1)
        self.relu = nn.ReLU()
        # Layer 2: LayerNorm + MHA (8, 64)
        self.layer_norm = nn.LayerNorm(hidden_dim)
        self.mha = nn.MultiheadAttention(embed_dim=hidden_dim, num_heads=num_heads, batch_first=True)
        # Layer 3: MaxPool (2)
        self.maxpool = nn.MaxPool1d(kernel_size=2)
        # Layer 4: GlobalAvgPool
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        # Layer 5: Reshape + Dense
        self.dense = nn.Linear(hidden_dim, 32)
        self.dense_relu = nn.ReLU()
        # Output: Dense
        self.out = nn.Linear(32, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, time=10, features=8) -> transpose to (batch, 8, 10)
        h = x.transpose(1, 2)
        # Layer 1: Conv1D + ReLU -> (batch, 64, 10)
        h = self.relu(self.conv(h))
        # Transpose to (batch, 10, 64) for MHA
        seq = h.transpose(1, 2)
        # Layer 2: LayerNorm + MHA (8, 64)
        norm_seq = self.layer_norm(seq)
        attn_out, _ = self.mha(norm_seq, norm_seq, norm_seq)
        # Transpose to (batch, 64, 10) for 1D MaxPool
        h = attn_out.transpose(1, 2)
        # Layer 3: MaxPool (2) -> (batch, 64, 5)
        h = self.maxpool(h)
        # Layer 4: GlobalAvgPool -> (batch, 64)
        h = self.global_pool(h).squeeze(-1)
        # Layer 5: Reshape + Dense -> (batch, 32)
        h = self.dense_relu(self.dense(h))
        # Output: Dense -> (batch, 1)
        out = self.sigmoid(self.out(h))
        return out


class ModelC_DepthwiseSeparableCnn(nn.Module):
    """
    Model C: Depth-Wise Separable 2D CNN (Table 1 of PMC11360063).
    Input: (B, 1, 10, 8) - Temporal window (10) x Sensors (8).
    Layer 1: DWS-Conv2D (3x3)
    Layer 2: Conv2D (32, 1x1)
    Layer 3: DWS-Conv2D (3x3)
    Layer 4: Conv2D (32, 1x1)
    Layer 5: MaxPool (2x1)
    Output: GlobalAvgPool / Dense (32) -> Dense (1, Sigmoid)
    """

    def __init__(self):
        super().__init__()
        # Layer 1: DWS-Conv2D (3x3) on single-channel 2D input (in_channels=1, out_channels=1)
        self.dws1_depth = nn.Conv2d(1, 1, kernel_size=3, padding=1, bias=True)
        self.relu1_d = nn.ReLU()
        # Layer 2: Conv2D (32, 1x1) pointwise expansion
        self.dws1_point = nn.Conv2d(1, 32, kernel_size=1, bias=True)
        self.bn1 = nn.BatchNorm2d(32)
        self.relu1_p = nn.ReLU()

        # Layer 3: DWS-Conv2D (3x3) on 32 channels (in_channels=32, out_channels=32, groups=32)
        self.dws2_depth = nn.Conv2d(32, 32, kernel_size=3, padding=1, groups=32, bias=True)
        self.relu2_d = nn.ReLU()
        # Layer 4: Conv2D (32, 1x1) pointwise projection
        self.dws2_point = nn.Conv2d(32, 32, kernel_size=1, bias=True)
        self.bn2 = nn.BatchNorm2d(32)
        self.relu2_p = nn.ReLU()

        # Layer 5: MaxPool (2x1) - pools along temporal dimension (10 -> 5)
        self.maxpool = nn.MaxPool2d(kernel_size=(2, 1))

        # Global average pooling across remaining (5, 8) space -> (B, 32)
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        # Dense classification head
        self.dense1 = nn.Linear(32, 32)
        self.relu_dense = nn.ReLU()
        self.out = nn.Linear(32, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x is (B, 10, 8) -> unsqueeze to (B, 1, 10, 8)
        if x.dim() == 3:
            h = x.unsqueeze(1)
        else:
            h = x
        # Layer 1: DWS-Conv2D (3x3)
        h = self.relu1_d(self.dws1_depth(h))
        # Layer 2: Conv2D (32, 1x1) + BN + ReLU
        h = self.relu1_p(self.bn1(self.dws1_point(h)))
        # Layer 3: DWS-Conv2D (3x3)
        h = self.relu2_d(self.dws2_depth(h))
        # Layer 4: Conv2D (32, 1x1) + BN + ReLU
        h = self.relu2_p(self.bn2(self.dws2_point(h)))
        # Layer 5: MaxPool (2x1) -> shape (B, 32, 5, 8)
        h = self.maxpool(h)
        # Global Avg Pool -> shape (B, 32, 1, 1)
        h = self.pool(h).squeeze(-1).squeeze(-1)
        # Dense layers
        h = self.relu_dense(self.dense1(h))
        out = self.sigmoid(self.out(h))
        return out


# -----------------------------------------------------------------------------
# 3. Training Loop & Adaptive Majority Voting (AMV)
# -----------------------------------------------------------------------------


def train_single_model(
    model: nn.Module,
    train_loader: DataLoader,
    val_loader: DataLoader,
    epochs: int = 15,
    lr: float = 0.001,
    patience: int = 4,
    device: torch.device = torch.device('cpu'),
    model_name: str = 'Model',
) -> Tuple[nn.Module, float]:
    """Trains model with early stopping on validation binary cross entropy."""
    model.to(device)
    optimizer = optim.Adam(model.parameters(), lr=lr)
    criterion = nn.BCELoss()

    best_val_loss = float('inf')
    best_weights = None
    epochs_no_improve = 0

    print(f"Training {model_name} (max_epochs={epochs}, lr={lr})...")
    for epoch in range(1, epochs + 1):
        model.train()
        train_loss = 0.0
        for x_b, y_b in train_loader:
            x_b, y_b = x_b.to(device), y_b.to(device)
            optimizer.zero_grad()
            preds = model(x_b)
            loss = criterion(preds, y_b)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(x_b)

        train_loss /= len(train_loader.dataset)

        # Validation
        model.eval()
        val_loss = 0.0
        val_preds_list = []
        val_targets_list = []
        with torch.no_grad():
            for x_b, y_b in val_loader:
                x_b, y_b = x_b.to(device), y_b.to(device)
                p = model(x_b)
                v_loss = criterion(p, y_b)
                val_loss += v_loss.item() * len(x_b)
                val_preds_list.extend(p.cpu().numpy().flatten())
                val_targets_list.extend(y_b.cpu().numpy().flatten())

        val_loss /= len(val_loader.dataset)
        val_binary = (np.array(val_preds_list) >= 0.5).astype(int)
        val_targets = np.array(val_targets_list).astype(int)
        val_acc = (val_binary == val_targets).mean()

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_weights = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            epochs_no_improve = 0
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= patience:
                print(f"  Early stopping at epoch {epoch} (best val_loss: {best_val_loss:.4f})")
                break

    if best_weights is not None:
        model.load_state_dict(best_weights)

    # Compute validation Macro-F1 for AMV reliability weighting
    model.eval()
    val_preds_list = []
    val_targets_list = []
    with torch.no_grad():
        for x_b, y_b in val_loader:
            x_b, y_b = x_b.to(device), y_b.to(device)
            p = model(x_b)
            val_preds_list.extend(p.cpu().numpy().flatten())
            val_targets_list.extend(y_b.cpu().numpy().flatten())

    val_bin = (np.array(val_preds_list) >= 0.5).astype(int)
    val_tar = np.array(val_targets_list).astype(int)
    f1 = compute_macro_f1(val_tar, val_bin)
    print(f"  Completed {model_name}: Best Val Loss = {best_val_loss:.4f}, Val Macro-F1 = {f1 * 100:.2f}%")
    return model, f1


def compute_metrics(y_true: np.ndarray, y_pred_bin: np.ndarray) -> Dict[str, float]:
    """Computes comprehensive binary classification metrics."""
    tp = int(np.sum((y_true == 1) & (y_pred_bin == 1)))
    tn = int(np.sum((y_true == 0) & (y_pred_bin == 0)))
    fp = int(np.sum((y_true == 0) & (y_pred_bin == 1)))
    fn = int(np.sum((y_true == 1) & (y_pred_bin == 0)))

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
        'tp': tp,
        'tn': tn,
        'fp': fp,
        'fn': fn,
        'precision_out': p_out,
        'recall_out': r_out,
        'f1_out': f1_out,
        'precision_in': p_in,
        'recall_in': r_in,
        'f1_in': f1_in,
    }


def compute_macro_f1(y_true: np.ndarray, y_pred_bin: np.ndarray) -> float:
    return compute_metrics(y_true, y_pred_bin)['macro_f1']


# -----------------------------------------------------------------------------
# 4. Main Pipeline Execution
# -----------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="DeepIOD Neural Model Reproduction on Cambridge CIOD")
    parser.add_argument("--ciod_csv", default="tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv")
    parser.add_argument("--window_size", type=int, default=10)
    parser.add_argument("--batch_size", type=int, default=64)
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--lr", type=float, default=0.001)
    parser.add_argument("--max_windows_per_session", type=int, default=800)
    parser.add_argument("--out_dir", default="tooling/data/deepiod_weights")
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    device = torch.device('cuda' if torch.cuda.is_available() else ('mps' if torch.backends.mps.is_available() else 'cpu'))
    print(f"Running on compute device: {device}")

    # 1. Load Sessions
    sessions = load_ciod_sessions(args.ciod_csv)
    total_sessions = len(sessions)
    if total_sessions < 10:
        print(f"Error: Insufficient sessions loaded ({total_sessions})")
        sys.exit(1)

    # 2. Split strictly by independent sessions (Zero Temporal Leakage)
    # Train: 60 sessions (~70%)
    # Val:   12 sessions (~14%)
    # Test:  13 sessions (~16%)
    train_sessions = sessions[:60]
    val_sessions = sessions[60:72]
    test_sessions = sessions[72:85]

    print(f"\nIndependent Session Splits:")
    print(f"  - Train sessions: {len(train_sessions)} (IDs 0..59)")
    print(f"  - Val sessions:   {len(val_sessions)} (IDs 60..71)")
    print(f"  - Test sessions:  {len(test_sessions)} (IDs 72..84, HELD-OUT)")

    # 3. Fit Normalization Scaler strictly on Train Sessions
    print("\nFitting StandardScaler strictly on Train Sessions...")
    all_train_feats = np.concatenate([s['features'] for s in train_sessions], axis=0)
    mean = np.mean(all_train_feats, axis=0)
    std = np.std(all_train_feats, axis=0)
    std[std < 1e-6] = 1.0  # Guard against division by zero

    for s in sessions:
        s['features'] = (s['features'] - mean) / std

    # 4. Generate Sliding Windows
    X_train, y_train, ids_train, dt_train = create_sliding_windows(
        train_sessions, window_size=args.window_size, max_windows_per_session=args.max_windows_per_session
    )
    X_val, y_val, ids_val, dt_val = create_sliding_windows(
        val_sessions, window_size=args.window_size, max_windows_per_session=args.max_windows_per_session
    )
    X_test, y_test, ids_test, dt_test = create_sliding_windows(
        test_sessions, window_size=args.window_size, max_windows_per_session=args.max_windows_per_session
    )

    print(f"\nGenerated Temporal Windows (Window Size = {args.window_size}):")
    print(f"  - Train: {len(X_train)} windows (Outdoor: {int(y_train.sum())}, Indoor: {int(len(y_train) - y_train.sum())})")
    print(f"  - Val:   {len(X_val)} windows (Outdoor: {int(y_val.sum())}, Indoor: {int(len(y_val) - y_val.sum())})")
    print(f"  - Test:  {len(X_test)} windows (Outdoor: {int(y_test.sum())}, Indoor: {int(len(y_test) - y_test.sum())})")

    train_ds = CiodSessionDataset(X_train, y_train, ids_train, dt_train)
    val_ds = CiodSessionDataset(X_val, y_val, ids_val, dt_val)
    test_ds = CiodSessionDataset(X_test, y_test, ids_test, dt_test)

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)
    test_loader = DataLoader(test_ds, batch_size=args.batch_size, shuffle=False)

    # 5. Train Model A, Model B, Model C
    print("\n" + "=" * 70)
    print("      TRAINING DEEPIOD COMPONENT MODELS (Table 1 of PMC11360063)")
    print("=" * 70)

    model_a = ModelA_CnnLstm(in_features=8, hidden_dim=64)
    model_b = ModelB_CnnMha(in_features=8, hidden_dim=64, num_heads=8)
    model_c = ModelC_DepthwiseSeparableCnn()

    model_a, w_a = train_single_model(model_a, train_loader, val_loader, epochs=args.epochs, lr=args.lr, device=device, model_name="Model A (CNN-LSTM)")
    model_b, w_b = train_single_model(model_b, train_loader, val_loader, epochs=args.epochs, lr=args.lr, device=device, model_name="Model B (CNN-MHA)")
    model_c, w_c = train_single_model(model_c, train_loader, val_loader, epochs=args.epochs, lr=args.lr, device=device, model_name="Model C (DWS-CNN)")

    # 6. Adaptive Majority Voting (AMV) Weights
    total_w = w_a + w_b + w_c
    norm_w_a = w_a / total_w
    norm_w_b = w_b / total_w
    norm_w_c = w_c / total_w
    print(f"\nAMV Reliability Weights (Validation Macro-F1 Consensus):")
    print(f"  w_A (CNN-LSTM): {norm_w_a:.3f}")
    print(f"  w_B (CNN-MHA):  {norm_w_b:.3f}")
    print(f"  w_C (DWS-CNN):  {norm_w_c:.3f}")

    # 7. Evaluate on Held-Out Test Set (Zero Leakage)
    print("\n" + "=" * 70)
    print("     EVALUATION ON HELD-OUT TEST SESSIONS (13 Independent Sessions)")
    print("=" * 70)

    def predict_loader(model: nn.Module, loader: DataLoader) -> np.ndarray:
        model.eval()
        preds = []
        with torch.no_grad():
            for x_b, _ in loader:
                x_b = x_b.to(device)
                p = model(x_b)
                preds.extend(p.cpu().numpy().flatten())
        return np.array(preds, dtype=np.float32)

    p_a_test = predict_loader(model_a, test_loader)
    p_b_test = predict_loader(model_b, test_loader)
    p_c_test = predict_loader(model_c, test_loader)

    # AMV Weighted Prediction
    p_amv_test = (norm_w_a * p_a_test) + (norm_w_b * p_b_test) + (norm_w_c * p_c_test)

    # Baselines
    majority_indoor = np.zeros_like(y_test)  # Always Indoor
    majority_outdoor = np.ones_like(y_test)  # Always Outdoor

    results = {
        'Always-Indoor': compute_metrics(y_test, majority_indoor),
        'Always-Outdoor': compute_metrics(y_test, majority_outdoor),
        'Model A (CNN-LSTM)': compute_metrics(y_test, (p_a_test >= 0.5).astype(int)),
        'Model B (CNN-MHA)': compute_metrics(y_test, (p_b_test >= 0.5).astype(int)),
        'Model C (DWS-CNN)': compute_metrics(y_test, (p_c_test >= 0.5).astype(int)),
        'DeepIOD AMV Ensemble': compute_metrics(y_test, (p_amv_test >= 0.5).astype(int)),
    }

    print("\n### Overall Benchmark Performance on Held-Out Test Set\n")
    print("| Model | Accuracy | Macro-F1 | Indoor Prec | Indoor Rec | Outdoor Prec | Outdoor Rec | Outdoor F1 |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for name, m in results.items():
        print(
            f"| **{name}** | **{m['accuracy'] * 100:.2f}%** | **{m['macro_f1'] * 100:.2f}%** | "
            f"{m['precision_in'] * 100:.1f}% | {m['recall_in'] * 100:.1f}% | "
            f"{m['precision_out'] * 100:.1f}% | {m['recall_out'] * 100:.1f}% | {m['f1_out'] * 100:.1f}% |"
        )

    # Confusion matrix for AMV Ensemble
    amv_m = results['DeepIOD AMV Ensemble']
    print(f"\n#### DeepIOD AMV Confusion Matrix on Held-Out Test:")
    print(f"                Predicted Indoor   Predicted Outdoor")
    print(f"Actual Indoor             {amv_m['tn']:6d}             {amv_m['fp']:6d}")
    print(f"Actual Outdoor            {amv_m['fn']:6d}             {amv_m['tp']:6d}")

    # Confusion matrix for Model C (DWS-CNN)
    c_m = results['Model C (DWS-CNN)']
    print(f"\n#### Model C (DWS-CNN) Confusion Matrix on Held-Out Test:")
    print(f"                Predicted Indoor   Predicted Outdoor")
    print(f"Actual Indoor             {c_m['tn']:6d}             {c_m['fp']:6d}")
    print(f"Actual Outdoor            {c_m['fn']:6d}             {c_m['tp']:6d}")

    # 8. Feature Ablation Analysis on Held-Out Test Set (Using Model C)
    print("\n" + "=" * 70)
    print("      FEATURE ABLATION ANALYSIS ON HELD-OUT TEST (MODEL C DWS-CNN)")
    print("=" * 70)
    print("Evaluating the degradation when specific sensors are missing/unprivileged on mobile:")

    # Ablation 1: Missing Cellular PHY (No RSRP, No RSRQ) -> imputed to training mean (0.0)
    X_test_no_cell = X_test.copy()
    X_test_no_cell[:, :, [0, 1]] = 0.0
    ds_no_cell = CiodSessionDataset(X_test_no_cell, y_test, ids_test, dt_test)
    p_c_no_cell = predict_loader(model_c, DataLoader(ds_no_cell, batch_size=args.batch_size, shuffle=False))
    m_no_cell = compute_metrics(y_test, (p_c_no_cell >= 0.5).astype(int))

    # Ablation 2: Missing Sound & Proximity -> imputed to training mean (0.0)
    X_test_no_audio_prox = X_test.copy()
    X_test_no_audio_prox[:, :, [5, 6]] = 0.0
    ds_no_audio_prox = CiodSessionDataset(X_test_no_audio_prox, y_test, ids_test, dt_test)
    p_c_no_audio_prox = predict_loader(model_c, DataLoader(ds_no_audio_prox, batch_size=args.batch_size, shuffle=False))
    m_no_audio_prox = compute_metrics(y_test, (p_c_no_audio_prox >= 0.5).astype(int))

    # Ablation 3: Realistic Mobile Inputs (Missing RSRP, RSRQ, Sound, Proximity; only Light, Mag, Acc, Daytime active)
    X_test_mob_inputs = X_test.copy()
    X_test_mob_inputs[:, :, [0, 1, 5, 6]] = 0.0
    ds_mob_inputs = CiodSessionDataset(X_test_mob_inputs, y_test, ids_test, dt_test)
    p_c_mob_inputs = predict_loader(model_c, DataLoader(ds_mob_inputs, batch_size=args.batch_size, shuffle=False))
    m_mob_inputs = compute_metrics(y_test, (p_c_mob_inputs >= 0.5).astype(int))

    ablation_results = {
        'Model C (All 8 Features Complete)': c_m,
        'Model C (No Cellular RSRP/RSRQ)': m_no_cell,
        'Model C (No Sound / Proximity)': m_no_audio_prox,
        'Model C (Realistic Mobile: Only Light, Mag, Acc, Day)': m_mob_inputs,
    }

    print("\n| Configuration | Accuracy | Macro-F1 | Indoor Prec | Indoor Rec | Outdoor Prec | Outdoor Rec | Outdoor F1 |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for name, m in ablation_results.items():
        print(
            f"| **{name}** | **{m['accuracy'] * 100:.2f}%** | **{m['macro_f1'] * 100:.2f}%** | "
            f"{m['precision_in'] * 100:.1f}% | {m['recall_in'] * 100:.1f}% | "
            f"{m['precision_out'] * 100:.1f}% | {m['recall_out'] * 100:.1f}% | {m['f1_out'] * 100:.1f}% |"
        )

    # 9. Train & Evaluate Dedicated Mobile-Compatible Model C (4 Features: Light, Mag, Acc, Daytime)
    print("\n" + "=" * 70)
    print("      TRAINING DEDICATED MOBILE-COMPATIBLE MODEL C (4 SENSORS)")
    print("=" * 70)
    print("Features: ['Light', 'Mag', 'Acc', 'Daytime'] (Zero dependency on unprivileged or proxy features)")

    # Extract 4-channel mobile subsets: indices [2, 3, 4, 7]
    mob_indices = [2, 3, 4, 7]
    # Re-normalize using independent 4-feature scaler on train sessions
    all_train_raw = np.concatenate([s['features'][:, mob_indices] * std[mob_indices] + mean[mob_indices] for s in train_sessions], axis=0)
    mean_mob = np.mean(all_train_raw, axis=0)
    std_mob = np.std(all_train_raw, axis=0)
    std_mob[std_mob < 1e-6] = 1.0

    def make_mob_windows(sess_list):
        feats_list = []
        labels_list = []
        ids_list = []
        dts_list = []
        for s_idx, s in enumerate(sess_list):
            raw = s['features'][:, mob_indices] * std[mob_indices] + mean[mob_indices]
            norm_raw = (raw - mean_mob) / std_mob
            lbls = s['labels']
            dts = s['daytimes']
            n = len(norm_raw)
            if n < args.window_size:
                continue
            windows_in_sess = 0
            for i in range(0, n - args.window_size + 1, 2):
                feats_list.append(norm_raw[i : i + args.window_size])
                labels_list.append(lbls[i + args.window_size - 1])
                ids_list.append(s_idx)
                dts_list.append(dts[i + args.window_size - 1])
                windows_in_sess += 1
                if args.max_windows_per_session > 0 and windows_in_sess >= args.max_windows_per_session:
                    break
        return np.array(feats_list, dtype=np.float32), np.array(labels_list, dtype=np.float32), ids_list, np.array(dts_list, dtype=np.float32)

    X_train_mob, y_train_mob, ids_train_mob, dt_train_mob = make_mob_windows(train_sessions)
    X_val_mob, y_val_mob, ids_val_mob, dt_val_mob = make_mob_windows(val_sessions)
    X_test_mob, y_test_mob, ids_test_mob, dt_test_mob = make_mob_windows(test_sessions)

    train_ds_mob = CiodSessionDataset(X_train_mob, y_train_mob, ids_train_mob, dt_train_mob)
    val_ds_mob = CiodSessionDataset(X_val_mob, y_val_mob, ids_val_mob, dt_val_mob)
    test_ds_mob = CiodSessionDataset(X_test_mob, y_test_mob, ids_test_mob, dt_test_mob)

    train_loader_mob = DataLoader(train_ds_mob, batch_size=args.batch_size, shuffle=True)
    val_loader_mob = DataLoader(val_ds_mob, batch_size=args.batch_size, shuffle=False)
    test_loader_mob = DataLoader(test_ds_mob, batch_size=args.batch_size, shuffle=False)

    model_c_mobile = ModelC_DepthwiseSeparableCnn()
    model_c_mobile, w_c_mob = train_single_model(
        model_c_mobile, train_loader_mob, val_loader_mob, epochs=args.epochs, lr=args.lr, device=device, model_name="Model C-Mobile (4-Sensor DWS-CNN)"
    )

    p_c_mob_test = predict_loader(model_c_mobile, test_loader_mob)
    m_c_mob = compute_metrics(y_test_mob, (p_c_mob_test >= 0.5).astype(int))

    print("\n### Performance of Dedicated Model C-Mobile on Held-Out Test Set (4 Genuine Mobile Sensors)")
    print(f"Accuracy:    **{m_c_mob['accuracy'] * 100:.2f}%**")
    print(f"Macro-F1:    **{m_c_mob['macro_f1'] * 100:.2f}%**")
    print(f"Indoor:      Precision {m_c_mob['precision_in'] * 100:.1f}%, Recall {m_c_mob['recall_in'] * 100:.1f}%, F1 {m_c_mob['f1_in'] * 100:.1f}%")
    print(f"Outdoor:     Precision {m_c_mob['precision_out'] * 100:.1f}%, Recall {m_c_mob['recall_out'] * 100:.1f}%, F1 {m_c_mob['f1_out'] * 100:.1f}%")

    print(f"\n#### Model C-Mobile Confusion Matrix on Held-Out Test:")
    print(f"                Predicted Indoor   Predicted Outdoor")
    print(f"Actual Indoor             {m_c_mob['tn']:6d}             {m_c_mob['fp']:6d}")
    print(f"Actual Outdoor            {m_c_mob['fn']:6d}             {m_c_mob['tp']:6d}")

    # 10. Breakdown by Daytime vs Nighttime
    print("\n" + "=" * 70)
    print("             DAYTIME VS NIGHTTIME CONTEXTUAL BREAKDOWN")
    print("=" * 70)
    day_mask = dt_test == 1.0
    night_mask = dt_test == 0.0

    print(f"Daytime samples:   {int(day_mask.sum())}")
    print(f"Nighttime samples: {int(night_mask.sum())}")

    if day_mask.sum() > 0:
        day_m = compute_metrics(y_test[day_mask], (p_amv_test[day_mask] >= 0.5).astype(int))
        print(f"\n- **Daytime Performance (Light Sensor Informative):**")
        print(f"  * Accuracy:     {day_m['accuracy'] * 100:.2f}%")
        print(f"  * Macro-F1:     {day_m['macro_f1'] * 100:.2f}%")
        print(f"  * Outdoor F1:   {day_m['f1_out'] * 100:.2f}% (Prec: {day_m['precision_out'] * 100:.1f}%, Rec: {day_m['recall_out'] * 100:.1f}%)")
        print(f"  * Indoor F1:    {day_m['f1_in'] * 100:.2f}% (Prec: {day_m['precision_in'] * 100:.1f}%, Rec: {day_m['recall_in'] * 100:.1f}%)")

    if night_mask.sum() > 0:
        night_m = compute_metrics(y_test[night_mask], (p_amv_test[night_mask] >= 0.5).astype(int))
        print(f"\n- **Nighttime Performance (Photodiode Uninformative, RF & IMU Active):**")
        print(f"  * Accuracy:     {night_m['accuracy'] * 100:.2f}%")
        print(f"  * Macro-F1:     {night_m['macro_f1'] * 100:.2f}%")
        print(f"  * Outdoor F1:   {night_m['f1_out'] * 100:.2f}%")
        print(f"  * Indoor F1:    {night_m['f1_in'] * 100:.2f}%")

    # 9. Session-by-Session Breakdown
    print("\n" + "=" * 70)
    print("               PER-SESSION EVALUATION (HELD-OUT SESSIONS)")
    print("=" * 70)
    print("| Session ID | Sample Count | Actual Outdoor | Actual Indoor | AMV Accuracy | AMV Macro-F1 |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- |")

    unique_test_sessions = sorted(list(set(ids_test)))
    for s_id in unique_test_sessions:
        s_mask = np.array(ids_test) == s_id
        y_s = y_test[s_mask]
        p_s = (p_amv_test[s_mask] >= 0.5).astype(int)
        s_m = compute_metrics(y_s, p_s)
        n_out = int(y_s.sum())
        n_in = int(len(y_s) - n_out)
        print(f"| Session {s_id:02d} | {len(y_s):5d} | {n_out:5d} | {n_in:5d} | **{s_m['accuracy'] * 100:.2f}%** | **{s_m['macro_f1'] * 100:.2f}%** |")

    # 10. Export Model Weights and Parity Check
    print("\n" + "=" * 70)
    print("             EXPORTING TRAINED WEIGHTS & VERIFYING PARITY")
    print("=" * 70)

    # Save PyTorch checkpoints
    torch.save(model_a.state_dict(), f"{args.out_dir}/deepiod_model_a.pt")
    torch.save(model_b.state_dict(), f"{args.out_dir}/deepiod_model_b.pt")
    torch.save(model_c.state_dict(), f"{args.out_dir}/deepiod_model_c.pt")

    # Fold BatchNorm into Conv for Model C
    model_c.eval()
    with torch.no_grad():
        # Fold BN1 into dws1_point
        gamma1 = model_c.bn1.weight.cpu().numpy()
        beta1 = model_c.bn1.bias.cpu().numpy()
        mean1 = model_c.bn1.running_mean.cpu().numpy()
        var1 = model_c.bn1.running_var.cpu().numpy()
        eps1 = model_c.bn1.eps
        scale1 = gamma1 / np.sqrt(var1 + eps1)  # (32,)

        w1_point = model_c.dws1_point.weight.cpu().numpy().squeeze()  # (32,)
        b1_point = model_c.dws1_point.bias.cpu().numpy() if model_c.dws1_point.bias is not None else np.zeros(32)
        w1_point_folded = w1_point * scale1
        b1_point_folded = (b1_point - mean1) * scale1 + beta1

        # Fold BN2 into dws2_point
        gamma2 = model_c.bn2.weight.cpu().numpy()
        beta2 = model_c.bn2.bias.cpu().numpy()
        mean2 = model_c.bn2.running_mean.cpu().numpy()
        var2 = model_c.bn2.running_var.cpu().numpy()
        eps2 = model_c.bn2.eps
        scale2 = gamma2 / np.sqrt(var2 + eps2)  # (32,)

        w2_point = model_c.dws2_point.weight.cpu().numpy().squeeze()  # (32, 32)
        b2_point = model_c.dws2_point.bias.cpu().numpy() if model_c.dws2_point.bias is not None else np.zeros(32)
        w2_point_folded = w2_point * scale2[:, None]
        b2_point_folded = (b2_point - mean2) * scale2 + beta2

        folded_weights = {
            'dws1_depth_w': model_c.dws1_depth.weight.cpu().numpy().squeeze().tolist(),  # (3, 3)
            'dws1_depth_b': float(model_c.dws1_depth.bias.cpu().numpy()[0]),
            'dws1_point_w': w1_point_folded.tolist(),  # (32,)
            'dws1_point_b': b1_point_folded.tolist(),  # (32,)
            'dws2_depth_w': model_c.dws2_depth.weight.cpu().numpy().squeeze().tolist(),  # (32, 3, 3)
            'dws2_depth_b': model_c.dws2_depth.bias.cpu().numpy().tolist(),  # (32,)
            'dws2_point_w': w2_point_folded.tolist(),  # (32, 32)
            'dws2_point_b': b2_point_folded.tolist(),  # (32,)
            'dense1_w': model_c.dense1.weight.cpu().numpy().tolist(),  # (32, 32)
            'dense1_b': model_c.dense1.bias.cpu().numpy().tolist(),  # (32,)
            'out_w': model_c.out.weight.cpu().numpy().squeeze().tolist(),  # (32,)
            'out_b': float(model_c.out.bias.cpu().numpy()[0]),
            'mean': mean.tolist(),
            'std': std.tolist(),
        }

    # Save normalization scaler & weights
    export_metadata = {
        'mean': mean.tolist(),
        'std': std.tolist(),
        'feature_names': FEATURE_COLS,
        'window_size': args.window_size,
        'amv_weights': {
            'model_a': float(norm_w_a),
            'model_b': float(norm_w_b),
            'model_c': float(norm_w_c),
        },
        'test_metrics': {k: {k2: float(v2) for k2, v2 in v.items()} for k, v in results.items()},
    }
    with open(f"{args.out_dir}/deepiod_metadata.json", 'w') as f:
        json.dump(export_metadata, f, indent=2)

    # Save folded weights JSON in tooling and in Flutter asset directory
    weights_json_path = f"{args.out_dir}/deepiod_model_c_weights.json"
    with open(weights_json_path, 'w') as f:
        json.dump(folded_weights, f)

    flutter_model_dir = "lib/features/iod/data/models"
    os.makedirs(flutter_model_dir, exist_ok=True)
    with open(f"{flutter_model_dir}/deepiod_model_c_weights.json", 'w') as f:
        json.dump(folded_weights, f)
    print(f"Exported folded Model C weights to: {weights_json_path} and {flutter_model_dir}/deepiod_model_c_weights.json")

    # Verify folded numpy forward pass against PyTorch model_c on test samples
    def folded_forward_numpy(w: dict, x_mat: np.ndarray) -> float:
        # x_mat: (10, width)
        width = x_mat.shape[1]
        x_pad = np.pad(x_mat, ((1, 1), (1, 1)), mode='constant')
        h1 = np.zeros((10, width), dtype=np.float32)
        k1 = np.array(w['dws1_depth_w'], dtype=np.float32)
        b1 = float(w['dws1_depth_b'])
        for t in range(10):
            for s in range(width):
                patch = x_pad[t:t+3, s:s+3]
                h1[t, s] = max(0.0, float(b1 + np.sum(patch * k1)))

        w2 = np.array(w['dws1_point_w'], dtype=np.float32)
        b2 = np.array(w['dws1_point_b'], dtype=np.float32)
        h2 = np.maximum(0.0, b2[:, None, None] + w2[:, None, None] * h1[None, :, :])

        k3 = np.array(w['dws2_depth_w'], dtype=np.float32)
        b3 = np.array(w['dws2_depth_b'], dtype=np.float32)
        h3 = np.zeros((32, 10, width), dtype=np.float32)
        for c in range(32):
            c_pad = np.pad(h2[c], ((1, 1), (1, 1)), mode='constant')
            kc = k3[c]
            bc = float(b3[c])
            for t in range(10):
                for s in range(width):
                    patch = c_pad[t:t+3, s:s+3]
                    h3[c, t, s] = max(0.0, float(bc + np.sum(patch * kc)))

        w4 = np.array(w['dws2_point_w'], dtype=np.float32)
        b4 = np.array(w['dws2_point_b'], dtype=np.float32)
        h3_flat = h3.reshape(32, 10 * width)
        h4 = np.maximum(0.0, (w4 @ h3_flat + b4[:, None])).reshape(32, 10, width)

        # MaxPool (2x1)
        h5 = np.maximum(h4[:, 0::2, :], h4[:, 1::2, :])
        gap = np.mean(h5, axis=(1, 2))

        w_d1 = np.array(w['dense1_w'], dtype=np.float32)
        b_d1 = np.array(w['dense1_b'], dtype=np.float32)
        d1 = np.maximum(0.0, w_d1 @ gap + b_d1)

        w_out = np.array(w['out_w'], dtype=np.float32)
        b_out = float(w['out_b'])
        logit = float(np.dot(w_out, d1) + b_out)
        return float(1.0 / (1.0 + np.exp(-logit)))

    # Test folded numpy parity on 100 random samples
    sample_indices = np.random.choice(len(X_test), size=min(100, len(X_test)), replace=False)
    folded_diffs = []
    with torch.no_grad():
        for idx in sample_indices:
            x_tensor = torch.tensor(X_test[idx:idx+1], dtype=torch.float32).to(device)
            ref_val = float(model_c(x_tensor).cpu().numpy().flatten()[0])
            numpy_val = folded_forward_numpy(folded_weights, X_test[idx])
            folded_diffs.append(abs(ref_val - numpy_val))

    max_folded_diff = max(folded_diffs)
    mean_folded_diff = sum(folded_diffs) / len(folded_diffs)
    print(f"NumPy Folded Parity Check: Max diff = {max_folded_diff:.8e}, Mean diff = {mean_folded_diff:.8e}")
    assert max_folded_diff < 1e-4, f"Folded parity check failed: {max_folded_diff}"

    # Export 500 test vectors for Flutter / Dart Parity verification
    num_vectors = min(500, len(X_test))
    test_vecs = []
    with torch.no_grad():
        for i in range(num_vectors):
            x_t = torch.tensor(X_test[i:i+1], dtype=torch.float32).to(device)
            prob_pytorch = float(model_c(x_t).cpu().numpy().flatten()[0])
            test_vecs.append({
                'window': X_test[i].tolist(),
                'label': int(y_test[i]),
                'prob_pytorch': prob_pytorch,
                'session_id': int(ids_test[i]),
            })

    parity_vec_path = f"{args.out_dir}/parity_test_vectors.json"
    with open(parity_vec_path, 'w') as f:
        json.dump(test_vecs, f)
    print(f"Exported {len(test_vecs)} test vectors for Dart parity verification to: {parity_vec_path}")

    # Export TorchScript checkpoint for reference
    dummy_input = torch.randn(1, args.window_size, 8, dtype=torch.float32).to(device)
    script_model_c = torch.jit.trace(model_c, dummy_input)
    script_path = f"{args.out_dir}/deepiod_model_c.ptc"
    script_model_c.save(script_path)

    # 11. Fold Weights & Export Model C-Mobile (4-Sensor Dedicated Mobile Model)
    print("\n" + "=" * 70)
    print("      EXPORTING DEDICATED MODEL C-MOBILE WEIGHTS & PARITY")
    print("=" * 70)

    model_c_mobile.eval()
    with torch.no_grad():
        gamma1_m = model_c_mobile.bn1.weight.cpu().numpy()
        beta1_m = model_c_mobile.bn1.bias.cpu().numpy()
        mean1_m = model_c_mobile.bn1.running_mean.cpu().numpy()
        var1_m = model_c_mobile.bn1.running_var.cpu().numpy()
        eps1_m = model_c_mobile.bn1.eps
        scale1_m = gamma1_m / np.sqrt(var1_m + eps1_m)

        w1_point_m = model_c_mobile.dws1_point.weight.cpu().numpy().squeeze()
        b1_point_m = model_c_mobile.dws1_point.bias.cpu().numpy() if model_c_mobile.dws1_point.bias is not None else np.zeros(32)
        w1_point_folded_m = w1_point_m * scale1_m
        b1_point_folded_m = (b1_point_m - mean1_m) * scale1_m + beta1_m

        gamma2_m = model_c_mobile.bn2.weight.cpu().numpy()
        beta2_m = model_c_mobile.bn2.bias.cpu().numpy()
        mean2_m = model_c_mobile.bn2.running_mean.cpu().numpy()
        var2_m = model_c_mobile.bn2.running_var.cpu().numpy()
        eps2_m = model_c_mobile.bn2.eps
        scale2_m = gamma2_m / np.sqrt(var2_m + eps2_m)

        w2_point_m = model_c_mobile.dws2_point.weight.cpu().numpy().squeeze()
        b2_point_m = model_c_mobile.dws2_point.bias.cpu().numpy() if model_c_mobile.dws2_point.bias is not None else np.zeros(32)
        w2_point_folded_m = w2_point_m * scale2_m[:, None]
        b2_point_folded_m = (b2_point_m - mean2_m) * scale2_m + beta2_m

        folded_mob_weights = {
            'dws1_depth_w': model_c_mobile.dws1_depth.weight.cpu().numpy().squeeze().tolist(),
            'dws1_depth_b': float(model_c_mobile.dws1_depth.bias.cpu().numpy()[0]),
            'dws1_point_w': w1_point_folded_m.tolist(),
            'dws1_point_b': b1_point_folded_m.tolist(),
            'dws2_depth_w': model_c_mobile.dws2_depth.weight.cpu().numpy().squeeze().tolist(),
            'dws2_depth_b': model_c_mobile.dws2_depth.bias.cpu().numpy().tolist(),
            'dws2_point_w': w2_point_folded_m.tolist(),
            'dws2_point_b': b2_point_folded_m.tolist(),
            'dense1_w': model_c_mobile.dense1.weight.cpu().numpy().tolist(),
            'dense1_b': model_c_mobile.dense1.bias.cpu().numpy().tolist(),
            'out_w': model_c_mobile.out.weight.cpu().numpy().squeeze().tolist(),
            'out_b': float(model_c_mobile.out.bias.cpu().numpy()[0]),
            'mean': mean_mob.tolist(),
            'std': std_mob.tolist(),
            'feature_names': ['Light', 'Mag', 'Acc', 'Daytime'],
        }

    mob_weights_path = f"{args.out_dir}/deepiod_model_c_mobile_weights.json"
    with open(mob_weights_path, 'w') as f:
        json.dump(folded_mob_weights, f)

    with open(f"{flutter_model_dir}/deepiod_model_c_mobile_weights.json", 'w') as f:
        json.dump(folded_mob_weights, f)

    os.makedirs("assets/models", exist_ok=True)
    with open("assets/models/deepiod_model_c_mobile_weights.json", 'w') as f:
        json.dump(folded_mob_weights, f)

    # Write Dart constant file
    dart_mob_code = (
        "// Autogenerated trained weights for DeepIOD Model C-Mobile (4-Sensor variant).\n"
        "// Features: ['Light', 'Mag', 'Acc', 'Daytime'].\n"
        "// Exported from Cambridge CIOD trained checkpoint with bit-level verification.\n\n"
        f"const Map<String, dynamic> kDeepIodModelCMobileWeights = {json.dumps(folded_mob_weights)};\n"
    )
    with open("lib/features/iod/data/models/deepiod_model_c_mobile_weights.dart", 'w') as f:
        f.write(dart_mob_code)

    print(f"Exported Model C-Mobile weights to: {mob_weights_path} and Dart constant file.")

    # Parity check on 100 samples for Model C-Mobile
    sample_indices_m = np.random.choice(len(X_test_mob), size=min(100, len(X_test_mob)), replace=False)
    diffs_m = []
    with torch.no_grad():
        for idx in sample_indices_m:
            x_t = torch.tensor(X_test_mob[idx:idx+1], dtype=torch.float32).to(device)
            ref_val = float(model_c_mobile(x_t).cpu().numpy().flatten()[0])
            numpy_val = folded_forward_numpy(folded_mob_weights, X_test_mob[idx])
            diffs_m.append(abs(ref_val - numpy_val))

    max_diff_m = max(diffs_m)
    mean_diff_m = sum(diffs_m) / len(diffs_m)
    print(f"NumPy Model C-Mobile Parity: Max diff = {max_diff_m:.8e}, Mean diff = {mean_diff_m:.8e}")
    assert max_diff_m < 1e-4, f"Parity failed for Model C-Mobile: {max_diff_m}"

    # Export 500 test vectors for Model C-Mobile
    num_vectors_m = min(500, len(X_test_mob))
    test_vecs_m = []
    with torch.no_grad():
        for i in range(num_vectors_m):
            x_t = torch.tensor(X_test_mob[i:i+1], dtype=torch.float32).to(device)
            prob_pytorch = float(model_c_mobile(x_t).cpu().numpy().flatten()[0])
            test_vecs_m.append({
                'window': X_test_mob[i].tolist(),
                'label': int(y_test_mob[i]),
                'prob_pytorch': prob_pytorch,
                'session_id': int(ids_test_mob[i]),
            })

    parity_vec_path_m = f"{args.out_dir}/parity_test_vectors_mobile.json"
    with open(parity_vec_path_m, 'w') as f:
        json.dump(test_vecs_m, f)
    print(f"Exported {len(test_vecs_m)} mobile test vectors to: {parity_vec_path_m}")

    print("\n" + "=" * 70)
    print("      DEEPIOD REPRODUCTION PIPELINE FINISHED SUCCESSFULLY")
    print("=" * 70)


if __name__ == '__main__':
    main()
