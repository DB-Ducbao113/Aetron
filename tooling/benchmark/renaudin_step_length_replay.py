"""Renaudin et al. (2012), DOI 10.3390/s120708507, Eq. 8.
Independent SLEDataset2 walking adaptation: session-average targets, no
per-cycle alignment assumed. Causal 256-sample frequency windows, 128 hop,
strongest demeaned tri-axis acceleration spectrum below the paper's 3 Hz
step-detection cutoff, Eq. 11's 1.4 Hz stride/step discriminator.
Coefficients fitted only on training subjects in each LOSO fold.
OS cadence is a different runtime measurement, not validated by this replay.
"""
import argparse, hashlib, csv, json, subprocess
from pathlib import Path
import numpy as np

def spectral_cadence(acc, fs):
    n=256
    w=np.lib.stride_tricks.sliding_window_view(acc,n,axis=0)[::128]
    w=w-w.mean(axis=2,keepdims=True)
    power=(np.abs(np.fft.rfft(w,axis=2))**2).sum(axis=1)
    bins=np.fft.rfftfreq(n,1/fs)
    band=(bins>0)&(bins<=3)
    freq=bins[band][np.argmax(power[:,band],axis=1)]
    return np.where(freq<1.4,2*freq,freq)

def design(rows):
    return np.array([[r['height_m']*r['frequency_hz'],r['height_m'],1] for r in rows])

def fit(rows):
    return np.linalg.lstsq(design(rows),[r['reference_step_m'] for r in rows],rcond=None)[0]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    rev=subprocess.check_output(['git','-C',str(a.data.parent),'rev-parse','HEAD'],text=True).strip()
    assert rev=='6b8a8d475e6984b4d2744ff31fe4ad254cf76896'
    rows=[]
    for path in sorted(a.data.glob('person*/person*.json')):
        d=json.loads(path.read_text())
        if 'stride_lengths' not in d: continue
        assert d['sampling_frequency']==100
        acc=np.array([d['linear_acceleration'][axis] for axis in 'xyz']).T
        assert np.isfinite(acc).all()
        f=spectral_cadence(acc,100)
        # Each window represents equal time; weight average estimated length
        # by predicted number of steps, not by reference event count.
        freq=float(np.average(f,weights=f))
        y=np.array(d['stride_lengths'],float)/2
        assert len(y)>0 and np.isfinite(y).all() and (y>0).all()
        h=float(d['height'])
        old=float(np.clip(h*(.4 if d['gender']=='female' else .43),.5,1.5))
        rows.append(dict(subject=path.parent.name,file=path.name,placement=d['smartphone_position'],speed=d['walking_speed'],height_m=h,frequency_hz=freq,reference_step_m=float(y.mean()),labels=len(y),old_step_m=old,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    subjects=sorted({r['subject'] for r in rows}); folds=[]
    for subject in subjects:
        train=[r for r in rows if r['subject']!=subject]
        test=[r for r in rows if r['subject']==subject]
        coef=fit(train)
        pred=design(test)@coef
        for r,v in zip(test,pred): r['predicted_step_m']=float(v)
        folds.append(dict(subject=subject,coefficients=coef.tolist(),test_sessions=len(test)))
    def metrics(rr,key):
        y=np.array([r['reference_step_m'] for r in rr]); pred=np.array([r[key] for r in rr]); e=pred-y
        return dict(n=len(rr),mae_cm=float(np.mean(abs(e))*100),rmse_cm=float(np.sqrt(np.mean(e**2))*100),session_mape_pct=float(np.mean(abs(e)/y)*100))
    summary={k:metrics(rows,k) for k in ['old_step_m','predicted_step_m']}
    subgroups={}
    # Explicit subgroup metrics, not used to select or tune the fit.
    for field in ['speed','placement','subject']:
        subgroups[field]={g:{k:metrics([r for r in rows if r[field]==g],k) for k in ['old_step_m','predicted_step_m']} for g in sorted({r[field] for r in rows})}
    out=dict(doi='10.3390/s120708507',source_commit=rev,subjects=len(subjects),sessions=len(rows),reference_cycle_labels=sum(r['labels'] for r in rows),summary=summary,subgroups=subgroups,folds=folds,full_fit_coefficients=fit(rows).tolist(),observed_height_range_m=[min(r['height_m'] for r in rows),max(r['height_m'] for r in rows)],observed_session_frequency_range_hz=[min(r['frequency_hz'] for r in rows),max(r['frequency_hz'] for r in rows)],scope='session mean step length only; walking; independently estimated spectral cadence, not OS pedometer; fit separately in each held-out subject fold')
    a.out.mkdir(parents=True,exist_ok=True)
    (a.out/'manifest.json').write_text(json.dumps(out,indent=2)+'\n')
    with (a.out/'sessions.csv').open('w',newline='') as f:
        wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
    print(json.dumps({k:v for k,v in out.items() if k not in ['folds','subgroups']},indent=2))
    print(json.dumps(subgroups['speed'],indent=2))
if __name__=='__main__': main()
