# SRTP: Track-Excited Response Comparison of X-Structure Inerter Secondary Suspensions

## 1. Project Overview

This project investigates the vertical vibration response of high-temperature superconducting maglev vehicles, comparing X-structure inerter secondary suspensions with a conventional linear secondary suspension under the same stochastic track-spectrum excitation. The current implementation solves nonlinear four-degree-of-freedom vehicle dynamics in MATLAB and uses separate Python Matplotlib scripts to plot exported CSV data, with IBXS and TIXS models and a conventional linear baseline integrated within the TIXS entry point.

### Implementation Principles and Current Scope

The vehicle degrees of freedom are car-body heave, car-body pitch, front-bogie heave, and rear-bogie heave. The eight-dimensional state follows the order below, with displacements measured as perturbations about the loaded static equilibrium:

$$
\boldsymbol q=[z_c,\theta_c,z_f,z_r]^{\mathsf T},\qquad
\boldsymbol y=[\boldsymbol q^{\mathsf T},\dot{\boldsymbol q}^{\mathsf T}]^{\mathsf T}.
$$

The primary suspension uses linear stiffness and damping, while two secondary branches connect the car body to the front and rear bogies. Rigid-rod X geometry transforms transverse spring and inerter actions into vertical generalized forces, producing displacement-dependent equivalent inertance and velocity-squared terms. At each right-hand-side evaluation, the code assembles the mass matrix and solves for acceleration:

$$
\boldsymbol M(\boldsymbol q)
=\boldsymbol M_0+\boldsymbol B\mathrm{diag}(\mu_f,\mu_r)\boldsymbol B^{\mathsf T},\qquad
\boldsymbol M_0=\mathrm{diag}(m_c,I_c,m_1,m_1).
$$

Here, $\boldsymbol B$ maps vehicle coordinates to the relative displacements of the two secondary branches, and $\mu_f,\mu_r$ are geometry-dependent equivalent inertances. Spring preload accounts for half the car-body weight supported by each branch. The model retains the full X-structure rod geometry and uses a small-pitch approximation for the car-body attachment points.

| Model | Current Implementation | Comparison Conditions |
|---|---|---|
| IBXS | Transverse spring, damper, and inerter in parallel; integrates the nonlinear vehicle response | Default loaded angle: $30^\circ$; its entry point does not integrate a conventional linear baseline |
| TIXS | Transverse spring and inerter with a vertical damper; integrates the nonlinear response and performs a refined-step check | Default loaded angle: $45^\circ$; the same entry point also integrates the conventional linear suspension |
| Conventional linear suspension | Uses constant mass, damping, and stiffness matrices within the TIXS entry point | Shares the TIXS run's track realization, initial conditions, output grid, and nominal solver settings |

The IBXS derivation takes downward vertical motion as positive, whereas the TIXS derivation takes upward motion as positive; their pitch conventions also differ. Align coordinate definitions before comparing signed displacement, pitch, or acceleration histories. The default models differ in damper orientation and loaded angle, so their results do not represent a controlled study in which only the inerter changes. The models currently omit rod mass, hinge friction, end-stop impacts, car-body roll, bogie pitch, and nonlinear superconducting levitation hysteresis.

The shared function `common/make_li2021_track.m` generates the excitation. It converts the German vertical track-irregularity spatial spectrum into a temporal spectrum using vehicle speed, synthesizes displacement through fixed-seed random phases and a Hermitian-symmetric IFFT, and obtains velocity by frequency-domain differentiation. A frequency-domain phase shift introduces the rear-support delay:

$$
S_v(\Omega)=\frac{A_v\Omega_C^2}{(\Omega^2+\Omega_R^2)(\Omega^2+\Omega_C^2)},\qquad
\Omega=\frac{2\pi f}{v},\qquad
S_t(f)=\frac{2\pi}{v}S_v\!\left(\frac{2\pi f}{v}\right),\qquad
\tau=\frac{2d}{v}.
$$

