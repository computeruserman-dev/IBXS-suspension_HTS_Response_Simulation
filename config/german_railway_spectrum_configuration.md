# German Railway Vertical-Irregularity Spectrum: Configuration and Realization

## Current configuration and realization after the output refactor

The current functions load `ibxs_li2021_parameters.json` and `tixs_li2021_parameters.json` in this directory. The `track` objects retain every numerical spectrum choice tabulated below. `../common/make_li2021_track.m` now implements the shared realization, preserving the IFFT normalization, random draw order, phase delay and spectral derivative. It returns both IBXS and TIXS field aliases, regenerates from the explicit configuration on every call, and restores the caller's RNG after synthesis. The previous IBXS persistent cache has been removed.

Each exported run records the complete effective spectrum settings in `data/<Suspension>/<run_id>/effective_config.json` and `metadata.json`. `track_realization.csv` preserves the full periodic grid, both displacements and both velocities. `time_histories.csv` also includes those inputs on the response grid. Model-specific README files document the current calls and plotting step. The optional IBXS reference CSV is now an explicit project-relative `reference_track_csv` configuration value (empty by default); an unavailable comparison is represented by an empty numeric value and a status string rather than NaN.

The following sections preserve the **pre-refactor audit** for traceability. Their original code-line locations, hard-coded configuration descriptions, cache behavior, filename/helper issues and original hashes refer to the previous implementation, not the current exporter. The physical spectrum formulas, coefficients and derived grid/RMS values remain applicable. Current source hashes are recorded separately for every exported run.

## Historical pre-refactor spectrum audit

## 1. Scope and evidence

This document records the configuration implemented in the Main workspace as reviewed on **2026-10-13**. Values labeled **implemented** come directly from the simulation code; values labeled **derived** are calculated from those settings. This review did not change simulation parameters, run MATLAB, or generate simulation results.

| Local source | Evidence used | Location |
|---|---|---|
| [IBXS simulation](../IBXS%20Suspension/simulate_ibxs_li2021.m) | Spectrum constants, IFFT, delayed rear input, spectral velocity, interpolation and caching | `makeReferenceTrack`, lines 198-242; lines 57-73 |
| [TIXS simulation](../TIXS%20Suspension/simulate_tixs_li2021.m) | The same spectrum algorithm, speed and support spacing | Lines 17-26; `makeLi2021Track`, lines 213-254 |
| [IBXS derivation source](../docs/IBXS_Lagrange_Derivation.tex) | Guideway displacement and velocity entering the primary suspension | Sections 4-6; labels `eq:G` and `eq:matrix` |
| [TIXS derivation source](../docs/TIXS_Lagrange_Derivation.tex) | Guideway inputs, primary forces and coordinate conventions | Sections 3-4; labels `eq:original-constitutive` and `eq:vehicle-matrix-eom` |

The corresponding PDFs were also read through text extraction: 5 pages for IBXS and 8 pages for TIXS. The TIXS PDF does not contain several additions present in its current TeX source; see the [dynamics document](suspension_dynamics_configuration.md). Neither derivation supplies the numerical railway-spectrum configuration, so the two MATLAB implementations are the direct evidence for the numerical choices below.

This Markdown file is a **configuration record**, not a configuration file loaded by MATLAB. Spectrum settings are currently hard-coded separately in the two local track-generation functions. Comments attribute the realization to `reproduce_li2021_passive.m`, but that file is absent from the reviewed Main workspace. Attribution in a comment is not evidence of an executed comparison with that external implementation.

## 2. Spectrum definitions and units

The code maps temporal frequency to angular spatial frequency:

$$
\Omega=\frac{2\pi f}{v},\qquad
S_v(\Omega)=\frac{A_v\Omega_c^2}
{(\Omega^2+\Omega_r^2)(\Omega^2+\Omega_c^2)}.
$$

The temporal displacement spectrum is obtained using the frequency-variable Jacobian:

$$
S_t(f)=\frac{2\pi}{v}S_v\!\left(\frac{2\pi f}{v}\right).
$$

Here `Sv` denotes the spatial spectrum of **vertical displacement irregularity**, not a velocity spectrum. Track velocities are constructed separately by temporal differentiation.

| Quantity | Meaning | Units/convention |
|---|---|---|
| $v$ | Vehicle speed | m/s |
| $f$ | Temporal frequency | Hz |
| $\Omega,\Omega_r,\Omega_c$ | Angular spatial frequencies | rad/m |
| $S_v$ | Spatial displacement PSD | Displacement squared per angular spatial frequency; m^3 with radians dimensionless |
| $S_t$ | Temporal displacement PSD | m^2/Hz |
| $A_v$ | Spectrum amplitude coefficient | Length dimension inferred from this formula with radians dimensionless |
| $x_f,x_r$ | Front and rear guideway displacements | m |
| $\dot x_f,\dot x_r$ | Guideway velocities | m/s |

