# Naming and Output Refactor: Verification Record

Date: 2026-10-13. Scope: the Main workspace IBXS/TIXS simulation interfaces, configuration loading, export/provenance and downstream plotting. No physical equation, default parameter, default solver tolerance or nominal spectrum coefficient was changed. No prior result was deleted, moved or relabeled.

## Verification gates

- Smoke Gate passed for both models over 0-1 s, with 501 output samples, complete eight-state dimensions, finite states/accelerations and valid output I/O. TIXS equilibrium, geometry and refinement assertions passed.
- Full Gate passed for both models over 0-10 s, with 5001 output samples and the original nominal/refinement settings. The same shared realization was reused for the TIXS conventional-linear comparison. Front/rear full-track CSVs are exactly equal between matching IBXS/TIXS runs.
- Independent CSV trapezoidal RMS agrees with MATLAB metadata within 1e-12 m/s^2. All numerical CSV fields are finite and have documented units.
- Existing run IDs are rejected before writing. Non-finite export input is rejected before reserving a directory. `writeOutputs=false` was checked to create no run directory. Track generation restores the caller's RNG state.
- Both solvers and all plotting scripts were invoked from outside the project root, checking that source-derived/script-derived paths are independent of the working directory.
- Both acceleration-function bodies were compared with the pre-refactor sources after removing comments/whitespace and were unchanged. Primary MATLAB names match filenames; the old missing TIXS renderer and MATLAB plotting branches are absent.
- MATLAB Code Analyzer reported no substantive findings. Two messages identify unnecessary historical `NASGU` suppression comments in shared cleanup-handle declarations; these do not affect execution.
- Matplotlib rendered all PNG/PDF outputs; PNGs are 1800 by 1200 pixels (3:2). A comparison figure was visually inspected. Legend placement was changed from fixed upper-right to Matplotlib's best location inside the axes after the initial smoke render obscured a peak. Numerical files were hashed before/after this figure-only regeneration and remained unchanged.
- Figure regeneration without `--overwrite` was rejected, leaving all existing figure files unchanged. Intentional smoke figure regeneration used `--overwrite`; full-run figures were initially rendered with the revised style.
- Documentation is English-only. The four physical-derivation TeX/PDF files retain their original hashes.

## Runtime and limits

Successful solver runtime: MATLAB 25.2.0.3177638 (R2025b) Update 5, maca64, batch mode with `-nojvm`. A JVM-enabled version/license probe printed valid information and then crashed in the installed license-logging component (process exit 137). The successful no-JVM smoke/full runs exited normally; no source parameter or solver tolerance was changed to address that runtime issue. In no-JVM Unix mode, source SHA-256 recording uses `shasum`; normal JVM mode uses Java MessageDigest.

Plotting runtime: Python 3.12.14, NumPy 2.2.6, Matplotlib 3.10.3, installed into a temporary verification environment. `common/plot_requirements.txt` pins the two direct plotting dependencies; setup commands are in `common/README.md`. Runtime measurements below cover track generation, integration and response processing, excluding export and Python plotting; they are observations, not speedup claims.

No stored pre-refactor benchmark existed under Main/data for a numeric before/after metric comparison. Preservation checks therefore used unchanged acceleration implementations, unchanged JSON default values and the matching track algorithms. No claim of improved vibration performance or performance attributable to this refactor is made.

The source plotting-template hash in numerical metadata records the template at export time. Its later legend/provenance-only revision is intentionally separate from numeric data provenance. Actual run-local script and CSV hashes are recorded in `plot_metadata.json`. Numeric metadata was not rewritten to relabel the original export.

## Measured run metrics

Compatibility RMS field names containing `10` are retained; `duration_s` and the effective solver duration identify each actual interval.

| Model | Run ID | Duration (s) | Body RMS (m/s^2) | Solver/processing elapsed (s) | TIXS refinement difference (%) |
|---|---|---:|---:|---:|---:|
| IBXS | `run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d` | 10 | 0.247501118358 | 8.887668 | N/A |
| IBXS | `smoke_output_refactor_20261013` | 1 | 0.234071954343 | 1.766140 | N/A |
| TIXS | `run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d` | 10 | 0.480034024615 | 363.666809 | 1.8974124968e-05 |
| TIXS | `smoke_output_refactor_20261013` | 1 | 0.541635927275 | 33.383533 | 3.61823456012e-05 |

## Modified and added source/documentation files

