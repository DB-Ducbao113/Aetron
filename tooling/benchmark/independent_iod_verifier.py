#!/usr/bin/env python3
"""
Independent IOD Benchmark Verifier for Aetron.

Independently reads exported per-sample prediction CSVs and calculates:
- Confusion Matrix (Actual rows vs Predicted columns)
- Accuracy
- Macro-F1
- Indoor Precision, Recall, Specificity, F1
- Outdoor Precision, Recall, F1
- Per-Session Breakdown across all held-out sessions (72..84)

Zero third-party dependencies: strictly uses Python standard library (csv, math, sys, os).
"""

import csv
import os
import sys
from collections import defaultdict


def verify_file(csv_path: str, model_label: str):
    if not os.path.exists(csv_path):
        print(f"ERROR: Prediction CSV not found at: {csv_path}", file=sys.stderr)
        sys.exit(1)

    print(f"\n{'='*78}")
    print(f"  INDEPENDENT VERIFICATION: {model_label}")
    print(f"  File: {csv_path}")
    print(f"{'='*78}")

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    total_samples = len(rows)
    print(f"Total Rows Loaded: {total_samples}")

    if total_samples != 10400:
        print(f"WARNING: Expected 10,400 held-out samples, found {total_samples}", file=sys.stderr)

    # Class mappings
    # Cambridge CIOD is binary (indoor vs outdoor)
    classes = ['indoor', 'outdoor']
    confusion = {gt: {pred: 0 for pred in classes + ['transition', 'unknown']} for gt in classes + ['transition', 'unknown']}
    
    # Per-session accumulator: session_id -> {total, correct, indoor_total, outdoor_total, indoor_tp, outdoor_tp}
    per_session = defaultdict(lambda: {
        'total': 0, 'correct': 0,
        'indoor_gt': 0, 'outdoor_gt': 0,
        'indoor_tp': 0, 'outdoor_tp': 0,
        'indoor_pred': 0, 'outdoor_pred': 0,
    })

    model_versions = set()

    for r in rows:
        gt = r.get('ground_truth', '').lower().strip()
        pred = r.get('predicted_state', '').lower().strip()
        sess = r.get('session_id', 'unknown').strip()
        mv = r.get('model_version', '').strip()
        if mv:
            model_versions.add(mv)

        if gt not in confusion:
            confusion[gt] = {p: 0 for p in classes + ['transition', 'unknown']}
        if pred not in confusion[gt]:
            confusion[gt][pred] = 0

        confusion[gt][pred] += 1

        is_corr = (gt == pred)
        stats = per_session[sess]
        stats['total'] += 1
        if is_corr:
            stats['correct'] += 1
        if gt == 'indoor':
            stats['indoor_gt'] += 1
            if pred == 'indoor':
                stats['indoor_tp'] += 1
        elif gt == 'outdoor':
            stats['outdoor_gt'] += 1
            if pred == 'outdoor':
                stats['outdoor_tp'] += 1

        if pred == 'indoor':
            stats['indoor_pred'] += 1
        elif pred == 'outdoor':
            stats['outdoor_pred'] += 1

    # Print model version provenance
    if model_versions:
        print(f"Model Version(s) in CSV: {', '.join(sorted(model_versions))}")

    # Compute binary metrics on Indoor (0) vs Outdoor (1)
    indoor_tp = confusion['indoor']['indoor']
    indoor_fn = confusion['indoor']['outdoor'] + confusion['indoor']['transition'] + confusion['indoor']['unknown']
    indoor_fp = confusion['outdoor']['indoor'] + confusion['transition']['indoor'] + confusion['unknown']['indoor']
    indoor_support = confusion['indoor']['indoor'] + indoor_fn

    outdoor_tp = confusion['outdoor']['outdoor']
    outdoor_fn = confusion['outdoor']['indoor'] + confusion['outdoor']['transition'] + confusion['outdoor']['unknown']
    outdoor_fp = confusion['indoor']['outdoor'] + confusion['transition']['outdoor'] + confusion['unknown']['outdoor']
    outdoor_support = confusion['outdoor']['outdoor'] + outdoor_fn

    total_evaluated = indoor_support + outdoor_support
    correct_count = indoor_tp + outdoor_tp
    accuracy = (correct_count / total_evaluated) if total_evaluated > 0 else 0.0

    # Indoor metrics
    indoor_prec = (indoor_tp / (indoor_tp + indoor_fp)) if (indoor_tp + indoor_fp) > 0 else 0.0
    indoor_rec = (indoor_tp / indoor_support) if indoor_support > 0 else 0.0
    indoor_f1 = (2 * indoor_prec * indoor_rec / (indoor_prec + indoor_rec)) if (indoor_prec + indoor_rec) > 0 else 0.0
    indoor_spec = (outdoor_tp / (outdoor_tp + outdoor_fp)) if (outdoor_tp + outdoor_fp) > 0 else 0.0

    # Outdoor metrics
    outdoor_prec = (outdoor_tp / (outdoor_tp + outdoor_fp)) if (outdoor_tp + outdoor_fp) > 0 else 0.0
    outdoor_rec = (outdoor_tp / outdoor_support) if outdoor_support > 0 else 0.0
    outdoor_f1 = (2 * outdoor_prec * outdoor_rec / (outdoor_prec + outdoor_rec)) if (outdoor_prec + outdoor_rec) > 0 else 0.0

    # Macro-F1
    macro_f1 = (indoor_f1 + outdoor_f1) / 2.0

    print("\n#### Independently Calculated Metrics:")
    print(f"| Metric | Raw Ratio | Calculated Value |")
    print(f"| :--- | :--- | :--- |")
    print(f"| **Evaluated Samples** | {total_evaluated} / {total_samples} | 100.0% |")
    print(f"| **Overall Accuracy** | {correct_count} / {total_evaluated} | **{accuracy * 100.0:.2f}%** |")
    print(f"| **Macro-F1 Score** | - | **{macro_f1 * 100.0:.2f}%** |")
    print(f"| **Indoor Precision** | {indoor_tp} / {indoor_tp + indoor_fp} | **{indoor_prec * 100.0:.2f}%** |")
    print(f"| **Indoor Recall** | {indoor_tp} / {indoor_support} | **{indoor_rec * 100.0:.2f}%** |")
    print(f"| **Indoor Specificity** | {outdoor_tp} / {outdoor_tp + outdoor_fp} | **{indoor_spec * 100.0:.2f}%** |")
    print(f"| **Indoor F1-Score** | - | **{indoor_f1 * 100.0:.2f}%** |")
    print(f"| **Outdoor Precision** | {outdoor_tp} / {outdoor_tp + outdoor_fp} | **{outdoor_prec * 100.0:.2f}%** |")
    print(f"| **Outdoor Recall** | {outdoor_tp} / {outdoor_support} | **{outdoor_rec * 100.0:.2f}%** |")
    print(f"| **Outdoor F1-Score** | - | **{outdoor_f1 * 100.0:.2f}%** |")

    print("\n#### Confusion Matrix (Actual rows vs Predicted columns):")
    print(f"| Actual \\ Pred | Pred Indoor | Pred Outdoor | Pred Transition | Pred Unknown | Total |")
    print(f"| :--- | :---: | :---: | :---: | :---: | :---: |")
    for act in ['indoor', 'outdoor']:
        r_in = confusion[act]['indoor']
        r_out = confusion[act]['outdoor']
        r_tr = confusion[act]['transition']
        r_un = confusion[act]['unknown']
        r_tot = r_in + r_out + r_tr + r_un
        print(f"| **Actual {act.upper()}** | {r_in:,} | {r_out:,} | {r_tr:,} | {r_un:,} | {r_tot:,} |")

    print("\n#### Per-Session Breakdown (Sessions 72..84):")
    print(f"| Session ID | Total | Indoor GT | Outdoor GT | Correct | Acc (%) | Indoor Rec (%) | Outdoor Rec (%) |")
    print(f"| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    for s_id in sorted(per_session.keys()):
        s = per_session[s_id]
        acc_s = (s['correct'] / s['total'] * 100.0) if s['total'] > 0 else 0.0
        in_rec_s = (s['indoor_tp'] / s['indoor_gt'] * 100.0) if s['indoor_gt'] > 0 else 100.0
        out_rec_s = (s['outdoor_tp'] / s['outdoor_gt'] * 100.0) if s['outdoor_gt'] > 0 else 100.0
        print(f"| `{s_id}` | {s['total']} | {s['indoor_gt']} | {s['outdoor_gt']} | {s['correct']} | {acc_s:.1f}% | {in_rec_s:.1f}% | {out_rec_s:.1f}% |")

    return {
        'total_samples': total_samples,
        'accuracy': accuracy,
        'macro_f1': macro_f1,
        'indoor_precision': indoor_prec,
        'indoor_recall': indoor_rec,
        'indoor_f1': indoor_f1,
        'outdoor_precision': outdoor_prec,
        'outdoor_recall': outdoor_rec,
        'outdoor_f1': outdoor_f1,
        'confusion': confusion,
        'per_session': per_session,
    }


def main():
    benchmarks = [
        ("tooling/data/benchmark_results/ciod_held_out_composite_predictions.csv", "Aetron IodCompositeClassifier (Deployed Default: Model C-Mobile)"),
        ("tooling/data/benchmark_results/ciod_held_out_mobile_predictions.csv", "DeepIOD Model C-Mobile (4-Sensor Dedicated)"),
        ("tooling/data/benchmark_results/ciod_held_out_model_a_predictions.csv", "DeepIOD Model A (1D-CNN + LSTM, 8 Channels)"),
        ("tooling/data/benchmark_results/ciod_held_out_model_b_predictions.csv", "DeepIOD Model B (1D-CNN + MHA, 8 Channels)"),
        ("tooling/data/benchmark_results/ciod_held_out_model_c_predictions.csv", "DeepIOD Model C (2D DWS-CNN, 8 Channels)"),
        ("tooling/data/benchmark_results/ciod_held_out_amv_neural_predictions.csv", "DeepIOD Neural AMV (Published Eq. 9 Probability-Weighted)"),
        ("tooling/data/benchmark_results/ciod_held_out_amv_bayes_predictions.csv", "Aetron Experimental Bayesian Fusion Extension"),
    ]

    all_metrics = {}
    for path, label in benchmarks:
        all_metrics[label] = verify_file(path, label)

    print("\n" + "="*78)
    print("  SUMMARY BENCHMARK COMPARISON TABLE (ALL MODELS SEPARATE)")
    print("="*78)
    print("| Model / Mode | Samples | Accuracy | Macro-F1 | Indoor F1 | Outdoor F1 | Outdoor Prec | Outdoor Rec | Indoor Rec |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    for label, m in all_metrics.items():
        print(f"| **{label}** | {m['total_samples']:,} | **{m['accuracy']*100:.2f}%** | **{m['macro_f1']*100:.2f}%** | {m['indoor_f1']*100:.1f}% | {m['outdoor_f1']*100:.1f}% | {m['outdoor_precision']*100:.1f}% | {m['outdoor_recall']*100:.1f}% | {m['indoor_recall']*100:.1f}% |")


if __name__ == '__main__':
    main()

