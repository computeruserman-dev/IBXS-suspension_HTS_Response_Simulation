# Agent Instructions for the SRTP Main Workspace

## Scope and Status

These instructions apply to all agents working in this directory and its
subdirectories. Follow them when creating, modifying, moving, or generating
project files.

All sections below are active requirements. These instructions do not require
an immediate reorganization of existing files unrelated to the requested task.

---

## 0. Domain-First Principle

> **Do not alter the physical model merely to hide numerical, implementation,
> or control defects.**

Physical parameters such as mass, stiffness, damping, geometric dimensions,
and linkage relationships represent the mechanical system. Control laws,
numerical solvers, and state-space implementations represent algorithmic or
computational behavior. If a response curve is unstable, divergent, or
otherwise abnormal, first investigate the model implementation, equations,
state definitions, units, solver settings, step-size constraints, initial
conditions, and control logic. Do not insert unexplained scale factors or tune
physical parameters solely to make an output curve look plausible.

Physical parameters may be changed when the change is legitimate and explicit,
including:

- correcting a documented modeling, transcription, or unit error;
- performing an explicitly requested sensitivity, calibration, identification,
  optimization, or design study; or
- implementing a documented change to the physical design or benchmark.

Any such change must be documented, reflected in the relevant configuration,
and assigned a new experiment or run identifier when it changes numerical
results.

---

## 1. Fixed Benchmarks and Verification Gates

### 1.1. Make Benchmark Runs Reconstructable

- A benchmark run must be reconstructable from versioned project files without
  relying on undocumented workspace state or hard-coded overrides.
- Keep benchmark-defining settings explicit in `config/`, including as
  applicable:
  - physical and controller parameters;
  - initial conditions;
  - vehicle speed and simulation duration;
  - track/input-generation settings;
  - solver type and integration method;
  - relative and absolute tolerances;
  - output sampling interval;
  - applicable step-size controls such as `MaxStep`, `InitialStep`, or a
    fixed-step size; and
  - pseudorandom seed or seed set.
- Keep code defaults, configuration values, and documented benchmark settings
  consistent. Any intentional override must be explicit and documented.

### 1.2. Control Stochastic Inputs

- Stochastic inputs must use explicitly specified and recorded pseudorandom
  seeds.
- Within a comparative evaluation, all compared models must use the same
  stochastic realization or the same predefined seed set unless the study
  explicitly investigates stochastic variability.
- Never rely on an implicit, time-dependent, or otherwise unrecorded random
  seed for comparative results.
- Monte Carlo or robustness studies may use multiple seeds, but the seed set
  must be recorded and reused consistently across compared models.

### 1.3. Use Verification Gates

After changing simulation, solver, controller, input-generation, or output code,
use a gated workflow appropriate to the change:

- **Smoke Gate (quick check):** Run a short time span (normally
  `t <= 1.0 s`), a single discrete step, or another lightweight test sufficient
  to verify matrix dimensions, state ordering, finite outputs, file I/O, and
  basic solver behavior.
- **Full Gate (release check):** Run the full simulation and regenerate affected
  numerical outputs only after the Smoke Gate passes when the change can alter
  simulation results.
- Plot-only, documentation-only, or formatting-only changes do not require the
  numerical solver to be rerun. Regenerate only the affected downstream
  artifacts.
- When a stored benchmark or reference result exists, compare key metrics
  against it using documented tolerances rather than relying only on visual
  inspection.
- In the final handoff, report which verification was performed, the solver
  status, relevant runtime information when measured, and any checks that were
  not performed.

---

## 2. Organize Simulation Code by Suspension Type

- Store simulation code and model-specific supporting files in the directory
  assigned to the corresponding suspension type.
- Store IBXS simulation files, including MATLAB `.m` files, only in
  `IBXS Suspension/`.
- Store TIXS simulation files, including MATLAB `.m` files, only in
  `TIXS Suspension/`.
- Apply the same convention to any other suspension type: use its own clearly
  named directory and keep its model-specific files there.
- Do not place model-specific simulation code in the workspace root or in a
  directory assigned to another suspension type.