Identical track settings, support spacing, and seeds allow IBXS, TIXS, and the linear baseline to share the same track realization. The front/rear track CSV files in the existing matching runs are identical.

Current performance evaluation focuses on car-body vertical acceleration histories and RMS. TIXS also reports the percentage change in RMS relative to the linear suspension. Additional comparison metrics will be introduced later; the current code does not provide a unified evaluation entry point for multiple performance metrics.

$$
a_{\mathrm{RMS}}=\sqrt{\frac{1}{T}\int_0^T a_c(t)^2\,\mathrm dt},\qquad
\Delta_{\mathrm{RMS}}=100\left(\frac{a_{\mathrm{RMS,TIXS}}}{a_{\mathrm{RMS,linear}}}-1\right)\%.
$$

RMS is calculated by trapezoidal integration over the output grid. Geometric endpoint margins, static-equilibrium residuals, and refined-step RMS differences check model feasibility and numerical validity rather than serving as additional performance metrics. Detailed equations are available in the [IBXS derivation](docs/IBXS_Lagrange_Derivation.tex), [TIXS derivation](docs/TIXS_Lagrange_Derivation.tex), and [dynamics configuration notes](config/suspension_dynamics_configuration.md).

## 2. Prerequisites & Installation

The following versions come from existing execution records and identify the verified environment. The repository does not specify minimum compatible versions.

| Component | Recorded Version or Requirement | Purpose |
|---|---|---|
| MATLAB | R2025b Update 5, `25.2.0.3177638` | Configuration loading, track synthesis, `ode45` integration, and CSV/MAT export |
| Python | 3.12.14 | Independent plotting runtime |
| NumPy | `2.2.6` | CSV loading, array operations, and finite-value checks |
| Matplotlib | `3.10.3` | PNG/PDF rendering with the Agg backend |
| SHA-256 facility | Java MessageDigest with the JVM; `shasum` in Unix no-JVM mode | Source-file hashing during export |

The MATLAB code calls functions including `ode45`, `jsondecode`, `jsonencode`, `griddedInterpolant`, `interp1`, and `struct2array`. The repository does not provide a complete MATLAB toolbox dependency list; confirm that these functions are available in the execution environment. Existing successful simulations used no-JVM mode. Environment-specific issues and verification conditions are documented in the [existing verification record](docs/output_refactor_verification.md).

From the project root, `main/`, create the plotting environment and install the pinned dependencies using the existing requirements file:

```sh
python3 -m venv .venv_plot && .venv_plot/bin/python -m pip install -r common/plot_requirements.txt
```

This command uses Unix/macOS virtual-environment paths. MATLAB must be installed and licensed separately. Python reads exported data and renders figures; MATLAB performs the dynamics integration.

## 3. Quickstart

### Minimal Working Example: Run the Smoke Gate First

In MATLAB, set the current directory to the project root, `main/`, and call the two existing entry points over $0$ to $1\,\mathrm{s}$:

```matlab
addpath('IBXS Suspension');
addpath('TIXS Suspension');
runId = 'readme_smoke_20261013';

ibxs = simulate_ibxs_li2021([],true,[],[],runId,1);
tixs = simulate_tixs_li2021([],true,runId,1);
```

`runId` must be unused; change it before repeating the example. Different suspension models may share an identifier for paired runs, but an existing data or figure directory for the same suspension causes the exporter to reject overwriting.

On success, each `data/<Suspension>/readme_smoke_20261013/` directory contains `time_histories.csv`, `track_realization.csv`, `simulation_results.mat`, `effective_config.json`, `metadata.json`, and `README.md`. Each response grid contains 501 rows, and each full track record contains 32768 rows. MATLAB prints the output location and acceleration RMS, and prepares a plotting script and README in the corresponding `pics/` directory.