The source does not annotate the units of `Av`; its dimensional interpretation above follows from the implemented equation and SI displacement units, rather than an independent verification of the original publication's notation. The synthesis is consistent with a **one-sided temporal PSD**, because each cosine amplitude is based on $\sqrt{2S_t\Delta f}$.

The local sources do not identify the railway quality/disturbance class associated with `Av`, the original table supplying the spectrum coefficients, or the calibration basis for `spectrumScale = 0.62`. Those details remain unspecified; no high- or low-disturbance classification is assigned here.

## 3. Implemented settings shared by both simulations

| Setting | Code name/expression | Implemented value | Purpose and units |
|---|---|---:|---|
| Speed | `v = 500/3.6` | 500 km/h = 138.888888889 m/s | Spectrum conversion and support delay |
| Spectrum coefficient | `Av` | `4.032e-7` | Amplitude coefficient; dimensional interpretation in Section 2 |
| Low characteristic spatial frequency | `OmegaR` | 0.0206 rad/m | Spectrum shape |
| High characteristic spatial frequency | `OmegaC` | 0.8246 rad/m | Spectrum shape |
| Random seed | `seed` | 127 | Integer seed |
| Random generator | `rng(seed,'twister')` | `twister` | Random phase realization |
| Periodic record duration | `recordSeconds` | 20 s | Sets the frequency spacing |
| FFT length | `N = 2^15` | 32768 samples | Even-length transform |
| Lower retained temporal frequency | `fMin` | 1.0 Hz | Lower band limit |
| Upper retained temporal frequency | `fMax` | 80 Hz | Upper band limit |
| Displacement amplitude multiplier | `spectrumScale` | 0.62 | Dimensionless multiplier of synthesized amplitudes |
| Center-to-support distance | IBXS `d`; TIXS `L` | 3.8 m | Symmetric vehicle attachment distance |
| Front-to-rear support distance | `2*d` or `2*L` | 7.6 m | Delay for the same moving guideway realization |
| Vehicle response output grid | `tOut = (0:0.002:10)'` | 0-10 s | Different from the 20 s synthesis record |

The band limitation is a hard cutoff:

```matlab
St(f < fMin | f > fMax) = 0;
```

Both 1 Hz and 80 Hz are retained. The code does not apply a taper, window, detrending operation, clipping, or post-synthesis RMS normalization.

The multiplier `0.62` scales **displacement amplitude**, so the realized PSD in the retained band is

$$
S_{\mathrm{realized}}(f)=0.62^2S_t(f)=0.3844S_t(f).
$$

Equivalently, the effective PSD coefficient would be $A_{v,\mathrm{eff}}=1.5499008\times10^{-7}$; the actual implementation retains the original `Av` and multiplies the synthesized amplitudes instead.

## 4. Discretization and derived quantities

$$
\Delta t=\frac{T}{N},\quad t_n=n\Delta t\quad(n=0,\ldots,N-1),\qquad
\Delta f=\frac1T,\quad f_k=k\Delta f\quad(k=0,\ldots,N/2).
$$

| Derived quantity | Value | Interpretation |
|---|---:|---|
| Track sample interval | 0.0006103515625 s | $20/32768$ |
| Track sample rate | 1638.4 Hz | $1/\Delta t$ |
| Nyquist frequency | 819.2 Hz | Above the retained upper limit of 80 Hz |
| Frequency spacing | 0.05 Hz | $1/20$ |
| Final track sample time | 19.9993896484375 s | The duplicate 20 s endpoint is excluded |
| Retained positive-frequency indices | $k=20,\ldots,1600$ | 1581 frequency bins |
| Retained angular spatial frequencies | 0.045238934212-3.619114736935 rad/m | $2\pi f/v$ |
| Retained wavelengths | 1.736111111111-138.888888888889 m | $\lambda=v/f$ |
| Rear delay $\tau$ | 0.05472 s | $7.6/v$ |
| Delay in synthesis samples | 89.653248 | Noninteger; no integer rounding is applied |
| Response output interval | 0.002 s | 500 Hz output grid |
| Response output samples | 5001 | Includes both 0 and 10 s |

`OmegaR` and `OmegaC` describe the spectrum shape; `fMin` and `fMax` impose an additional temporal band limit. These are distinct settings.

## 5. Realization code and normalization

### 5.1 Random-phase Hermitian IFFT

The following is the realization core from IBXS `makeReferenceTrack(d)`. It is a documentation excerpt, not a new executable simulation script. TIXS uses the same operations, with `L` replacing `d`, speed supplied as an argument, and different output field names.