- Figure-generation scripts follow the storage rules in Section 3.
- Shared utilities genuinely used by multiple suspension models belong in
  `common/` and must document their intended callers and assumptions.

---

## 3. Organize Generated Data and Figures

### 3.1. Data and Figure Directory Structure

- Store generated numerical data, such as `.csv` and `.mat` files, under
  `data/<Suspension>/<run_id>/`.
- Store generated plots and figure exports, such as `.png`, `.pdf`, and `.svg`
  files, under `pics/<Suspension>/<run_id>/`.
- Legacy or tool-specific formats such as MATLAB `.fig` files may be retained
  when explicitly needed, but they do not replace the canonical exported
  figures or the Python plotting workflow below.
- Do not write generated outputs directly into `data/`, `pics/`, the workspace
  root, or a suspension source-code directory.
- Use the same `<run_id>` for corresponding data and figure directories.

Example:

```text
data/IBXS/baseline_run/
pics/IBXS/baseline_run/
```

### 3.2. Decouple Plotting from Simulation

- Generate canonical figures with Python Matplotlib by reading the corresponding
  exported CSV files directly from `data/`.
- Store each plotting `.py` script in the same experiment subdirectory under
  `pics/` as the figures it generates.

Example:

```text
data/IBXS/baseline_run/time_histories.csv
pics/IBXS/baseline_run/plot_time_histories.py
pics/IBXS/baseline_run/time_histories.png
```

- Keep Matplotlib styling inside the plotting scripts so figure styling can be
  changed and regenerated without rerunning the ODE solver.
- When plotting in batch or headless environments, use a non-interactive backend
  such as `matplotlib.use('Agg')` before importing `matplotlib.pyplot`.
- Do not force a non-interactive backend when interactive plotting is explicitly
  required for the task.

### 3.3. Figure Formatting Defaults

- Use a 3:2 width-to-height ratio by default unless the user, publication
  format, or figure composition requires another ratio.
- Prefer legends inside the plotting area when they remain legible and do not
  obscure important data. Otherwise use a clearer placement.
- Include meaningful axis labels and explicit units, normally SI units unless a
  different domain convention is intentionally used.
- Clearly distinguish all compared models, cases, or controllers in the legend.

---

## 4. Preserve Provenance and Keep Documentation Atomic

### 4.1. README Requirements for Generated Outputs

Every directory that directly contains generated data or figures must contain a
`README.md` explaining enough information to reproduce and interpret those
outputs.

Record, as applicable:

- what the outputs represent and which suspension model they concern;
- the mathematical model, benchmark, or experiment purpose;
- the generating script or function and how it was invoked;
- the relevant source data paths using project-relative paths;
- the configuration file or parameter set used;
- software and runtime version information when relevant;
- solver type, tolerances, and applicable step-size settings;
- pseudorandom seed or seed set when stochastic inputs are used;
- generation date;
- code revision or Git commit when available;
- column or field descriptions, including units for numerical data; and
- the relationship between corresponding data and figure directories.

For figure-output READMEs, explicitly identify the plotting script, source CSV
paths under `data/`, and the command needed to regenerate the figures.

### 4.2. Atomic Consistency Rule

- When a change affects the physical model, assumptions, equations, parameter
  definitions, solver behavior, controller behavior, inputs, outputs,
  interpretation, or other documented behavior, update the relevant README in
  the same modification turn.
- When a change affects settings represented in `config/`, update the affected
  configuration files in the same modification turn.
- Pure refactors that do not change behavior, configuration, interfaces, or
  documented meaning do not require artificial README or configuration edits.
- Keep code defaults, configuration values, and documentation consistent.
  Explain intentional experiment-specific overrides.
- Use the existing README filename when one is present, whether `README.md` or
  `readme.md`; do not create a duplicate solely to change casing. For new
  documentation, use `README.md`.
- If documentation needed to explain a changed model or workflow is missing,
  create the appropriate README. If applicable configuration files are missing,
  make the effective settings explicit and create configuration files when the
  implementation uses them.

---

## 5. Validate Numerical Outputs and Avoid Known Engineering Traps

### 5.1. Reject NaN and Inf Before Export

Solvers may return or terminate without making every numerical failure obvious.
Before exporting numerical results, verify that relevant states and outputs are
finite.