The TIXS entry point performs nominal nonlinear integration, conventional linear baseline integration, and refined-step nonlinear integration, checking static equilibrium, geometry, and RMS convergence. Both entry points check the eight-state dimensions, complete time grids, and finite values. The exporter rejects non-finite responses and numerical metrics.

Then run the separate plotting commands from a terminal at the project root:

```sh
.venv_plot/bin/python pics/IBXS/readme_smoke_20261013/plot_time_histories.py
.venv_plot/bin/python pics/TIXS/readme_smoke_20261013/plot_time_histories.py
```

IBXS produces `body_acceleration.png` and `body_acceleration.pdf`. TIXS also produces `linear_tixs_acceleration_comparison.png` and its PDF counterpart. Both produce `plot_metadata.json`, recording the plotting environment, source CSV hash, and output paths. The default canvas is $9\times6$ inches, comparison legends are inside the axes, and axis labels include explicit units.

### Run the Full Gate After the Smoke Gate Passes

Use a fresh identifier and leave the end time empty to use the JSON default duration of $10\,\mathrm{s}$:

```matlab
runId = 'readme_full_20261013';
ibxs = simulate_ibxs_li2021([],true,[],[],runId,[]);
tixs = simulate_tixs_li2021([],true,runId,[]);
```

Each full-run response CSV contains 5001 rows. For plotting, use `pics/IBXS/readme_full_20261013/plot_time_histories.py` and `pics/TIXS/readme_full_20261013/plot_time_histories.py`. These commands are reproduction instructions; numerical integration was not performed while writing or translating this README.

### Reuse Existing CSV Data for Figure-Only Changes

After editing a run's `plot_time_histories.py`, explicitly regenerate existing figures with:

```sh
.venv_plot/bin/python pics/TIXS/smoke_output_refactor_20261013/plot_time_histories.py --overwrite
```

`--overwrite` regenerates figures and plotting metadata without modifying CSV/MAT data or invoking an ODE solver. Simulation and plotting functions resolve project paths from their own locations. The relative commands above are intended to be executed from the project root.

## 4. Repository Architecture

The project separates simulation code, shared utilities, configurations, numerical results, figures, and derivations into the following directories:

