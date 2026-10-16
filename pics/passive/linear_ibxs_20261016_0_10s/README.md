# Passive linear / IBXS comparison figures

Run ID `linear_ibxs_20261016_0_10s`, numerical data generated 2026-10-16;
figure styling revised 2026-10-17 (Asia/Shanghai).
Plotting script: `plot_passive_comparison.py` in this directory.
Configuration: `config/passive_linear_ibxs_20261016.json`.
All paths below are relative to the project root, `main/`.

Source CSVs are under `data/passive/linear_ibxs_20261016_0_10s/`:
`vertical_acceleration_time_histories.csv`, `vertical_acceleration_rms.csv`
and `vertical_acceleration_psd.csv`. The data README gives source runs,
physical assumptions, coordinate mapping, fixed seed 127, solver settings,
column units, RMS definition and exact Welch estimator.

Outputs:

- `vertical_acceleration_time_comparison.png` and `.pdf`: 0-10 s signed
  car-body acceleration, m/s^2, with model names only in the in-plot legend.
- `vertical_acceleration_psd_comparison.png` and `.pdf`: one-sided Welch
  acceleration PSD level, 10 log10(Saa / [1 (m/s^2)^2/Hz]), versus log-scaled
  frequency over 0.5-40 Hz. Major ticks: 0.5, 1, 2, 5, 10, 20, 40 Hz.
- `vertical_acceleration_combined_comparison.png` and `.pdf`: aligned 1x2
  time-history / PSD panels, labels (a)/(b), with no caption below.
  Each plotting rectangle has width:height 1.3:1. The combined figure is
  cropped to its tight artist bounds, with a 0.04 inch safety margin.
  The two axes use explicit positions with exactly equal width, height,
  top and bottom extents; no automatic layout changes their alignment.

The user-provided reference at
`../matlab/Semi_Active_Body_Acceleration_PSD_Comparison.pdf` defines the
requested PSD axis metric and frequency ticks only. Its semi-active curves
are not data for this passive comparison, and its y limits are not forced.

Both standalone exports and each plotting rectangle have width:height
1.3:1, as explicitly requested by the user. PNG is 300 dpi and PDF is
vector, with Times New Roman, inward major/minor ticks, a boxed frame, SI
units and legible legends inside the axes. No numerical smoothing or
arbitrary response/PSD scale factors are applied. Backend: Agg.
Both model curves are solid in every panel: linear 1.2 pt, IBXS 1.6 pt.
All four spines are explicitly 1.0 pt. The linear curve is dark charcoal
`#2B2D42`. Legends contain only `Linear Suspension` and
`IBXS Suspension`, with no RMS values. These settings apply to the combined figure
and the intentionally regenerated standalone figures.

Regenerate figures from existing CSVs without any solver invocation:

```sh
python3 pics/passive/linear_ibxs_20261016_0_10s/plot_passive_comparison.py plot --overwrite
```

For a fresh derivation, run the `smoke`, `prepare`, `plot` sequence described
in the data README. `prepare --overwrite` is an explicit regeneration from
the same source/configuration; changed result-defining settings need a fresh
run ID. Python 3.12.14, NumPy 2.2.6 and Matplotlib 3.10.3 were available for
the first generation; actual versions and source/output SHA-256 values are
recorded in `plot_metadata.json` and the data's `analysis_metadata.json`.
No physical parameter/configuration or MATLAB simulation code was edited.
The new postprocessing configuration and both result READMEs were created
together; the project and configuration index READMEs were updated as well.

Verification includes finite source data, actual artist properties,
panel aspect ratios/alignment and separated PSD corner tick-label bounds.
Source CSVs were finite and their SHA-256 hashes were unchanged by plotting.
The plot command succeeded when invoked from outside the project root.

## Figure-only revision, 2026-10-17

The revision intentionally regenerates the two standalone figures and adds
the combined figure. It reads only the existing three CSVs and never calls
`smoke`, `prepare`, a MATLAB simulation or any ODE solver. Historical numerical
metadata retains its original script/configuration hashes; it is not relabeled
as a new numerical run. Current figure/script/configuration hashes and exact
axes/line/legend checks are recorded separately in `plot_metadata.json`.
The data and original seed/physical/solver settings remain unchanged.

The latest revision supersedes the earlier 3:2 figures and shared caption.
The PSD axes use 9 pt major tick-label padding and inward-facing endpoint
label alignment: `0.5` is left-aligned at the left edge and `40` is
right-aligned at the right edge. A bounding-box check rejects overlap
between the lowest y tick and first x tick.

Export uses tight artist bounds (the same bounds as `bbox_inches='tight'`)
plus 0.04 inch padding. For standalone figures only, the bounds are expanded
minimally to preserve the requested 1.3:1 page/image ratio, quantized to a
13:10 pixel grid. Neither data nor tick values are removed or rescaled.
The bottom caption is removed entirely. Standalone and combined figures
share the same curve styles and legend labels.

Latest revision verified: all three PDFs were rasterized and visually checked.
The `-100` and `0.5` labels are clearly separated, all text is visible and
the caption is absent. Standalone PNG dimensions are 2808x2160 (time)
and 2873x2210 (PSD); both PNG and PDF page ratios are exactly 1.3:1.
Each plotting rectangle is also 1.3:1, including the aligned combined panels.
The original three numerical CSV hashes still match `analysis_metadata.json`.
Finite-data, line-width/style/color, legend and alignment checks passed.
No ODE solver, numerical preparation or smoke simulation was rerun.
