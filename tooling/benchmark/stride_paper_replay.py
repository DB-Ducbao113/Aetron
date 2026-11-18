"""Replay published SLE equations on Wang et al.'s public annotated ASLE cycles.

Vezočnik et al. (2021), doi:10.3390/s21103527, eq.15.
Vezočnik & Juric (2022), doi:10.3390/s22239452, eq.2.
Cross-dataset equation replay, not reproduction of optical derivation or
end-to-end smartphone detection. Raw acceleration magnitude (includes gravity)
instead of source linear acceleration. Reference events supply segmentation.
"""
import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path
import subprocess
import numpy as np

MODELS = ('pca2021', 'cca2022', 'training_mean')
EXPECTED_COMMIT = 'c96f67c79a81a8f2098eee051dd41c0c1ba1d102'


def extract_cycles(a):
    """Only complete intervals between two observed reference counter events.
    Reference distance is the cumulative-distance increment at the closing event.
    Cross-check with per-stride length at that event (not the previous group).
    Returns (closing time ms, stride frequency Hz, acceleration range, stride m).
    """
    if a.ndim != 2 or a.shape[1] != 7 or not np.isfinite(a).all():
        raise ValueError('expected finite ax ay az timestamp_ms length counter cumulative')
    if np.any(np.diff(a[:,3]) <= 0):
        raise ValueError('nonmonotonic timestamps')
    counter = a[:,5]
    if np.any(counter != np.floor(counter)) or np.any(np.diff(counter) < 0):
        raise ValueError('invalid stride counter')
    events = np.flatnonzero(np.diff(counter) != 0) + 1
    rejected = Counter()
    rows = []
    for s,e in zip(events[:-1],events[1:]):
        if counter[e] - counter[s] != 1:
            rejected['counter_gap'] += 1
            continue
        d = a[e,6] - a[s,6]
        if not np.isclose(d,a[e,4],atol=1e-6,rtol=1e-7):
            rejected['reference_mismatch'] += 1
            continue
        duration = (a[e,3]-a[s,3])/1000
        if e-s < 2:
            rejected['insufficient_samples'] += 1
            continue
        amp = float(np.ptp(np.linalg.norm(a[s:e,:3],axis=1)))
        if d < 0 or amp <= 0:
            rejected['invalid_reference_or_signal'] += 1
            continue
        rows.append((float(a[e,3]),1/duration,amp,float(d)))
    return rows,rejected


def design(a,model):
    if model == 'training_mean':
        return np.ones((len(a),1))
    amp = a[:,2] ** .1
    if model == 'pca2021':
        return amp[:,None]
    if model == 'cca2022':
        return np.column_stack((a[:,1]*amp,amp))
    raise ValueError(model)


def fit(a,model):
    x=design(a,model)
    if np.linalg.matrix_rank(x) != x.shape[1]:
        raise ValueError('rank deficient calibration')
    return np.linalg.lstsq(x,a[:,3],rcond=None)[0]


def predict(a,model,coef):
    return design(a,model) @ coef


def metrics(y,p):
    err=p-y
    return {'n':len(y),'mae_cm':float(np.mean(abs(err))*100),
            'rmse_cm':float(np.sqrt(np.mean(err**2))*100),
            'bias_cm':float(np.mean(err)*100),
            'reference_m':float(y.sum()),'estimated_m':float(p.sum()),
            'abs_distance_error_pct':float(abs(err.sum())/y.sum()*100) if y.sum()>0 else None}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    rev=subprocess.check_output(['git','-C',str(args.data.parent),'rev-parse','HEAD'],text=True).strip()
    if rev != EXPECTED_COMMIT:
        raise ValueError(f'unexpected source revision {rev}')
    files=sorted(args.data.glob('*.txt'))
    if len(files)!=30:
        raise ValueError(f'expected 30 source files, got {len(files)}')
    groups={}
    inventory=[]
    for f in files:
        a=np.loadtxt(f,usecols=(1,2,3,10,11,12,13))
        rows,rejected=extract_cycles(a)
        data=np.array(rows,dtype=float).reshape(-1,4)
        inventory.append({'file':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),
                          'samples':len(a),'valid_cycles':len(rows),'rejected':dict(rejected),
                          'duration_s':float((a[-1,3]-a[0,3])/1000)})
        if len(data):
            groups[f.name]=(data,float(a[0,3]))
    args.out.mkdir(parents=True,exist_ok=True)
    all_results={}
    with (args.out/'predictions.csv').open('w',newline='') as stream:
        writer=csv.writer(stream)
        writer.writerow(['protocol','file','close_ms','stride_hz','acceleration_range_ms2','reference_stride_m',*MODELS])
        for protocol in ('file_holdout','first_5min'):
            folds=[]
            pooled={model:[] for model in MODELS}
            targets=[]
            for name,(test,first_t) in groups.items():
                if protocol=='file_holdout':
                    train=np.concatenate([v[0] for k,v in groups.items() if k!=name])
                else:
                    if test[-1,0]-first_t < 600000:
                        continue
                    cutoff=first_t+300000
                    train=test[test[:,0]<=cutoff]
                    # Exclude cycle straddling calibration cutoff.
                    test=test[test[:,0]-1000/test[:,1]>=cutoff]
                if not len(test) or not len(train):
                    continue
                y=test[:,3]
                targets.extend(y)
                results={}
                preds=[]
                for model in MODELS:
                    coef=fit(train,model)
                    p=predict(test,model,coef)
                    results[model]={'coefficients':coef.tolist(),**metrics(y,p)}
                    pooled[model].extend(p)
                    preds.append(p)
                folds.append({'file':name,'train_n':len(train),'test_n':len(test),'models':results})
                writer.writerows([protocol,name,*row,*ps] for row,ps in zip(test,zip(*preds)))
            summary={}
            for model in MODELS:
                summary[model]=metrics(np.array(targets),np.array(pooled[model]))
                errors=[f['models'][model]['abs_distance_error_pct'] for f in folds
                        if f['models'][model]['abs_distance_error_pct'] is not None]
                summary[model]['mean_file_abs_distance_error_pct']=float(np.mean(errors))
            all_results[protocol]={'folds':folds,'summary':summary}
    report={'source_commit':rev,'source_doi':'10.3390/s19040840','source_files':inventory,
            'models':{'pca2021':'10.3390/s21103527 Eq.15',
                      'cca2022':'10.3390/s22239452 Eq.2',
                      'training_mean':'engineering comparator'},
            'scope':'annotated cycle equation replay, raw acceleration including gravity, mixed activities, file holdout not subject holdout; no runtime segmentation or production claim',
            'results':all_results}
    (args.out/'manifest.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'files':len(files),'eligible_files':len(groups),'cycles':sum(len(v[0]) for v in groups.values()),
                      'rejections':dict(sum((Counter(r['rejected']) for r in inventory),Counter())),
                      'results':{k:{'files':len(v['folds']),'summary':v['summary']} for k,v in all_results.items()}},indent=2))

if __name__=='__main__':
    main()
