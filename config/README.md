# Suspension Benchmark Configuration

## Active configuration files

- `ibxs_li2021_parameters.json`: IBXS physical parameters, horizontal-damper topology, initial state, track settings, solver and output-grid defaults.
- `tixs_li2021_parameters.json`: TIXS physical parameters, vertical-damper topology, initial state, track settings, nominal solver and refinement gate.
- [Railway spectrum explanation](german_railway_spectrum_configuration.md): current shared implementation and preserved historical audit of formulas/realization.
- [Vehicle dynamics explanation](suspension_dynamics_configuration.md): current interfaces/output workflow and historical detailed derivation/parameter audit.

Both simulations load their matching JSON relative to their source-derived project root. Positional arguments override selected JSON fields and are recorded in the run's `effective_config.json`. Defaults preserve the previously implemented physical system and solver settings. JSON `units` records physical units and eight-state ordering; initial-state entries are perturbations about loaded equilibrium. `reference_track_csv` is empty by default and, when configured for IBXS, identifies a project-relative reference CSV with the same time grid.

The spectrum has explicit seed 127 and twister algorithm, with shared numerical realization across both models. There is no time-dependent seed or hidden persistent track cache. The default benchmark duration is 10 s; explicit shorter durations are separately identified smoke runs. TIXS retains its nominal/refined RMS comparison.

## Output and documentation contract

MATLAB exports each run into fresh paired `data/<Suspension>/<run_id>/` and `pics/<Suspension>/<run_id>/` directories. Data include CSV/MAT, effective configuration, runtime metadata, source SHA-256 values and a README. Figures are generated separately with the run-local Matplotlib script, using relative CSV paths, Agg, a 3:2 canvas and in-plot comparison legends. Existing data/figure directories are rejected; figure-only regeneration requires explicit `--overwrite`.

See each suspension README and `../common/README.md` for functions, argument precedence, smoke commands and plotting. Any parameter/equation/solver change must update the corresponding source README and configuration documentation together, and new numerical results must receive a new run identifier.

## Change inventory

Modified: both simulation files and the three existing configuration Markdown files. Added: the two JSON parameter sets, each suspension's README, `common/README.md`, the shared configuration/track/validation/export MATLAB helpers and the plotting source template. Physical derivation TeX/PDF files and unrelated files are unchanged. Verification outcomes and actual generated run files are enumerated in `../docs/output_refactor_verification.md` after checks complete.
