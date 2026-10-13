# Shared Suspension Utilities

Both `simulate_ibxs_li2021` and `simulate_tixs_li2021` use these helpers:

- `load_suspension_config.m`: reads the matching versioned JSON benchmark relative to the project root; callers apply and record positional overrides.
- `make_li2021_track.m`: identical random-phase Hermitian IFFT realization for both vehicles, with explicit seed/algorithm, full-record front/rear displacement and spectral velocity, restored caller RNG and no workspace cache.
- `validate_solution.m`: rejects incomplete grids, incorrect eight-state dimensions and NaN/Inf.
- `export_suspension_run.m`: reserves paired run directories, rejects overwrite, exports CSV/MAT and effective configuration, creates provenance READMEs and records source hashes/runtime.
- `plot_time_histories.py.in`: a non-executable source template copied as `plot_time_histories.py` into each `pics/<Suspension>/<run_id>/` directory. All actual plotting `.py` files are co-located with their figures. It uses Agg, script-relative CSV paths, a 3:2 canvas, explicit units and an in-axes comparison legend.
- `plot_requirements.txt`: pinned NumPy and Matplotlib versions for the independently invoked plotting step.

Model-specific equations remain in their suspension folders. Helpers assume the documented eight-state order and SI units. Source hashes are recorded for the model, configuration, all shared MATLAB helpers and plotting template. Plotting is independent of MATLAB export and records its own Python/NumPy/Matplotlib versions. Existing run directories are never reused by the exporter; intentional figure-only regeneration requires `--overwrite`.

For a local plotting environment, run these commands from the project root:

```sh
python3 -m venv .venv_plot
.venv_plot/bin/python -m pip install -r common/plot_requirements.txt
.venv_plot/bin/python pics/<Suspension>/<run_id>/plot_time_histories.py
```

Verification used a temporary environment with those pinned direct dependencies. MATLAB verification used `-nojvm` because the installed R2025b runtime crashed in its license-logging component during a JVM-enabled probe. Unix no-JVM runs record SHA-256 with `shasum`; JVM-enabled runs use Java MessageDigest. Metadata records whether the JVM was enabled. No physical or solver setting is changed by that runtime choice.