```text
main/                    # Project root containing the suspension simulation and comparison workflow.
|-- IBXS Suspension/     # MATLAB simulation code and model-specific documentation for IBXS.
|-- TIXS Suspension/     # MATLAB simulation code and documentation for TIXS and its linear baseline.
|-- common/              # Shared configuration, track synthesis, validation, export, and plotting utilities.
|-- config/              # Physical parameters, track settings, solver settings, and configuration documentation.
|-- data/                # Numerical simulation results and run provenance, organized by suspension and run ID.
|-- pics/                # Figures and their Python plotting scripts, organized by suspension and run ID.
`-- docs/                # Mathematical derivations, rendered reports, and verification records.
```

Corresponding numerical and figure outputs use matching run identifiers under `data/<Suspension>/<run_id>/` and `pics/<Suspension>/<run_id>/`. This separation allows figures to be regenerated from saved numerical data without rerunning the simulation.

## 5. Configuration

The configuration entry points are the [IBXS JSON](config/ibxs_li2021_parameters.json) and [TIXS JSON](config/tixs_li2021_parameters.json). Dotted names in the tables denote JSON nesting. Defaults are shared by both models unless stated otherwise. Nonempty positional arguments override JSON values, and each run records its effective settings in `effective_config.json`.

### Vehicle and Secondary-Suspension Parameters

| Parameter | Physical Meaning / Function | Default Value | Type / Unit |
|---|---|---|---|
| `vehicle.mc` | Car-body mass | 8500 | Number / $\mathrm{kg}$ |
| `vehicle.Ic` | Car-body pitch moment of inertia | 192500 | Number / $\mathrm{kg\,m^2}$ |
| `vehicle.m1` | Mass of each bogie-Dewar assembly | 4032 | Number / $\mathrm{kg}$ |
| `vehicle.d` | Distance from the car-body center to each support | 3.8 | Number / $\mathrm{m}$ |
| `vehicle.k1` | Primary stiffness per branch | 3542400 | Number / $\mathrm{N/m}$ |
| `vehicle.c1` | Primary damping coefficient per branch | 2419.2 | Number / $\mathrm{N\,s/m}$ |
| `vehicle.g` | Gravitational acceleration used for static preload | 9.81 | Number / $\mathrm{m/s^2}$ |
| `secondary.k` | Transverse spring stiffness per X unit; also used as vertical secondary stiffness in the TIXS linear baseline | 730000 | Number / $\mathrm{N/m}$ |
| `secondary.c` | Secondary damper coefficient per branch; also used in the TIXS linear baseline | 50000 | Number / $\mathrm{N\,s/m}$ |
| `secondary.b` | Transverse inerter inertance per branch, distinct from rod mass | 500 | Number / $\mathrm{kg}$ |
| `secondary.l` | Length of an individual X-structure rod | 1 | Number / $\mathrm{m}$ |
| `secondary.alpha_deg` | Rod angle at loaded static equilibrium | IBXS: 30; TIXS: 45 | Number / $\mathrm{degree}$ |
| `secondary.damper_orientation` | Secondary damper orientation, checked against the model | IBXS: `horizontal`; TIXS: `vertical` | String / dimensionless |

Transverse element coefficients differ from the equivalent vertical coefficients at loaded equilibrium. The code separately calculates tangent stiffness and equivalent inertance, and checks that spring natural length and tangent stiffness are positive. Changing physical parameters or adding scale factors to conceal abnormal responses violates the [workspace rules](AGENTS.md). Justified physical corrections or explicitly defined study changes require updated configurations and documentation and a new run identifier.

### Track-Excitation Parameters

| Parameter | Physical Meaning / Function | Default Value | Type / Unit |
|---|---|---|---|
| `track.speed_km_h` | Vehicle speed for converting the spatial spectrum to a temporal spectrum | 500 | Number / $\mathrm{km/h}$; converted to $\mathrm{m/s}$ in code |
| `track.Av` | German vertical track-spectrum amplitude coefficient | $4.032\times10^{-7}$ | Number / $\mathrm{m}$, inferred from the implemented formula with radians dimensionless |
| `track.OmegaR` | Low-wavenumber characteristic parameter | 0.0206 | Number / $\mathrm{rad/m}$ |
| `track.OmegaC` | High-wavenumber characteristic parameter | 0.8246 | Number / $\mathrm{rad/m}$ |
| `track.seed` | Seed for random-phase generation | 127 | Nonnegative integer / dimensionless |
| `track.rng_algorithm` | Pseudorandom algorithm; currently only this setting is accepted | `twister` | String / dimensionless |
| `track.record_seconds` | Periodic synthesized track-record length | 20 | Number / $\mathrm{s}$ |
| `track.sample_count` | Number of IFFT samples | 32768 | Even integer / samples |
| `track.f_min_hz` | Lower synthesis-frequency limit | 1 | Number / $\mathrm{Hz}$ |
| `track.f_max_hz` | Upper synthesis-frequency limit | 80 | Number / $\mathrm{Hz}$ |
| `track.amplitude_scale` | Existing benchmark multiplier applied to frequency-domain amplitudes | 0.62 | Number / dimensionless |

`amplitude_scale` multiplies frequency-domain amplitudes, giving a corresponding PSD multiplier of $0.62^2$. It is an existing explicit benchmark setting and was not changed for this documentation update. The track sampling interval is $20/32768\,\mathrm{s}$, the last record time is $(32768-1)\times20/32768\,\mathrm{s}$, the frequency spacing is $1/20\,\mathrm{Hz}$, and the default rear-input delay is $0.05472\,\mathrm{s}$. The generator preserves and restores the caller's random-number state. Comparative experiments must record and reuse consistent track settings and seeds.

### Solver, Verification, and Output Parameters

| Parameter | Physical Meaning / Function | Default Value | Type / Unit |
|---|---|---|---|
| `solver.method` | Dynamics integration method; currently the only method accepted by the loader | `ode45` | String |
| `solver.rel_tol` | Nominal integration relative tolerance | $10^{-8}$ | Number / dimensionless |
| `solver.abs_tol` | Nominal integration absolute tolerance | $10^{-10}$ | Number / corresponding state units |
| `solver.max_step_s` | Maximum internal step for nominal integration | 0.002 | Number / $\mathrm{s}$ |
| `solver.output_step_s` | Uniform response-output interval, distinct from adaptive internal steps | 0.002 | Number / $\mathrm{s}$ |
| `solver.duration_s` | Response integration duration | 10 | Number / $\mathrm{s}$ |
| `solver.initial_state` | Eight-dimensional initial perturbation about static equilibrium | `[0,0,0,0,0,0,0,0]` | Numeric array / ordered units: $\mathrm{m,rad,m,m,m/s,rad/s,m/s,m/s}$ |
| `refinement.enabled` | Refined-step verification flag; IBXS does not execute this check, while TIXS requires it to be enabled | IBXS: `false`; TIXS: `true` | Boolean |
| `refinement.rel_tol` | TIXS refined integration relative tolerance | $10^{-9}$ | Number / dimensionless |
| `refinement.abs_tol` | TIXS refined integration absolute tolerance | $10^{-11}$ | Number / corresponding state units |
| `refinement.max_step_s` | Maximum step for TIXS refined integration | 0.001 | Number / $\mathrm{s}$ |
| `refinement.rms_difference_limit_percent` | Strict upper limit on the relative difference between nominal and refined TIXS acceleration RMS | 0.5 | Number / $\%$ |
| `reference_track_csv` | Optional IBXS reference CSV containing time and front/rear track columns on the response grid | `""` | Project-relative path string; currently not read by the TIXS entry point |

The refinement check uses the refined integration RMS as its denominator and requires the difference to be strictly below the configured threshold. The end time must be an integer multiple of the output interval and must not exceed the final time of the full track record.

Entry-point signatures and positional overrides are:

```matlab
simulate_ibxs_li2021(maxStep,writeOutputs,alphaDeg,rodLength,runId,stopTime)
simulate_tixs_li2021(alphaDeg,writeOutputs,runId,stopTime)
```

| Parameter | Physical Meaning / Function | Default Value | Type / Unit |
|---|---|---|---|
| `maxStep` | Overrides the IBXS nominal maximum step | JSON `solver.max_step_s` | Positive number / $\mathrm{s}$ |
| `writeOutputs` | Exports data and prepares figure directories; simulation still runs when false | `true` | Boolean |
| `alphaDeg` | Overrides the model's loaded rod angle | JSON `secondary.alpha_deg` | Number / $\mathrm{degree}$, strictly between $0$ and $90$ |
| `rodLength` | Overrides the IBXS rod length | JSON `secondary.l` | Positive number / $\mathrm{m}$ |
| `runId` | Export identifier; existing directories for the same suspension are rejected | `''`, generating a unique identifier automatically | String matching `^[a-z][a-z0-9_]{0,95}$` |
| `stopTime` | Overrides the response duration, including short Smoke Gate runs | JSON `solver.duration_s` | Positive number / $\mathrm{s}$ |

Result fields retain historical names such as `rms_0_10_s_m_s2` and `rms10_m_s2`. The actual evaluation interval is determined by `duration_s`; short runs must not be treated as full benchmark results. Run-specific configurations, units, commands, and source hashes provide numerical provenance. Reuse existing data for figure-only or documentation-only changes. Changes to models, inputs, or solver settings that affect numerical results require a new run identifier and corresponding README/configuration updates.