Examples:

```matlab
assert(all(isfinite(y(:))), 'Simulation output contains NaN or Inf.');
```

```python
assert np.isfinite(y).all(), "Simulation output contains NaN or Inf."
```

When practical, also check basic physically meaningful bounds or invariants so
that extremely large but technically finite values are not silently accepted as
valid results.

### 5.2. Prevent Dynamic Result Overwrite

- Use a distinct experiment or run identifier whenever settings, inputs,
  physical parameters, model equations, control algorithms, or other
  result-affecting formulations change.
- Do not silently overwrite existing experiment results.
- Intentional regeneration of an existing run must be clearly identified and
  must not relabel old outputs as results of different code or settings.

### 5.3. Avoid Working-Directory Dependence

- Resolve project paths relative to the script location or an explicitly
  designated project root rather than relying on MATLAB's current `pwd` or the
  shell's current working directory.
- Avoid machine-specific absolute paths in committed code and configuration.
- Create required output directories before writing files.
- Check required inputs and provide clear errors when expected files are
  missing.

### 5.4. Preserve Numerical and Physical Separation During Debugging

When abnormal responses occur, distinguish among:

- physical-model errors or incorrect equations;
- unit, sign, coordinate, or state-ordering errors;
- numerical integration or tolerance problems;
- control-law or switching-logic problems; and
- data-processing or plotting errors.

Do not compensate for one category by silently changing another.

---

## 6. Additional File Management Requirements

### 6.1. Use Clear, Consistent Names

- Use descriptive filenames that identify the model and purpose, such as
  `simulate_ibxs_baseline.m` and `ibxs_baseline_parameters.json`.
- Retain existing suspension directory names.
- Prefer lowercase `snake_case` for new script filenames and experiment/run
  identifiers.
- For MATLAB function files, keep the filename consistent with the primary
  function name.
- Avoid ambiguous names such as `final2`, `new_test`, `temp_result`, or similar
  temporary labels for permanent project files.

### 6.2. Separate Shared Utilities, Configuration, Documentation, and Results

- Keep model-specific simulation functions in their suspension directory.
- Store figure-generation scripts as specified in Section 3.
- If multiple models genuinely share a utility, place it in `common/` and
  document its callers, interfaces, and assumptions.
- Keep reusable parameter sets and run settings in `config/`, with names that
  identify their model or experiment. Document units and override precedence.
- Keep derivations, reports, research notes, and their source files in `docs/`.
- Report PDFs belong in `docs/`; individual plot PDF exports belong in `pics/`.
- Keep generated results separate from source code, configuration, and input
  datasets, except for plotting scripts stored alongside their figures as
  required by Section 3.
- Document where non-generated input datasets are stored and how they enter the
  simulation workflow.

### 6.3. Keep Changes Focused and Verifiable

- Preserve unrelated user files and edits. Do not rename, move, or delete files
  beyond the scope of the requested task without a clear need.
- Keep temporary debugging files out of permanent result directories.
- After changing simulation or output code, perform the relevant verification
  described in Section 1 when feasible.
- In the final handoff, identify changed files, generated outputs,
  documentation/configuration updates, and the verification performed.

---

## 7. Do Not

- **Do not** alter physical parameters or insert artificial scale factors solely
  to make unstable or incorrect simulation results look plausible.
- **Do not** use unseeded stochastic excitation in comparative evaluations.
- **Do not** write generated data or figure files directly into `data/`,
  `pics/`, the workspace root, or suspension source directories.
- **Do not** commit machine-specific absolute paths such as `C:\...` or
  `/Users/...`.
- **Do not** delete, rename, or move unrelated files outside the immediate scope
  of the task.
- **Do not** silently overwrite existing experiment results.
- **Do not** relabel old results as outputs of new code, parameters, or model
  formulations.
- **Do not** rerun expensive full simulations for plot-only or documentation-only
  changes when saved numerical outputs are still valid.
- **Do not** claim simulation speedup, stability improvement, vibration
  reduction, or other performance gains without citing measured evidence such
  as runtime, solver statistics, RMS/peak response, frequency-domain metrics,
  or another appropriate quantitative measure.
