"""Missing-cadence adaptation of Renaudin Eq. 8, DOI 10.3390/s120708507.
Uses existing verified session feature/label exports. No measured cadence is
invented: training cohort mean frequency marginalizes the regression; a
training-cohort mean step length handles missing/out-of-domain height.
Descriptive LOSO on previously explored public datasets, not new holdout.
"""
import csv
import json
import hashlib
from pathlib import Path
import numpy as np

ROOT = Path(__file__).parent / "results"

def evaluate(mode, source):
    path = ROOT / source / "sessions.csv"
    rows = list(csv.DictReader(path.open()))
    for r in rows:
        for field in ("height_m","frequency_hz","reference_step_m","old_step_m"):
            r[field] = float(r[field])
    def fit(train):
        h = np.array([r["height_m"] for r in train])
        f = np.array([r["frequency_hz"] for r in train])
        y = np.array([r["reference_step_m"] for r in train])
        coef = np.linalg.lstsq(np.column_stack([h*f,h,np.ones(len(h))]),y,rcond=None)[0]
        return coef, float(f.mean()), float(y.mean()), float(h.min()), float(h.max())
    def predict(r, params):
        (a,b,c),freq,avg,hmin,hmax=params
        h=r["height_m"]
        pred=h*(a*freq+b)+c
        return float(pred) if hmin<=h<=hmax and pred>0 else avg
    for subject in sorted({r["subject"] for r in rows}):
        train=[r for r in rows if r["subject"]!=subject]
        params=fit(train)
        for r in rows:
            if r["subject"]==subject:
                r["fallback_known_height_m"]=predict(r,params)
                r["fallback_missing_height_m"]=params[2]
    def stats(key):
        y=np.array([r["reference_step_m"] for r in rows])
        diff=np.array([r[key] for r in rows])-y
        return {"mae_cm":float(abs(diff).mean()*100),
                "rmse_cm":float(np.sqrt((diff**2).mean())*100),
                "mape_pct":float((abs(diff)/y).mean()*100)}
    coef,freq,avg,hmin,hmax=fit(rows)
    result={"mode":mode,"source":source,"source_csv_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
            "subjects":len({r["subject"] for r in rows}),"sessions":len(rows),
            "full_fit_coefficients":coef.tolist(),"cohort_mean_frequency_hz":freq,
            "cohort_mean_step_m":avg,"height_range_m":[hmin,hmax],
            "loso":{k:stats(k) for k in ("old_step_m","fallback_known_height_m","fallback_missing_height_m")}}
    return result, rows

def main():
    out=ROOT/"renaudin_fallback_20261118"
    out.mkdir(exist_ok=True)
    manifest={}
    for mode,source in (("walking","renaudin_sle_20261118"),("running","renaudin_running_rbds_20261118")):
        manifest[mode],rows=evaluate(mode,source)
        with (out/f"{mode}_predictions.csv").open("w",newline="") as f:
            writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(json.dumps(manifest,indent=2))
if __name__=="__main__":main()