```matlab
v = 500/3.6;
Av = 4.032e-7;
OmegaR = 0.0206;
OmegaC = 0.8246;
seed = 127;
recordSeconds = 20;
N = 2^15;
fMin = 1.0;
fMax = 80;
spectrumScale = 0.62;
dt = recordSeconds/N;
tTrack = (0:N-1)'*dt;
df = 1/recordSeconds;
f = (0:N/2)'*df;
Omega = 2*pi*f/v;
Sv = Av*OmegaC^2./((Omega.^2+OmegaR^2).*(Omega.^2+OmegaC^2));
St = (2*pi/v)*Sv;
St(f < fMin | f > fMax) = 0;
rng(seed,'twister');
phase = 2*pi*rand(N/2-1,1);
amplitude = spectrumScale*sqrt(2*St(2:N/2)*df);
X = complex(zeros(N,1));
X(2:N/2) = (N/2)*amplitude.*exp(1i*phase);
X(N/2+2:N) = conj(X(N/2:-1:2));
xFront = real(ifft(X));
tau = 2*d/v;
rearPhase = exp(-1i*2*pi*f(2:N/2)*tau);
Xrear = complex(zeros(N,1));
Xrear(2:N/2) = X(2:N/2).*rearPhase;
Xrear(N/2+2:N) = conj(Xrear(N/2:-1:2));
xRear = real(ifft(Xrear));
Vfront = complex(zeros(N,1));
Vrear = complex(zeros(N,1));
Vfront(2:N/2) = 1i*2*pi*f(2:N/2).*X(2:N/2);
Vrear(2:N/2) = 1i*2*pi*f(2:N/2).*Xrear(2:N/2);
Vfront(N/2+2:N) = conj(Vfront(N/2:-1:2));
Vrear(N/2+2:N) = conj(Vrear(N/2:-1:2));
vFront = real(ifft(Vfront));
vRear = real(ifft(Vrear));
```

For $k=1,\ldots,N/2-1$, the cosine amplitude and MATLAB coefficient are

$$
a_k=0.62\sqrt{2S_t(f_k)\Delta f},\qquad
X_{k+1}=\frac N2a_k\exp(\mathrm i\phi_k),\quad \phi_k\sim U(0,2\pi).
$$

MATLAB `ifft` supplies a $1/N$ factor. The positive/negative conjugate pair therefore produces $a_k\cos(2\pi f_kt+\phi_k)$; `N/2` is essential to this normalization. DC, `X(1)`, and Nyquist, `X(N/2+1)`, remain zero. Negative-frequency coefficients are conjugate mirrors, producing a real-valued record.

The code draws **16383 phases**, including those corresponding to zero-amplitude frequencies outside the retained band. Drawing phases only for retained bins would change which random numbers are assigned to those bins, even with the same seed. Reproduction therefore requires the generator, seed, draw order and FFT convention, rather than the seed alone.

### 5.2 Rear guideway: phase delay of the same record

$$
X_k^{\mathrm{rear}}=X_k^{\mathrm{front}}\exp(-\mathrm i2\pi f_k\tau),\qquad
x_r(t)=x_f(t-\tau),\qquad \tau=\frac{2d}{v}.
$$

The time-domain identity refers to the **20 s periodic trigonometric realization**. At $t<\tau$, the rear input uses periodic continuation into negative time, rather than an initial zero segment. Rear and front inputs are correlated through this delay, not generated independently. The delay is neither rounded to integer samples nor implemented by shifting a sampled vector.

### 5.3 Track velocity: spectral differentiation

$$
V_k=\mathrm i2\pi f_kX_k,\qquad \dot x(t)=\operatorname{IFFT}(V).
$$

Displacement and velocity samples are derived from the same trigonometric record. During integration they are interpolated independently. Consequently, the interpolated velocity is not exactly the derivative of the piecewise-linear displacement interpolant; consistency is at the underlying synthesis and sampling level.

### 5.4 Full-period RMS calculated from the coefficients

Discrete orthogonality gives

$$
\frac1N\sum_{n=0}^{N-1}x_f(t_n)^2
=\frac12\sum_ka_k^2
=0.62^2\sum_{k=20}^{1600}S_t(f_k)\Delta f.
$$

For the current settings, the **derived full-period discrete displacement RMS is 0.00173286187685 m**, approximately 1.732862 mm. Rear RMS is identical over the full period because the delay changes phase only. This is not the 0-10 s track-window RMS or a vehicle acceleration result. It was calculated algebraically without running MATLAB or creating time histories.

## 6. Integration with the two vehicle models