The two simulation files and three existing configuration Markdown files were modified. The remaining files below were added. `AGENTS.md` and unrelated files were not edited.

- `IBXS Suspension/simulate_ibxs_li2021.m`
- `TIXS Suspension/simulate_tixs_li2021.m`
- `IBXS Suspension/README.md`
- `TIXS Suspension/README.md`
- `config/README.md`
- `config/german_railway_spectrum_configuration.md`
- `config/suspension_dynamics_configuration.md`
- `config/ibxs_li2021_parameters.json`
- `config/tixs_li2021_parameters.json`
- `common/README.md`
- `common/load_suspension_config.m`
- `common/make_li2021_track.m`
- `common/validate_solution.m`
- `common/export_suspension_run.m`
- `common/plot_time_histories.py.in`
- `common/plot_requirements.txt`
- `docs/output_refactor_verification.md`

## Generated files

Each run's data and figure README provides invocation, source paths, units, seed, solver settings and provenance. The following inventory lists every output created by the verification runs:

- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/README.md`
- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/effective_config.json`
- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/metadata.json`
- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/simulation_results.mat`
- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/time_histories.csv`
- `data/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/track_realization.csv`
- `pics/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/README.md`
- `pics/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/body_acceleration.pdf`
- `pics/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/body_acceleration.png`
- `pics/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/plot_metadata.json`
- `pics/IBXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/plot_time_histories.py`
- `data/IBXS/smoke_output_refactor_20261013/README.md`
- `data/IBXS/smoke_output_refactor_20261013/effective_config.json`
- `data/IBXS/smoke_output_refactor_20261013/metadata.json`
- `data/IBXS/smoke_output_refactor_20261013/simulation_results.mat`
- `data/IBXS/smoke_output_refactor_20261013/time_histories.csv`
- `data/IBXS/smoke_output_refactor_20261013/track_realization.csv`
- `pics/IBXS/smoke_output_refactor_20261013/README.md`
- `pics/IBXS/smoke_output_refactor_20261013/body_acceleration.pdf`
- `pics/IBXS/smoke_output_refactor_20261013/body_acceleration.png`
- `pics/IBXS/smoke_output_refactor_20261013/plot_metadata.json`
- `pics/IBXS/smoke_output_refactor_20261013/plot_time_histories.py`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/README.md`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/effective_config.json`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/metadata.json`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/simulation_results.mat`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/time_histories.csv`
- `data/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/track_realization.csv`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/README.md`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/body_acceleration.pdf`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/body_acceleration.png`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/linear_tixs_acceleration_comparison.pdf`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/linear_tixs_acceleration_comparison.png`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/plot_metadata.json`
- `pics/TIXS/run_20261013_074447_802_tp26102901_481a_40c7_8ad2_34801127611d/plot_time_histories.py`
- `data/TIXS/smoke_output_refactor_20261013/README.md`
- `data/TIXS/smoke_output_refactor_20261013/effective_config.json`
- `data/TIXS/smoke_output_refactor_20261013/metadata.json`
- `data/TIXS/smoke_output_refactor_20261013/simulation_results.mat`
- `data/TIXS/smoke_output_refactor_20261013/time_histories.csv`
- `data/TIXS/smoke_output_refactor_20261013/track_realization.csv`
- `pics/TIXS/smoke_output_refactor_20261013/README.md`
- `pics/TIXS/smoke_output_refactor_20261013/body_acceleration.pdf`
- `pics/TIXS/smoke_output_refactor_20261013/body_acceleration.png`
- `pics/TIXS/smoke_output_refactor_20261013/linear_tixs_acceleration_comparison.pdf`
- `pics/TIXS/smoke_output_refactor_20261013/linear_tixs_acceleration_comparison.png`
- `pics/TIXS/smoke_output_refactor_20261013/plot_metadata.json`
- `pics/TIXS/smoke_output_refactor_20261013/plot_time_histories.py`

## Handoff checklist

- [x] Model scripts remain in their suspension directories; CSV/MAT are in `data/<Suspension>/<run_id>/`; figures and executable plotting scripts are co-located in `pics/<Suspension>/<run_id>/`.
- [x] Required directories are created before writing, existing run IDs are rejected, and project/script-relative paths are used.
- [x] Both suspension READMEs, shared README, JSON configurations and existing configuration Markdown documents were updated together. Every result directory contains its own README.
- [x] Changed source/documents and generated outputs are explicitly enumerated above.
