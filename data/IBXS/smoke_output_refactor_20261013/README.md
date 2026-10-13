# IBXS run smoke_output_refactor_20261013

Generated UTC: 2026-10-13T07:42:00.878Z. Runtime: MATLAB 25.2.0.3177638 (R2025b) Update 5 (MACA64). Solver status: completed.

## Reproduction

From the project root, add `IBXS Suspension` to the MATLAB path and call:

```matlab
simulate_ibxs_li2021(0.002,true,30,1,'smoke_output_refactor_20261013',1);
```

The run ID is reserved: use a new ID when replaying, and restore `effective_config.json` settings rather than silently using changed defaults. Configuration source: `config/ibxs_li2021_parameters.json`.

Seed: 127 (`twister`); speed: 500 km/h; solver: ode45; RelTol: 1e-08; AbsTol: 1e-10; MaxStep: 0.002 s; output interval: 0.002 s; duration: 1 s.

The exact effective physical, track, initial-state and refinement settings are recorded in `effective_config.json` and `metadata.json`. Source SHA-256 values are in `metadata.json`; no Git revision is asserted. The loaded-equilibrium nonlinear model is described in `../../../config/suspension_dynamics_configuration.md`.

## Files and units

- `time_histories.csv`: response-grid values; column units are listed below.
- `track_realization.csv`: full periodic track record; time_s (s), front_track_m/rear_track_m (m), front_track_velocity_m_s/rear_track_velocity_m_s (m/s).
- `simulation_results.mat`: states, track, parameters, effective config, metadata and metrics; TIXS also saves linear/refined states and accelerations.
- `effective_config.json`: complete settings after explicit positional overrides.
- `metadata.json`: generation command, runtime, source hashes, units and metrics.

| Column | Unit |
|---|---|
| `time_s` | s |
| `body_vertical_acceleration_m_s2` | m/s^2 |
| `body_heave_m` | m |
| `body_pitch_rad` | rad |
| `front_bogie_heave_m` | m |
| `rear_bogie_heave_m` | m |
| `front_track_m` | m |
| `rear_track_m` | m |
| `front_track_velocity_m_s` | m/s |
| `rear_track_velocity_m_s` | m/s |
| `body_heave_velocity_m_s` | m/s |
| `body_pitch_velocity_rad_s` | rad/s |
| `front_bogie_velocity_m_s` | m/s |
| `rear_bogie_velocity_m_s` | m/s |

Paired figure directory: `../../../pics/IBXS/smoke_output_refactor_20261013/`. The plot script reads this CSV directly.