| Item | IBXS | TIXS |
|---|---|---|
| Track function | `makeReferenceTrack(d)` | `makeLi2021Track(v,L)` |
| Displacement fields | `front`, `rear` | `xf`, `xr` |
| Velocity fields | `vFront`, `vRear` | `vf`, `vr` |
| Common metadata fields | `t`, `seed`, `fMin`, `fMax`, `spectrumScale`, `tau` | Same |
| Interpolation | `griddedInterpolant(...,'linear','none')` | `interp1(...,'linear')` |
| Lifetime | Persistent `referenceTrack` and `roadFit` | Regenerated on every main-function call |
| Primary restoring force | `k1*(q(3:4)-road)+c1*(qd(3:4)-roadV)` | `K1*(q(3:4)-road)+C1*(qd(3:4)-roadV)` |

Neither interpolation enables extrapolation; the current response interval lies within the track record. IBXS generates track data only when its persistent cache is empty. Subsequent cached calls do not reset the RNG or resynthesize the record. TIXS resets the global RNG on every call. When investigating changed IBXS track settings, clear the function's persistent state before checking the new realization.

IBXS optionally compares its interpolated tracks against `../li2021_passive_reproduction/time_histories.csv`, relative to its source directory, and only when `writeOutputs` is true. This resolves to a directory under Main that is absent from the reviewed inventory. The code also requires matching sample counts and time differences below `1e-12` s. When comparison cannot be performed, `reference_track_max_abs_difference_m` remains `NaN`, not zero.

The two track algorithms have matching numerical settings and operations. Identical realizations are expected for matching MATLAB RNG behavior and a fresh IBXS cache; no MATLAB pointwise comparison was executed in this review. IBXS derivation coordinates are positive downward, whereas TIXS coordinates are positive upward. Identical numerical arrays do not automatically represent the same signed physical guideway motion across those conventions; physical comparison requires an explicit coordinate mapping.

## 7. Reproduction entry points and output provenance

### 7.1 Existing entry points

For IBXS, with MATLAB's current directory explicitly set to the project root, the following relative-path invocation suppresses the existing output-writing branch:

```matlab
addpath(fullfile(pwd,'IBXS Suspension'));
result = simulate_ibxs_li2021(0.002,false,30,1);
```

This is an invocation example, **not a command executed in this review**. The returned value contains summary fields, not the full track arrays. The complete realization is available internally and is included in the MAT payload only when the original output branch is enabled.

The TIXS filename is `simulate_tixs_li2021.m`, but its primary function declares `simulate_li2021_tixs(alphaDeg)`. Its comparison-rendering helper is also missing from Main, and there is no output-disable parameter. A verified, complete reproduction command cannot be asserted until those issues and output routing are addressed; see the dynamics document for details.

### 7.2 Required locations for future runs

Future runs must allocate a new run identifier when settings or inputs change, and route outputs to

```text
data/IBXS/<run_id>/
pics/IBXS/<run_id>/
data/TIXS/<run_id>/
pics/TIXS/<run_id>/
```

Each directory directly containing results must include a README recording the invocation, source snapshot, complete spectrum parameters, random seed/generator, solver settings, time grids, CSV fields and units. Matplotlib scripts belong beside their generated figures, must read CSVs through relative paths, and must use the workspace's default 3:2 aspect ratio and in-plot comparison legends.

The current MATLAB output branches do not implement this routing. This documentation task created no data or figure runs and did not alter those branches.

For independently reproducible track data, a future CSV should preserve time in seconds, both track displacements in meters and both velocities in meters per second, explicitly identifying whether it contains the full synthesis grid or the response grid. The existing IBXS response CSV omits track columns; TIXS saves both displacements on the response grid but omits track velocities.

### 7.3 Information not established by the local files

MATLAB release, platform, installed products, successful execution history and code revision are not recorded in the supplied sources. This review does not infer them. No original spectrum-class attribution, historical calibration for the amplitude multiplier, or externally validated realization is established here.

## 8. Source snapshot and verification limits

| File relative to the project root | SHA-256 |
|---|---|
| `IBXS Suspension/simulate_ibxs_li2021.m` | `039580c2619396b30668f142628269da235debd1fc85e900142acd3dc9744289` |
| `TIXS Suspension/simulate_tixs_li2021.m` | `f0b7ae9647e034f2dbb507b83fb2e91d2cd1f1d842396c749a1bd3f938210e7b` |

Checks performed: source-text comparison, PDF text review, independent recalculation of grids, retained frequencies, delay and full-period coefficient RMS. Not performed: MATLAB execution, vehicle-response calculation, external paper verification, or comparison against historical CSV files. Derivation-file hashes are recorded in Section 9 of the [dynamics document](suspension_dynamics_configuration.md).
