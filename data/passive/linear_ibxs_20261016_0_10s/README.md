# Passive linear / IBXS vertical acceleration comparison

Derived on 2026-10-16 (Asia/Shanghai) from the existing completed 0-10 s
benchmark, not a new simulation. Run ID: `linear_ibxs_20261016_0_10s`.
The numerical derivation and figures are configured in
`config/passive_linear_ibxs_20261016.json` relative to the project root.

## Inputs, physical system and coordinates

Source run: `run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d`.
Read `data/IBXS/<source_run>/time_histories.csv` for IBXS acceleration and
`data/TIXS/<source_run>/time_histories.csv` for the **conventional linear**
acceleration column. The nonlinear TIXS response is not part of this comparison.
Each source directory's `effective_config.json` and `metadata.json` identify
the original solver, physical parameters, source hashes and completion status.

Physical parameters are unchanged: body mass 8500 kg, pitch inertia
192500 kg m^2, each bogie mass 4032 kg, half support spacing 3.8 m;
primary stiffness 3542400 N/m and damping 2419.2 N s/m per branch.
The conventional linear secondary branch has k=730000 N/m and c=50000 N s/m,
with no inerter. IBXS uses the same numerical *horizontal* spring/damper
coefficients, horizontal inertance 500 kg, rod length 1 m and loaded angle
30 deg. Its loaded vertical tangent stiffness/damping/inertance are
187743.333333 N/m, 16666.666667 N s/m and 166.666667 kg per branch.
This compares existing designs, not isolated inerter effects or matched
vertical stiffness/damping.

Use downward-positive signed track displacement and body acceleration, as in
the IBXS derivation. The linear data were exported inside an upward-positive
TIXS run. Their use here is valid because a conventional linear system with
zero initial perturbations has L(-track)=-L(track): simultaneous inversion
of track and response preserves its numerical input/output relation. Both
stored linear track AND response are interpreted downward-positive here;
acceleration is not flipped alone. Pitch coordinates differ by a sign, and
the script verifies the corresponding incidence-matrix equivalence. This
argument applies to the linear baseline, not the nonlinear TIXS solution.

Both sources use seed **127**, algorithm **twister**, speed **500 km/h**,
the same 20 s / 32768-sample synthesized track, 1-80 Hz synthesis band and
rear delay 0.05472 s. The pre-existing track amplitude convention 0.62 is
preserved, not adjusted. Before export the script checks identical times,
front/rear displacement AND velocity, vehicle/track/solver settings, zero
initial states, finite source columns and recorded source-code hashes.
All numerical source/configuration hashes must match. The old plotting
template differs because of a historical legend/provenance-only revision
documented in `docs/output_refactor_verification.md`; both hashes are recorded
and that nonnumerical file is explicitly excluded from numerical-source gates.

Original solver: MATLAB R2025b Update 5, ode45, RelTol=1e-8, AbsTol=1e-10,
MaxStep=0.002 s, output dt=0.002 s; 5001 samples from 0 through 10 s.
No warm-up or transient removal, filtering, response scaling, interpolation
or numerical differentiation is applied.

## Three numerical deliverables

- `vertical_acceleration_time_histories.csv`: `time_s` (s),
  `linear_vertical_acceleration_m_s2`, `ibxs_vertical_acceleration_m_s2`
  (m/s^2), and `front_track_m`, `rear_track_m` (m).
- `vertical_acceleration_rms.csv`: one row per model, including interval,
  sample count, unweighted time-domain RMS (m/s^2), peak absolute acceleration
  (m/s^2), and RMS reduction relative to linear (%).
  RMS = sqrt(trapezoid(a^2,t)/10), **without** mean removal.
- `vertical_acceleration_psd.csv`: frequency (Hz), each one-sided PSD
  ((m/s^2)^2/Hz), and each PSD level (dB re 1 (m/s^2)^2/Hz).
  The CSV retains 0-250 Hz including DC. The plot displays only 0.5-40 Hz.

PSD uses symmetric Hann windows of 2048 points, 1024-point overlap, per-segment
mean removal, NFFT=8192, arithmetic averaging, and fs*sum(window^2) density
normalization with interior positive-frequency bins doubled. At fs=500 Hz
there are 3 complete windows (starting 0, 2.048 and 4.096 s), 905 unused
tail samples, 4.096 s window duration and 0.06103515625 Hz FFT spacing.
Zero padding refines the plotted frequency grid, not the underlying spectral
resolution (fs/2048=0.244140625 Hz). RMS includes all 5001 samples.
Welch variance and full-record RMS need not coincide because windowing,
segment detrending and tail handling differ. No artificial dB floor is used;
nonpositive PSD or any NaN/Inf causes rejection before export.

## Reproduction and verification

From the project root, with Python, NumPy and Matplotlib available:

```sh
python3 pics/passive/linear_ibxs_20261016_0_10s/plot_passive_comparison.py smoke
python3 pics/passive/linear_ibxs_20261016_0_10s/plot_passive_comparison.py prepare
python3 pics/passive/linear_ibxs_20261016_0_10s/plot_passive_comparison.py plot
```

`smoke` checks the first <=1 s and temporary CSV I/O plus a synthetic
sinusoid normalization check. `prepare` validates full source data, checks
RMS against original metadata and verifies Welch Parseval normalization,
then exports CSV/provenance. Existing results require explicit `--overwrite`.
`plot` reads only these three derived CSVs; it never invokes an ODE solver.
All paths resolve from the script's project root, independently of cwd.
`analysis_metadata.json` records actual versions, hashes, metrics, finite
checks, verification outcomes and postprocessing runtime. Original solver
runtime is retained as historical provenance, not a newly measured speedup.

Figures and generating script are in
`pics/passive/linear_ibxs_20261016_0_10s/`; see that directory's README.

## Executed results and checks

| Model | 0-10 s RMS (m/s^2) | Peak absolute acceleration (m/s^2) |
|---|---:|---:|
| Conventional linear | 0.5285359191751396 | 1.34861482476861 |
| Passive IBXS | 0.24750111835760183 | 0.945434309492274 |

For these existing designs and this seed, IBXS RMS is 53.17231821370536%
lower. This is not a claim isolating the effect of inertance; transformed
vertical stiffness and damping also differ.

Executed smoke: 501 samples over 0-1 s, finite values, CSV round trip,
and a 16 Hz unit-amplitude sinusoid with integrated PSD
0.5000001208357114 versus theoretical 0.5: PASS.
Full CSV postprocessing: PASS, no ODE run. All five time/track displacement/
velocity comparisons have maximum difference exactly zero. Recomputed RMS
matches original MATLAB metadata within 1e-12 m/s^2. Welch Parseval relative
errors are 2.099e-16 (linear) and 0 (IBXS). All exported numeric columns were
reopened and checked finite; CSV hashes remained unchanged by plotting.
Both PNGs and rasterized PDF pages were visually inspected: no clipping or
legend overlap; PNG 2700x1800 and PDF 648x432 points confirm the 3:2 ratio.
Plotting was invoked from outside the project root to check path independence.

Figure-only revision on 2026-10-17: the corresponding `pics/` script and
the configuration's `figure` section now produce an aligned 1x2 combined
figure and restyled standalone figures. The latest style uses 1.3:1 panels,
tight exports, full suspension names in legends and no bottom caption. No numerical
CSV, physical/solver setting, RMS or PSD estimate is regenerated or changed.
Original `analysis_metadata.json` and `smoke_verification.json` retain their
historical hashes; current styling provenance is in `pics/.../plot_metadata.json`.
