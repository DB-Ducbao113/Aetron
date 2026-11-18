"""Running adaptation of Renaudin Eq.8 (10.3390/s120708507).
Fukuchi et al. (10.7717/peerj.3298), RBDS Figshare v5, original 28 runners.
Force-derived cadence; belt-speed / cadence reference, not independent foot
placement labels. Whole-trial steady-state means; not smartphone replay.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfiltfilt

def contact_events(force):
    filt = sosfiltfilt(butter(4, 10, fs=300, output='sos'), force)
    active = filt >= 20
    starts = np.flatnonzero(~active[:-1] & active[1:]) + 1
    ends = np.flatnonzero(active[:-1] & ~active[1:]) + 1
    valid = []
    for start in starts:
        later = ends[ends > start]
        if len(later) and later[0] - start >= 30:
            valid.append(start)
    return np.array(valid), len(starts) - len(valid)

def design(rows):
    return np.array([[r['height_m']*r['frequency_hz'],r['height_m'],1] for r in rows])

def fit(rows):
    return np.linalg.lstsq(design(rows), [r['reference_step_m'] for r in rows], rcond=None)[0]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    meta=json.loads((a.data/'metadata.json').read_text())
    assert meta['doi']=='10.6084/m9.figshare.4543435.v5'
    files={f['name']:f for f in meta['files'] if f['name'].endswith('forces.txt')}
    info=a.data/'RBDSinfo_2017.txt'
    info_md5=hashlib.md5(info.read_bytes()).hexdigest()
    assert any(f['id']==7841131 and f['computed_md5']==info_md5 for f in meta['files'])
    people={}
    with info.open(encoding='utf-8-sig') as stream:
        for r in csv.DictReader(stream,delimiter='\t'):
            if not r['Subject']: continue
            i=int(r['Subject'])
            if not 1<=i<=28: continue
            value=(float(r['Height'])/100,r['Gender'])
            assert i not in people or people[i]==value
            people[i]=value
    assert len(people)==28
    rows=[]
    for i,(height,gender) in sorted(people.items()):
        assert gender in ('M','F')
        for speed_code in (25,35,45):
            name=f'RBDS{i:03d}runT{speed_code}forces.txt'
            path=a.data/name
            md5=hashlib.md5(path.read_bytes()).hexdigest()
            assert md5==files[name]['computed_md5']
            raw=np.loadtxt(path,skiprows=1)
            assert raw.shape==(9000,8) and np.isfinite(raw).all()
            assert np.array_equal(raw[:,0],np.arange(1,len(raw)+1))
            events,rejected=contact_events(raw[:,2])
            dt=np.diff(events)/300
            assert len(dt)>1 and np.all((dt>=.2)&(dt<=.6))
            frequency=1/np.mean(dt)
            speed=speed_code/10
            ref=speed/frequency
            old=float(np.clip(height*(.62 if gender=='F' else .67),.5,1.5))
            rows.append(dict(subject=i,filename=name,height_m=height,gender=gender,speed_ms=speed,frequency_hz=float(frequency),reference_step_m=float(ref),old_step_m=old,intervals=len(dt),rejected_crossings=rejected,md5=md5))
    folds=[]
    for i in people:
        train=[r for r in rows if r['subject']!=i]
        test=[r for r in rows if r['subject']==i]
        coef=fit(train)
        for r,pred in zip(test,design(test)@coef): r['predicted_step_m']=float(pred)
        folds.append(dict(subject=i,coefficients=coef.tolist()))
    def metrics(rr,key):
        y=np.array([r['reference_step_m'] for r in rr])
        e=np.array([r[key] for r in rr])-y
        return dict(n=len(rr),mae_cm=float(np.mean(abs(e))*100),rmse_cm=float(np.sqrt(np.mean(e*e))*100),session_mape_pct=float(np.mean(abs(e)/y)*100))
    keys=['old_step_m','predicted_step_m']
    summary={k:metrics(rows,k) for k in keys}
    speeds={str(v):{k:metrics([r for r in rows if r['speed_ms']==v],k) for k in keys} for v in (2.5,3.5,4.5)}
    report=dict(source_doi=meta['doi'],paper_doi='10.7717/peerj.3298',model_doi='10.3390/s120708507',metadata_file_id=7841131,metadata_md5=info_md5,subjects=28,sessions=len(rows),reference_intervals=sum(r['intervals'] for r in rows),rejected_crossings=sum(r['rejected_crossings'] for r in rows),summary=summary,speed_groups=speeds,folds=folds,full_fit_coefficients=fit(rows).tolist(),height_range_m=[min(r['height_m'] for r in rows),max(r['height_m'] for r in rows)],cadence_range_spm=[min(r['frequency_hz']*60 for r in rows),max(r['frequency_hz']*60 for r in rows)],scope='LOSO on steady treadmill trial means; reference length is belt speed / force-derived cadence, so shares cadence measurement; no smartphone or absolute foot-placement validation.')
    a.out.mkdir(parents=True,exist_ok=True)
    (a.out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    with (a.out/'sessions.csv').open('w',newline='') as stream:
        wr=csv.DictWriter(stream,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
    print(json.dumps({k:v for k,v in report.items() if k!='folds'},indent=2))
if __name__=='__main__':main()
