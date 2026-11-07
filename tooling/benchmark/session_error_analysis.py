#!/usr/bin/env python3
"""
Deep Per-Session Error Analysis for Cambridge CIOD Sessions 78, 80, and 82.
Zero third-party dependencies: strictly uses Python standard library (math, csv, sys, os).

Investigates the feature distributions distinguishing:
- False Negatives (Actual Outdoor predicted as Indoor)
- True Positives (Actual Outdoor predicted as Outdoor)
- True Negatives (Actual Indoor predicted as Indoor)
- False Positives (Actual Indoor predicted as Outdoor)
"""

import csv
import math
import os
import sys

PRED_CSV = "tooling/data/benchmark_results/ciod_full_held_out_mobile_predictions.csv"
RAW_CIOD = "tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv"

def calc_mean_std(values):
    if not values:
        return 0.0, 0.0
    n = len(values)
    mean_val = sum(values) / n
    if n < 2:
        return mean_val, 0.0
    var_val = sum((x - mean_val) ** 2 for x in values) / (n - 1)
    return mean_val, math.sqrt(var_val)

def calc_percentiles(values, percentiles):
    if not values:
        return [0.0] * len(percentiles)
    s = sorted(values)
    n = len(s)
    res = []
    for p in percentiles:
        idx = int(round((p / 100.0) * (n - 1)))
        idx = max(0, min(n - 1, idx))
        res.append(s[idx])
    return res

def analyze_sessions():
    if not os.path.exists(PRED_CSV):
        print(f"Error: {PRED_CSV} not found", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(RAW_CIOD):
        print(f"Error: {RAW_CIOD} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Loading predictions from: {PRED_CSV}")
    pred_rows = {}
    with open(PRED_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for r in reader:
            sess = r['session_id'].strip()
            if sess not in pred_rows:
                pred_rows[sess] = []
            pred_rows[sess].append({
                'gt': r['ground_truth'].strip().lower(),
                'pred': r['predicted_state'].strip().lower(),
                'prob': float(r['deepiod_outdoor_score']) if r.get('deepiod_outdoor_score') else float(r['class_probability']),
            })

    target_sessions = ['CIOD_session_78', 'CIOD_session_80', 'CIOD_session_82']
    print(f"Target sessions: {target_sessions}")

    print(f"Loading raw features from: {RAW_CIOD}...")
    raw_sessions = {}
    current_sess_id = 0
    current_feats = []
    with open(RAW_CIOD, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['New_Recording'].strip() == '1' and len(current_feats) > 0:
                current_sess_id += 1
                sess_name = f"CIOD_session_{current_sess_id}"
                raw_sessions[sess_name] = current_feats
                current_feats = []

            feats = {
                'RSRP': float(row['RSRP']),
                'RSRQ': float(row['RSRQ']),
                'Light': float(row['Light']),
                'Mag': float(row['Mag']),
                'Acc': float(row['Acc']),
                'Sound': float(row['Sound']),
                'Proximity': float(row['Proximity']),
                'Daytime': float(row['Daytime']),
                'IO': float(row['IO']), # 1.0 = Indoor, 0.0 = Outdoor
            }
            current_feats.append(feats)

    if len(current_feats) > 0:
        current_sess_id += 1
        raw_sessions[f"CIOD_session_{current_sess_id}"] = current_feats

    print(f"Parsed {len(raw_sessions)} raw sessions.")

    feature_keys = ['Light', 'Mag', 'Acc', 'Daytime', 'Proximity', 'Sound', 'RSRP', 'RSRQ']

    for t_sess in target_sessions:
        print("\n" + "="*80)
        print(f"  DEEP FEATURE ERROR ANALYSIS FOR SESSION: {t_sess}")
        print("="*80)

        preds = pred_rows.get(t_sess, [])
        raw = raw_sessions.get(t_sess, [])
        print(f"Predictions: {len(preds)} rows | Raw data: {len(raw)} rows")

        n = min(len(preds), len(raw) - 9)
        aligned = []
        for i in range(n):
            aligned.append({
                'gt': preds[i]['gt'],
                'pred': preds[i]['pred'],
                'prob': preds[i]['prob'],
                'raw': raw[i + 9],
            })

        groups = {
            'TP_Outdoor': [x for x in aligned if x['gt'] == 'outdoor' and x['pred'] == 'outdoor'],
            'FN_Outdoor (Missed)': [x for x in aligned if x['gt'] == 'outdoor' and x['pred'] == 'indoor'],
            'TN_Indoor': [x for x in aligned if x['gt'] == 'indoor' and x['pred'] == 'indoor'],
            'FP_Indoor (False Out)': [x for x in aligned if x['gt'] == 'indoor' and x['pred'] == 'outdoor'],
        }

        print(f"Outcome Group Counts:")
        for g_name, g_items in groups.items():
            pct = (len(g_items) / n * 100) if n > 0 else 0
            print(f"  - {g_name:24s}: {len(g_items):6d} ({pct:5.1f}%)")

        print("\n--- Feature Mean +/- Std across Outcome Groups ---")
        header = f"{'Feature':12s} | " + " | ".join([f"{g:22s}" for g in groups.keys()])
        print(header)
        print("-" * len(header))

        for feat in feature_keys:
            vals_per_group = []
            for g_name, g_items in groups.items():
                if len(g_items) > 0:
                    arr = [x['raw'][feat] for x in g_items]
                    m_val, s_val = calc_mean_std(arr)
                    vals_per_group.append(f"{m_val:8.2f} +/- {s_val:6.2f}")
                else:
                    vals_per_group.append(f"{'N/A':^22s}")
            print(f"{feat:12s} | " + " | ".join(vals_per_group))

        probs_per_group = []
        for g_name, g_items in groups.items():
            if len(g_items) > 0:
                arr = [x['prob'] for x in g_items]
                m_val, s_val = calc_mean_std(arr)
                probs_per_group.append(f"{m_val:8.4f} +/- {s_val:6.4f}")
            else:
                probs_per_group.append(f"{'N/A':^22s}")
        print(f"{'P(Outdoor)':12s} | " + " | ".join(probs_per_group))

        fn_probs = [x['prob'] for x in groups['FN_Outdoor (Missed)']]
        if len(fn_probs) > 0:
            print(f"\nDistribution of P(Outdoor) for Missed Outdoor (FN) in {t_sess}:")
            percentiles = [10, 25, 50, 75, 90, 95, 99]
            q_vals = calc_percentiles(fn_probs, percentiles)
            p_str = ", ".join([f"P{p}: {v:.3f}" for p, v in zip(percentiles, q_vals)])
            print(f"  {p_str}")
            frac_25 = sum(1 for p in fn_probs if p >= 0.25) / len(fn_probs) * 100
            frac_20 = sum(1 for p in fn_probs if p >= 0.20) / len(fn_probs) * 100
            frac_15 = sum(1 for p in fn_probs if p >= 0.15) / len(fn_probs) * 100
            print(f"  Fraction of FN with P >= 0.25: {frac_25:.1f}%")
            print(f"  Fraction of FN with P >= 0.20: {frac_20:.1f}%")
            print(f"  Fraction of FN with P >= 0.15: {frac_15:.1f}%")

if __name__ == '__main__':
    analyze_sessions()
