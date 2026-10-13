# IBXS Li2021 Simulation

## Entry point and configuration

`simulate_ibxs_li2021(maxStep, writeOutputs, alphaDeg, rodLength, runId, stopTime)` is the primary function and matches its MATLAB filename. Empty arguments use `../config/ibxs_li2021_parameters.json`. The function resolves the project root from its own location, adds the shared `common/` directory and does not depend on the working directory.

Defaults: 0.002 s MaxStep, 30 degree loaded angle, 1 m rod length; 10 s response duration, 0.002 s output interval, zero eight-state perturbation, ode45 with RelTol 1e-8 and AbsTol 1e-10. Spectrum: seed 127, twister, 500 km/h, 20 s record, 32768 samples, 1-80 Hz, amplitude multiplier 0.62. All physical and numerical defaults are explicit in JSON. Positional overrides take precedence and are recorded in the run's effective configuration. The refactor changes storage, configuration loading and naming; it does not change the physical equations or nominal parameter values.

Use `writeOutputs=false` to compute without creating data/figure directories. An empty run ID allocates a unique timestamp-based identifier. Explicit identifiers must be lowercase snake_case and start with a letter; existing data or figure run directories are rejected. `stopTime` supports Smoke Gate checks and must be positive, within the track record, and a multiple of the output interval. Historical RMS field names containing `10` are retained for compatibility; read `duration_s` to identify the actual interval.

## Smoke Gate and plotting

With the project root selected in MATLAB:

```matlab
addpath('IBXS Suspension');
result = simulate_ibxs_li2021([],true,[],[],'smoke_output_refactor',1);
```

From the project root, using a Python environment with NumPy and Matplotlib:

```sh
python3 pics/IBXS/smoke_output_refactor/plot_time_histories.py
```

The command is an example; use a fresh run ID if the example already exists. Run-local Python scripts also work from any working directory because data paths are anchored to the script. `--overwrite` explicitly regenerates figures only. Full runs use an empty `stopTime` (10 s from JSON) and a fresh run ID. MATLAB exports data and prepares the plot script; Python rendering is a separate downstream step.

## Outputs and provenance

`data/IBXS/<run_id>/` contains `time_histories.csv`, `track_realization.csv`, `simulation_results.mat`, `effective_config.json`, `metadata.json` and `README.md`. `pics/IBXS/<run_id>/` contains `plot_time_histories.py`, its README and, after plotting, PNG/PDF exports and `plot_metadata.json`. Both directories use the same run ID. A failure is reported rather than silently treating partial files as a completed run.

Response CSVs contain time (s), acceleration (m/s^2), heave (m), pitch (rad), velocities (m/s or rad/s), and front/rear track displacement/velocity. TIXS additionally includes conventional-linear acceleration and branch relative displacements. Full-grid track CSV fields are `time_s`, `front_track_m`, `rear_track_m`, `front_track_velocity_m_s`, `rear_track_velocity_m_s`. Run metadata and READMEs provide exact field units, solver settings, seed, generating invocation, runtime, source hashes and relative source/figure paths. MAT files preserve parameters, states and complete track records; TIXS also preserves linear/refined solutions.

Before export, complete output-grid dimensions, finite states/accelerations and physical geometry are checked. TIXS retains the loaded-equilibrium and refined RMS assertions. Shared seeded track generation restores the caller's RNG and avoids stale persistent caches. The same realization is reused for TIXS and its conventional-linear comparison.

Canonical figures use Matplotlib Agg, a 9 by 6 inch (3:2) canvas and explicit units. TIXS comparison legends are inside the axes. Plot styling can be modified in the run-local script without rerunning the solver.

## Model references

See `../docs/IBXS_Lagrange_Derivation.tex`, `../config/suspension_dynamics_configuration.md` and `../config/german_railway_spectrum_configuration.md`. The two configuration documents retain the previous implementation audit under explicitly historical headings and describe the new output/configuration workflow first. Historical results are not moved or relabeled by this change.
