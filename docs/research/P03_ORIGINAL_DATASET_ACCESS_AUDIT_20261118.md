# P03 — Original paper data access and reproduction audit (2026-11-18)

**Status: original experiment NOT REPRODUCED — publicly accessible supplement is insufficient.** This is an evidence audit, not a change to the P03 runtime or its release decision.

## 1. Source and verified download

Czerwiński, Wydra, Rachwał, Jachuła and Zubrzycki, *A Multi-Stage Framework for GPS Trajectory Reconstruction Using Consumer-Grade Wearable Devices*, Applied Sciences 16(18), 8972, published 10 September 2026. [DOI](https://doi.org/10.3390/app16188972); [publisher article](https://www.mdpi.com/2076-3417/16/18/8972).

Publisher's [supplement landing URL](https://www.mdpi.com/article/10.3390/app16188972/s1) returned HTTP 403 on the local host; the direct publisher asset was publicly retrievable without authentication when requesting it with a normal browser user agent:

<https://mdpi-res.com/d_attachment/applsci/applsci-16-08972/article_deploy/applsci-16-08972-s001.zip>

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `applsci-16-08972-s001.zip` | 332194 | `778ae23792166c70a3c76d83195ac851bd64045850b5883972b06516e9ae1a8c` |
| sole ZIP member `applsci-4487496-supplementary.pdf` | 369581 | `5090eadfa1825c0217964009464cf668ea0c2f1c3de0da8b7775fb3d0c5bf8be` |

The downloaded archive was inspected in memory using Python `zipfile`, `hashlib`, and `pypdf.PdfReader`. The PDF has two pages, zero embedded files and no reported annotations or external links. Page 1 contains Table S1 (pooled threshold sensitivity), Figure S1, Table S2 (leave-one-reference-out residual summaries); page 2 contains Figure S2. No GPX, CSV, 574-checkpoint reference array, per-observation timestamp/coordinate arrays, participant/device correspondence, or executable source code was found. No source file was added to the repository.

Reproducible verification (requires installed `pypdf`, standard-library networking, and access to the publisher asset):

```python
import hashlib, io, urllib.request, zipfile
from pypdf import PdfReader

url = 'https://mdpi-res.com/d_attachment/applsci/applsci-16-08972/article_deploy/applsci-16-08972-s001.zip'
request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(request, timeout=30) as response:
    payload = response.read()
print(len(payload), hashlib.sha256(payload).hexdigest())
with zipfile.ZipFile(io.BytesIO(payload)) as archive:
    for member in archive.infolist():
        data = archive.read(member)
        print(member.filename, len(data), hashlib.sha256(data).hexdigest())
        if member.filename.lower().endswith('.pdf'):
            pdf = PdfReader(io.BytesIO(data))
            print('pages', len(pdf.pages), 'embedded files', list(pdf.attachments))
            for i, page in enumerate(pdf.pages, start=1):
                print(i, page.extract_text(), 'annotations', page.get('/Annots'))
```

The paper's Data Availability Statement points to the article and supplement rather than a separately identified archive of raw recordings. Searches for the exact title/DOI and data/code repositories did not locate the original six GPX files. This establishes a missing publicly verified artifact, **not** proof that the data are private, proprietary, or unobtainable from the authors. Earlier statements in `P03_FINAL_SCIENTIFIC_VALIDATION.md` §1.3 about RINEX/NMEA and institutional ownership are unsubstantiated: the paper describes GPX recordings, and its data-availability statement indicates that further inquiries may be addressed to the corresponding author.

## 2. Required source inputs and actual method

Paper §§2.1–2.4, 2.9 and 3 report six real running GPX recordings over one known 5.726 km route. Three high-fidelity Garmin recordings construct a distance-normalized 574-checkpoint reference proxy. Three low-fidelity smartphone recordings comprise 699 timestamped observations (572/46/81); the UTC window 2025-05-25 09:02:24–09:43:55 leaves 224 observations (184/8/32), of which 158 (118/8/32) are retained. The reference is consumer-grade and not survey RTK truth. The reconstruction relies on route checkpoint association, time/sequence feasibility, a 30 m spatial threshold, reference elevation and pace models, including reference-derived acceleration/terrain information. A reproducible study requires the six original GPX files or equivalent per-observation and per-checkpoint arrays sufficient to reconstruct the same reference, common-window mask, and retained assignments. The published aggregates do not identify the coordinates or times needed by the Dart replay.

The paper also describes a distinct position-only CV Kalman / offline RTS comparison (§2.9.1), with state `[x,y,vx,vy]`, varying timestamp intervals, fixed measurement standard deviation 15 m, acceleration process standard deviation 1.5 m/s², and reset after >60 s. Those parameter values are published, but its original evaluation still requires the original GPX and the reference. It is not Aetron P03 and does not supply a substitute dataset.

Published paper results (author-reported only): raw nearest-route RMSE 30.72 m on 224 observations; proposed retained-assignment residual RMSE 14.84 m on 158 observations. These are different populations and refer to the adopted route proxy. Section 2.9.4 also reports a common 158-observation sensitivity comparison. Do not treat coverage or nearest-checkpoint distance as independent synchronized position error. The publicly downloaded supplement's Table S1 at 30 m instead records 441 retained points (64.76%) and 14.67 m RMSE; the article's §3.9.3 states 70.54% and 14.84 m at 30 m. The supplement does not provide row-level data or a cohort identifier resolving the difference; do not silently combine those populations. Table S2 reports pooled reference-proxy disagreement 9.09 m horizontal RMSE and 8.66 m elevation RMSE, not geodetic truth error.

**Replay decision:** no Dart run on author data, because that data was not supplied by the verified public ZIP. Digitizing figures, generating pseudo-GPX, or treating a Garmin profile as independently labeled absolute ground truth would misrepresent the experiment. Status remains NOT REPRODUCED.

## 3. Foundational method attribution and implementation scope

Fritsch and Carlson (1980), [Monotone Piecewise Cubic Interpolation](https://doi.org/10.1137/0717021), SIAM J. Numer. Anal. 17(2), 238–246, §2 equation (2), gives the scalar Hermite representation; §3 characterizes interval monotonicity; §4 discusses derivative initialization and a sufficient first-quadrant radius-3 region `S2`. This supports the Hermite basis and normalized tangent limiter (nonnegative alpha/beta with `alpha²+beta² <= 9`). The 1980 examples are numerical interpolation examples, not this GNSS data. Fritsch and Butland (1984), [DOI 10.1137/0905021](https://doi.org/10.1137/0905021), is a separate local monotone interpolation construction; do not imply that the Aetron implementation reproduces that harmonic-mean tangent procedure.

`lib/features/workout/domain/services/trajectory_reconstruction/kinematic_trajectory_reconstruction_engine.dart` (inspected current `ekf` worktree, lines 221–343) constructs Hermite curves for each gap separately using measured/derived endpoint speeds and headings projected into local east/north, clamps tangent ratios to nonnegative, and scales them when their squared sum is >9. The curve representation and radius limiter are grounded in Fritsch–Carlson. However, the original multi-knot algorithm initializes shared knot derivatives and adjusts them consistently across intervals. Our pairwise tangent construction, activity limits, gap limits (2–15 s), coordinate projection, linear altitude and fallback chord bearing are engineering adaptations. Separate per-gap limiting may yield different derivatives for a shared knot on either side; global C1 continuity and physically bounded displacement speed do not follow merely from the scalar monotonicity condition. The kinematic speed value is clamped, but the curve derivative itself is not necessarily bounded by that display value. It is defensible to call this an **Fritsch–Carlson-limited, pairwise Hermite interpolation adaptation**, not exact full PCHIP reproduction and not Czerwiński's route-constrained reconstruction.

## 4. TU Wien scope and previously available replay

Independent dataset: Dürnberger, *Smartphone GNSS and Sensor Data with RTK Reference Trajectory*, [DOI 10.48436/y6gxm-6mg51](https://doi.org/10.48436/y6gxm-6mg51). It is not the Czerwiński 2025 Polish running experiment. Prior Aetron `tooling/benchmark/replay_tu_wien_p03_closure.py` is inspectable in git object `5af6f6a` (`git show 5af6f6a:tooling/benchmark/replay_tu_wien_p03_closure.py`); it is absent from the current worktree. It reads Pixel 9a / Pixel 7 Pro exports for routes 31–35, simulates 4 s gaps by taking every fourth phone fix, reconstructs using Python linear/PCHIP copies, and scores a last-prior output within 2 s against Leica reference. Despite its introductory docstring, it does not run the Dart runtime or an EKF method. It does not restrict scoring to the truly withheld interior epochs or preserve original reference quality. Earlier audit also found Pixel 7 Pro logger timestamps ~2.53–2.59 s later than NMEA GNSS UTC and all legacy reference exports mislabeled `RTK_FIXED` despite phase/code/Navigated source roles. Absolute timing/quality claims in the old TU Wien replay therefore need reconciliation; no old number is claimed as a fresh result here. Any corrected TU Wien experiment remains a separate independent outdoor walking, artificially downsampled reconstruction validation, not reproduction of Czerwiński et al.

No shared runtime changes, benchmark reruns, commits, pushes, or deployments were made. Original-author data reproduction remains blocked by the absent executable data inputs; the absence of a retrieved source dataset cannot be repaired by a synthetic or independent dataset.
