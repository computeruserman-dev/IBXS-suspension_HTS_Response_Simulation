# IBXS and TIXS Vehicle Dynamics: Equations and Configuration

## Current implementation after the naming and output refactor

Current entry points are `simulate_ibxs_li2021(maxStep,writeOutputs,alphaDeg,rodLength,runId,stopTime)` and `simulate_tixs_li2021(alphaDeg,writeOutputs,runId,stopTime)`. Both primary function names now match their existing filenames. Empty arguments use the matching versioned JSON in this directory; positional overrides take precedence and are serialized in every run. Physical parameters, exact branch equations, default initial conditions, output grid, solver tolerances and TIXS refinement threshold are unchanged. A short `stopTime` is available for smoke checks; metrics use that actual interval even where compatibility field names retain `10`.

Both functions now call shared track/configuration/output utilities from `../common/`. The old missing TIXS rendering helper and all MATLAB figure-writing branches have been removed. MATLAB writes data and prepares a self-contained Matplotlib script; figure generation is a separate CSV-only Python step. `writeOutputs=false` creates no run directories. An empty run ID creates a unique timestamp identifier; an explicit existing run ID is rejected.

Data are stored in `data/<Suspension>/<run_id>/time_histories.csv`, `track_realization.csv`, `simulation_results.mat`, `effective_config.json`, `metadata.json` and `README.md`. Plots and `plot_time_histories.py` are stored in the paired `pics/<Suspension>/<run_id>/`, with its own README. Every response/track CSV includes explicit units through named columns and metadata. MAT payloads now preserve complete states, parameters, effective configuration, track arrays and provenance; TIXS includes the linear and refined solutions. Before export, incomplete solver grids and non-finite values are rejected. Optional IBXS reference comparison is explicitly configured; an absent comparison is empty, with a status string.

The generated plotting script uses Agg, relative paths anchored to its own directory, 3:2 canvases, PNG/PDF exports, and an in-plot legend for TIXS comparisons. Intentional figure-only regeneration requires `--overwrite` and does not change numerical data. Model and shared README files document execution and run provenance.

The following sections preserve the **pre-refactor audit**. Their interface descriptions, source line numbers, output names, missing-helper statements and unchanged-source assertions describe the old snapshots identified by the historical hashes. They are retained as provenance, not current workflow instructions. The model equations and default numerical values remain applicable; current source hashes are captured in each exported run.

## Historical pre-refactor dynamics audit

## 1. Scope, sources and interpretation

This document records the equations, physical parameters, solver settings and output behavior present in the Main workspace on **2026-10-13**. It separately describes IBXS and TIXS because their damper topology, coordinate conventions and default operating angles differ. The companion [railway-spectrum document](german_railway_spectrum_configuration.md) specifies the shared excitation and realization code.

| Source | Role in this document |
|---|---|
| [IBXS TeX derivation](../docs/IBXS_Lagrange_Derivation.tex) | Sections 1-8: signs, geometry, preload, energy, full equations and linearization |
| [IBXS PDF](../docs/IBXS_Lagrange_Derivation.pdf) | Five-page rendered derivation; text checked against the TeX |
| [IBXS MATLAB source](../IBXS%20Suspension/simulate_ibxs_li2021.m) | Actual parameters, acceleration implementation, solver and output schema |
| [TIXS TeX derivation](../docs/TIXS_Lagrange_Derivation.tex) | Sections 2-4: isolated reference model, vehicle replacement, preload and equations |
| [TIXS PDF](../docs/TIXS_Lagrange_Derivation.pdf) | Eight-page rendered derivation; contains an earlier set of explanatory passages |
| [TIXS MATLAB source](../TIXS%20Suspension/simulate_tixs_li2021.m) | Actual parameters, nonlinear/linear integrations, refinement check and outputs |

**Implemented** values below come from code. **Derived** values are recalculated from the formulas, not simulated response results. This Markdown file is a descriptive configuration record: neither MATLAB function reads it or other files in `config/`. No source equation, parameter or simulation file was modified for this documentation task.

The source documents cite Li et al. (2021) for the four-DOF vehicle and Wang et al. (2024) for the isolated TIXS model. These are local-document attributions; the external papers and their original parameter tables were not independently checked. The TIXS vehicle combination is described in its derivation as a new replacement model, rather than an equation already supplied by Li et al.

## 2. Shared vehicle configuration and assumptions

### 2.1 Physical quantities

| Quantity | IBXS code | TIXS code | Implemented value | Units and interpretation |
|---|---|---|---:|---|
| Car-body mass | `par.mc` | `m2` | 8500 | kg |
| Car-body pitch inertia | `par.Ic` | `I2` | 192500 | kg m^2 |
| Mass of each bogie-Dewar assembly | `par.m1` | `m1` | 4032 | kg per front/rear assembly |
| Center-to-support distance | `par.d` | `L` | 3.8 | m; symmetric front and rear |
| Primary stiffness | `par.k1` | `K1` | 3542400 | N/m per bogie branch |
| Primary damping | `par.c1` | `C1` | 2419.2 | N s/m per bogie branch |
| Secondary transverse spring coefficient | `par.kX` | `K2` | 730000 | N/m per X-unit/complete branch |
| Secondary damper coefficient | `par.cX` | `C2` | 50000 | N s/m; horizontal in IBXS, vertical in TIXS |
| Transverse inerter inertance | `par.b` | `b` | 500 | kg per branch; not rod or bogie mass |
| Individual rod length | `par.l` | `l` | 1.0 default | m; adjustable by argument only in IBXS |
| Gravitational acceleration | `par.g` | `g` | 9.81 | m/s^2 |
| Loaded rod angle from horizontal | `par.alphaDeg` | `alphaDeg` | IBXS 30; TIXS 45 | degrees; converted to radians |

These are branch-level coefficients. Do not multiply them by the number of physical devices without a separate model of the device arrangement. In particular, TIXS `K2` denotes the transverse spring coefficient in its nonlinear model, but also denotes the direct vertical secondary stiffness in its conventional linear comparison. Equal numerical coefficients do not make those two stiffnesses mechanically identical.

### 2.2 Model scope

Both vehicles have four generalized coordinates and eight first-order states: car-body heave, car-body pitch, front-bogie heave and rear-bogie heave, followed by their velocities. Both assume a rigid car body, linearized attachment kinematics for small pitch, symmetric front/rear parameters, ideal hinges and massless inextensible X-rods. Each branch has four identical rods; `l` is one rod's length, not the full X-height.

The X-geometry is retained without a Taylor truncation in the nonlinear simulations. Primary HTS levitation remains a linear spring-damper approximation. Roll, lateral motion, bogie pitch, rod inertia, hinge friction, end-stop impacts and nonlinear hysteretic HTS levitation are omitted. The implemented simulations are passive: no actuator or controller force enters the acceleration routines. Optional forces in the derivations are therefore set to zero, not configured as PID/fuzzy-PID control.

The coordinates are perturbations about a **loaded equilibrium**, not absolute elevations. Gravity is represented through preload and static-force subtraction; adding an extra constant `-g` term to the implemented perturbation equations would count static gravity again.

### 2.3 Common primary force and numerical state form

Let $\boldsymbol\xi=(\xi_a,\xi_b)^T$ be the guideway displacement and $\dot{\boldsymbol\xi}$ its velocity. With the coordinate order given separately below, define

$$
E=\begin{bmatrix}0&0&1&0\\0&0&0&1\end{bmatrix},\qquad
\boldsymbol G=K_1(E\boldsymbol q-\boldsymbol\xi)
+C_1(E\dot{\boldsymbol q}-\dot{\boldsymbol\xi}),
$$

$$
M_0=\operatorname{diag}(8500,192500,4032,4032),\qquad
\boldsymbol y=(\boldsymbol q^T,\dot{\boldsymbol q}^T)^T,\qquad
\dot{\boldsymbol y}=(\dot{\boldsymbol q}^T,\ddot{\boldsymbol q}^T)^T.
$$

`E` is written as `H1` in TIXS and is implicit in IBXS `[0;0;G]`. Matrix entries mix translational and rotational units: the pitch inertia entry is kg m^2, while translational entries are kg. A raw condition number is not a unit-independent mechanical comparison; the TIXS TeX source recommends scaling pitch to a length coordinate before such a comparison.

## 3. IBXS configuration and exact dynamics

### 3.1 Function interface and effective settings

Source: `IBXS Suspension/simulate_ibxs_li2021.m`.

```matlab
function result = simulate_ibxs_li2021(maxStep,writeOutputs,alphaDeg,rodLength)
```

| Argument | Default | Validation/behavior |
|---|---:|---|
| `maxStep` | 0.002 s | Positive finite scalar; affects solver maximum step only |
| `writeOutputs` | `true` | `false` returns the summary before file writing; no explicit type validation |
| `alphaDeg` | 30 degrees | Finite scalar, strictly between 0 and 90 |
| `rodLength` | 1 m | Positive finite scalar |

The initialization then requires both `wn > 0` and `Ktan > 0`. Speed, spectrum, masses, support distance, spring, damper and inerter constants are not exposed as arguments. Passing a different maximum step does not change the fixed 0.002 s output grid or synthesis grid.

The opening comment refers to `main.tex`, which is absent from this source directory. The reviewed matching derivation is `docs/IBXS_Lagrange_Derivation.tex`; the name in the code comment is stale.

### 3.2 Coordinates, signs and geometric map

IBXS uses downward-positive vertical coordinates. Its pitch convention gives front/branch-a attachment displacement $x_c-d\varphi_c$ and rear/branch-b displacement $x_c+d\varphi_c$:

$$
\boldsymbol q_I=(x_c,\varphi_c,x_{1a},x_{1b})^T,\qquad
B_I=\begin{bmatrix}1&1\\-d&d\\-1&0\\0&-1\end{bmatrix},\qquad
\boldsymbol r=B_I^T\boldsymbol q_I.
$$

Thus $r_a=x_c-d\varphi_c-x_{1a}$ and $r_b=x_c+d\varphi_c-x_{1b}$. Positive $r_i$ is compression, not absolute height:

$$
H_0=2l\sin\alpha,\quad H_i=H_0-r_i,\quad
w_i=\sqrt{4l^2-H_i^2},\quad J_i=\frac{dw_i}{dr_i}=\frac{H_i}{w_i},\quad
J_i'=-\frac{4l^2}{w_i^3}.
$$

The allowed non-inverted stroke is $0<H_i<2l$, equivalently $H_0-2l<r_i<H_0$. For the default $l=1$ m, $\alpha=30$ degrees, this is **$-1<r_i<1$ m**. Every acceleration evaluation rejects states at or beyond the endpoints with an error; there is no mechanical stop/contact model.

The spring, damper and inerter are all connected horizontally between the lateral hinges. Therefore $\dot w_i=J_i\dot r_i$ and $\ddot w_i=J_i\ddot r_i+J_i'\dot r_i^2$.

### 3.3 Static preload

For symmetric support and no static actuator bias,

$$
P=\frac{m_cg}{2},\qquad w_0=2l\cos\alpha,\qquad
w_n=w_0-\frac{P}{k_X\tan\alpha}.
$$

The branch's transverse spring energy and generalized spring force are

$$
V_X=\tfrac12k_X(w-w_n)^2,\qquad S(r)=k_X(w-w_n)J,
$$

so $S(0)=P$. The perturbation force subtracts $P$, producing zero secondary dynamic force at $r=\dot r=0$. The static primary levitation load is $L_0=m_1g+P$; it has already been removed from the perturbation primary force.

Setting $w_n=w_0$ without an independent static load path would remove the spring's supporting force and contradict the loaded-equilibrium assumption.

### 3.4 Branch force, mass matrix and scalar equations

The geometry-transformed inertance and its derivative are

$$
\mu_i=bJ_i^2,\qquad \mu_i'=2bJ_iJ_i'=-\frac{8bl^2H_i}{w_i^4}.
$$

Define the acceleration-independent branch contribution

$$
N_i=\tfrac12\mu_i'\dot r_i^2+c_XJ_i^2\dot r_i
+k_X(w_i-w_n)J_i-P,
\qquad F_i=\mu_i\ddot r_i+N_i.
$$

The negative velocity-squared coefficient follows from the compression coordinate; it is not an optional damping term. Horizontal damping must be transformed by $J_i^2$.

The passive scalar equations are

$$
\begin{aligned}
m_c\ddot x_c+F_a+F_b&=0,\\
I_c\ddot\varphi_c-dF_a+dF_b&=0,\\
m_1\ddot x_{1a}+G_a-F_a&=0,\\
m_1\ddot x_{1b}+G_b-F_b&=0.
\end{aligned}
$$

Since the branch force itself contains acceleration, the implementation collects those terms into

$$
M_I(\boldsymbol q)=M_0+B_I\operatorname{diag}(\mu_a,\mu_b)B_I^T,
\qquad M_I\ddot{\boldsymbol q}=-B_I\boldsymbol N-E^T\boldsymbol G.
$$

Explicitly,

$$
M_I=\begin{bmatrix}
m_c+\mu_a+\mu_b&d(\mu_b-\mu_a)&-\mu_a&-\mu_b\\
d(\mu_b-\mu_a)&I_c+d^2(\mu_a+\mu_b)&d\mu_a&-d\mu_b\\
-\mu_a&d\mu_a&m_1+\mu_a&0\\
-\mu_b&-d\mu_b&0&m_1+\mu_b
\end{bmatrix}.
$$

Code trace: initialization lines 28-55; `ibxsRhs` lines 167-172; `ibxsAcceleration` lines 174-195. The numerical solve is `M\(-par.B*N-[0;0;G])`, not an inverse-matrix multiplication. The matrix is symmetric positive definite for positive physical masses and nonnegative inertance within the admissible geometry, but this alone does not establish stiffness stability or good conditioning near a geometric endpoint.

### 3.5 Default derived quantities and local linearization

At equilibrium,

$$
\mu_0=b\tan^2\alpha,\qquad C_{I,\mathrm{tan}}=c_X\tan^2\alpha,\qquad
K_{I,\mathrm{tan}}=k_X\tan^2\alpha-
\frac{P}{2l\sin\alpha\cos^2\alpha}.
$$

| Derived default quantity | Value | Units |
|---|---:|---|
| Loaded angle | 0.523598775598 | rad |
| $P$ | 41692.5 | N per branch |
| $H_0$ | 1.000000000000 | m |
| $w_0$ | 1.732050807569 | m |
| $w_n$ | 1.633128166069 | m |
| Transverse preload extension $w_0-w_n$ | 0.098922641499 | m |
| Transverse spring tension $k_X(w_0-w_n)$ | 72213.528295 | N |
| Vertical tangent stiffness | 187743.333333 | N/m |
| Vertical tangent damping | 16666.666667 | N s/m |
| Vertical equivalent inertance | 166.666667 | kg |
| Static primary levitation force $L_0$ | 81246.42 | N per bogie |

The first-order branch limit is $F_i\simeq\mu_0\ddot r_i+C_{I,\mathrm{tan}}\dot r_i+K_{I,\mathrm{tan}}r_i$. The code still integrates the full nonlinear expressions, not these constants. In particular, the nominal 500 kg transverse inertance becomes approximately 166.667 kg vertically at the default angle, rather than 500 kg.

## 4. TIXS configuration and exact dynamics

### 4.1 Function interface and effective settings

Source filename: `TIXS Suspension/simulate_tixs_li2021.m`. Its primary declaration is currently

```matlab
function result = simulate_li2021_tixs(alphaDeg)
```

The default `alphaDeg` is **45 degrees**. `validateattributes` requires a real, finite numeric scalar strictly between 0 and 90. The filename/declaration mismatch is an unresolved entry-point issue; this document does not rename the file or assume a particular MATLAB behavior for the mismatch.

Rod length, inertance, spring and damping coefficients, integration tolerances and output behavior are hard-coded. There is no `writeOutputs` switch or maximum-step argument. Positive natural spring length and positive tangent stiffness are both asserted before integration.

### 4.2 Coordinates, topology and geometry

TIXS vertical coordinates are positive upward. Positive pitch raises the front attachment:

$$
\boldsymbol q_T=(z_c,\varphi,z_a,z_b)^T,\qquad
B_T=\begin{bmatrix}1&1\\L&-L\\-1&0\\0&-1\end{bmatrix},\qquad
\boldsymbol r=B_T^T\boldsymbol q_T.
$$

Hence $r_a=z_c+L\varphi-z_a$ and $r_b=z_c-L\varphi-z_b$. Positive $r_i$ increases the vertical separation:

$$
s_i=l\sin\alpha+\frac{r_i}{2},\qquad
D_i=l^2-s_i^2,\qquad R_i=\sqrt{D_i},\qquad w_i=2R_i.
$$

Allowed geometry is $0<s_i<l$, or $-2l\sin\alpha<r_i<2l(1-\sin\alpha)$. The default stroke is **$-1.414213562373<r_i<0.585786437627$ m**. Every acceleration evaluation rejects `s <= 0`, `s >= l`, or `D <= 0`.

TIXS uses a **transverse spring and transverse inerter, but a vertical damper**. Thus its damper contributes $C_2\dot r_i$ directly, with no $J^2$ factor. This is a physical topology distinction from the implemented IBXS.

### 4.3 Loaded equilibrium and preload

The implementation sets

$$
P_i=\frac{m_2g}{2},\qquad F_{0i}=-P_i,\qquad
w_0=2l\cos\alpha,\qquad w_{ni}=w_0-\frac{P_i}{K_2\tan\alpha}.
$$

`P`, `F0` and `wn` are two-entry vectors, while the symmetric rod and spring constants are scalars. The negative static generalized force corresponds to upward physical support in the upward-positive coordinate system.

The TeX derivation also provides the more general, unequal-arm load split:

$$
P_a=\frac{m_2gL_b}{L_a+L_b},\qquad
P_b=\frac{m_2gL_a}{L_a+L_b}.
$$

The simulation uses only $L_a=L_b=L=3.8$ m. Asymmetric geometry is not an exposed configuration.

With $V_i=\tfrac12K_2(w_i-w_{ni})^2$,

$$
V_i'(r_i)=-K_2(2R_i-w_{ni})\frac{s_i}{R_i},\qquad V_i'(0)=F_{0i}.
$$

Static preload subtraction is therefore `Vp - F0`, which is `Vp + P`, not `Vp - P`. No separate static actuator force is installed. Static primary levitation again supports $m_1g+P_i$.

### 4.4 Branch force, coupled mass matrix and equations

$$
\mu_i=b\frac{s_i^2}{D_i},\qquad
\mu_i'=\frac{bl^2s_i}{D_i^2},\qquad
H_i=\tfrac12\mu_i'\dot r_i^2+C_2\dot r_i+V_i'(r_i)-F_{0i},
$$

$$
\Delta F_i=\mu_i\ddot r_i+H_i.
$$

On the permitted branch with $b\geq0$, $\mu_i'$ is nonnegative; its sign differs from IBXS because the relative coordinate increases height rather than compression. Here $H_i$ means the acceleration-independent force term, **not** the IBXS geometric height $H_i$.

The passive scalar equations are

$$
\begin{aligned}
m_2\ddot z_c+\Delta F_a+\Delta F_b&=0,\\
I_2\ddot\varphi+L\Delta F_a-L\Delta F_b&=0,\\
m_1\ddot z_a+G_a-\Delta F_a&=0,\\
m_1\ddot z_b+G_b-\Delta F_b&=0.
\end{aligned}
$$

The explicit acceleration form is

$$
M_T(\boldsymbol q)=M_0+B_T\operatorname{diag}(\mu_a,\mu_b)B_T^T,
\qquad M_T\ddot{\boldsymbol q}=-B_T\boldsymbol H-E^T\boldsymbol G,
$$

$$
M_T=\begin{bmatrix}
m_2+\mu_a+\mu_b&L(\mu_a-\mu_b)&-\mu_a&-\mu_b\\
L(\mu_a-\mu_b)&I_2+L^2(\mu_a+\mu_b)&-L\mu_a&L\mu_b\\
-\mu_a&-L\mu_a&m_1+\mu_a&0\\
-\mu_b&L\mu_b&0&m_1+\mu_b
\end{bmatrix}.
$$

Code trace: initialization lines 17-44; `tixsRhs` lines 175-178; `tixsAcceleration` lines 180-200. The solve is `M\(-par.B*H-par.H1.'*primary)`. State-dependent mass and the velocity-squared term are retained throughout integration.

### 4.5 Default derived quantities and local limit

$$
\mu_0=b\tan^2\alpha,\qquad C_{T,\mathrm{tan}}=C_2,\qquad
K_{T,\mathrm{tan}}=K_2\tan^2\alpha-
\frac{P}{2l\sin\alpha\cos^2\alpha}
=\frac{2K_2l\sin^3\alpha-P}{2l\sin\alpha\cos^2\alpha}.
$$

| Derived default quantity | Value | Units |
|---|---:|---|
| Loaded angle | 0.785398163397 | rad |
| $P_i$ | 41692.5 | N per branch |
| $F_{0i}$ | -41692.5 | N, signed generalized spring force |
| Loaded height $2l\sin\alpha$ | 1.414213562373 | m |
| $w_0$ | 1.414213562373 | m |
| $w_n$ | 1.357100548674 | m |
| Transverse preload extension | 0.057113013699 | m |
| Transverse spring tension | 41692.5 | N |
| Vertical tangent stiffness | 671037.901051 | N/m |
| Vertical tangent damping | 50000 | N s/m |
| Vertical equivalent inertance | 500 | kg |
| Static primary levitation force | 81246.42 | N per bogie |

The first-order force is $\Delta F_i\simeq\mu_0\ddot r_i+C_2\dot r_i+K_{T,\mathrm{tan}}r_i$. The direct linear comparison in the code uses 730000 N/m secondary stiffness, not the loaded TIXS tangent stiffness 671037.901051 N/m.

### 4.6 Isolated reference model versus the simulated vehicle

Section 2 of the TIXS TeX source describes an unpreloaded isolated oscillator, whose spring is undeformed at $u=0$ and whose reference equation omits gravity:

$$
[M_1+\mu(u)]\ddot u+\tfrac12\mu'(u)\dot u^2+c\dot u+kx(u)x'(u)
=-M_1\ddot z,
\qquad x(u)=2l\cos\alpha-2\sqrt{l^2-(l\sin\alpha+u/2)^2}.
$$

Its theoretical nondimensional variables are $\omega_n=\sqrt{k/M_1}$, $U=u/(2l)$, $Z=z_m/(2l)$, $\tau=\omega_nt$, $\Omega=\omega/\omega_n$, $\delta=b/M_1$ and $\zeta=c/(2M_1\omega_n)$. These are derivation definitions, **not extra numerical vehicle settings**. The symbol $\tau$ there denotes nondimensional time, whereas the track structure's `tau` denotes rear delay in seconds. Likewise $\Omega$ there is a frequency ratio, not the railway spectrum's angular spatial frequency.

The MATLAB vehicle integrates the dimensional, preloaded four-DOF equations with random guideway displacement/velocity forcing. It does not use harmonic base acceleration, a selected harmonic amplitude, dimensionless integration, or the original paper's later cubic Taylor approximation.

## 5. Comparison, preload stability and coordinate mapping

### 5.1 Direct comparison of the implemented defaults

| Property | IBXS | TIXS |
|---|---|---|
| Vertical convention | Downward positive | Upward positive |
| Branch-a pitch coefficient | $-d$ | $+L$ |
| Relative coordinate | Compression | Extension/increase of height |
| Damper installation | Transverse | Vertical |
| Loaded angle | 30 degrees | 45 degrees |
| Rod length | 1 m default, argument-adjustable | 1 m hard-coded |
| Transverse inertance | 500 kg | 500 kg |
| Equilibrium vertical inertance | 166.666667 kg | 500 kg |
| Equilibrium vertical damping | 16666.666667 N s/m | 50000 N s/m |
| Loaded tangent stiffness | 187743.333333 N/m | 671037.901051 N/m |
| In-code linear baseline | None integrated | Conventional secondary spring-damper vehicle |

A default-to-default response comparison changes topology **and** loaded angle, effective stiffness, damping and inertance. It should not be described as isolating a single topology effect.

If branch labels are aligned as front/rear and $d=L$, consistent coordinate conversion is

$$
\boldsymbol q_T=D\boldsymbol q_I,\quad
D=\operatorname{diag}(-1,1,-1,-1),\quad
B_T=-DB_I,\quad \boldsymbol r_T=-\boldsymbol r_I,
\quad \boldsymbol\xi_T=-\boldsymbol\xi_I.
$$

This preserves the geometry for the same angle and rod length while accounting for the vertical conventions. It does not turn the horizontal IBXS damper into a vertical TIXS damper. Both codes currently generate identical-signed numerical track arrays; physical comparisons must state how those arrays map to signed physical motion.

### 5.2 Feasibility and local stiffness conditions

Both loaded branch models require

$$
w_n>0\iff P<2kl\sin\alpha,\qquad
K_{\mathrm{tan}}>0\iff P<2kl\sin^3\alpha.
$$

For $0<\alpha<\pi/2$, the stiffness bound is stricter than the positive-length bound. With $P=41692.5$ N, $k=730000$ N/m and $l=1$ m, the lower angle bound for positive tangent stiffness is **approximately 17.797723799 degrees**, strictly excluded at equality. IBXS changing `rodLength` also changes this bound and its preload.

The default stability-limit right-hand side is 182500 N for IBXS and 516187.950266 N for TIXS, so both defaults satisfy the local branch condition. This does not constitute a simulated stroke, strength or clearance check.

As the transverse span approaches zero, geometric factors and equivalent inertance become large. The code rejects geometric violations; it does not impose a prescribed positive clearance margin, regularize those factors, or model endpoint impacts. The derivations also distinguish positive mass-matrix definiteness from static stiffness stability.

## 6. Solver configuration, excitation and metrics

### 6.1 Integration settings

| Setting | IBXS nominal | TIXS nominal/linear baseline | TIXS refinement |
|---|---|---|---|
| Solver | `ode45` | `ode45` | `ode45` |
| Response interval | 0-10 s | 0-10 s | 0-10 s |
| Requested output grid | `(0:0.002:10)'` | Same | Same |
| Initial state | `zeros(8,1)` | `zeros(8,1)` | `zeros(8,1)` |
| Relative tolerance | `1e-8` | `1e-8` | `1e-9` |
| Absolute tolerance | `1e-10` | `1e-10` | `1e-11` |
| Maximum internal step | `maxStep`, default 0.002 s | 0.002 s | 0.001 s |
| Track displacement/velocity interpolation | Cached linear interpolants | `interp1`, linear | Same |

The grid spacing is a requested output interval, not a fixed internal integration step. Scalar absolute tolerances apply numerically to both translational and angular state components; no separately scaled component tolerance is configured. No warm-up or transient-discard interval is used. Zero initial perturbation does not imply zero track input at $t=0$.

Both models use the 20 s, 32768-sample, 1-80 Hz track described in the spectrum document. The response output rate is 500 Hz. Changing the track synthesis grid, requested output grid and solver maximum step are three separate configuration changes.

### 6.2 TIXS conventional linear comparison

With the same $B_T$, primary selector $E$, track record, initial state and nominal solver settings,

$$
C_{\mathrm{lin}}=C_2B_TB_T^T+C_1E^TE,\qquad
K_{\mathrm{lin}}=K_2B_TB_T^T+K_1E^TE,
$$

$$
M_0\ddot{\boldsymbol q}_{\mathrm{lin}}
=E^T(K_1\boldsymbol\xi+C_1\dot{\boldsymbol\xi})
-C_{\mathrm{lin}}\dot{\boldsymbol q}_{\mathrm{lin}}
-K_{\mathrm{lin}}\boldsymbol q_{\mathrm{lin}}.
$$

This baseline has no inerter contribution to mass. It is the conventional vehicle, not the TIXS tangent linearization, which would retain $B_T\operatorname{diag}(\mu_0,\mu_0)B_T^T$ and use the loaded tangent stiffness. The code asserts identical output time grids with `isequal(t,tLin)`.

### 6.3 Reported quantities and checks

Both functions calculate car-body acceleration directly from the equations at output times, avoiding numerical differentiation of simulated displacement. The RMS metric is

$$
\mathrm{RMS}_{0-10}=\sqrt{\frac{\operatorname{trapz}(t,a_c^2)}{t_{\mathrm{end}}-t_0}}
$$

in m/s^2. It covers the full 0-10 s interval, including the initial transient, and uses trapezoidal quadrature rather than an unweighted sample mean. There is no ride-comfort frequency weighting, PSD-based RMS or filtering in these implementations.

IBXS reports minimum height, maximum height and minimum hinge span across both branches at requested output times. It has geometry checks during RHS evaluation but no automatic repeated integration for convergence. It attempts the optional reference-track check only when output writing is enabled.

TIXS performs these additional implemented checks:

1. Zero-input equilibrium acceleration: infinity norm below `1e-10`, using zero guideway displacement/velocity and zero perturbation state.
2. Nominal/refined RMS difference: `100*abs(rmsFine10-rms10)/rmsFine10 < 0.5` percent. The output grid remains unchanged; both integration tolerance and maximum step are refined.
3. Sampled endpoint margin: minimum of $s_a,s_b,l-s_a,l-s_b$ is positive, in meters. This is a half-height margin, not a measured hardware clearance or minimum transverse span.

The reported comparison change is `100*(rms10/rmsLinear10-1)`: negative means a lower nonlinear TIXS RMS than the conventional baseline. None of these runtime assertions was executed in this documentation task, so no passing result or acceleration RMS is asserted here.

## 7. Actual outputs, metadata and reproduction status

### 7.1 IBXS output branch

When `writeOutputs` is true, the current code writes directly beside the MATLAB source:

| Actual filename | Contents |
|---|---|
| `ibxs_body_acceleration_0_10s.csv` | Response table described below |
| `ibxs_simulation_500kg.mat` | `result`, `par`, `track`, `t`, `Y`, `aBody` |
| `ibxs_body_acceleration_0_10s.png` | MATLAB acceleration plot, 200 dpi |
| `ibxs_body_acceleration_0_10s.pdf` | MATLAB acceleration plot, painters export |

CSV columns and units:

| Column | Units |
|---|---|
| `time_s` | s |
| `body_vertical_acceleration_m_s2` | m/s^2 |
| `body_heave_m` | m |
| `body_pitch_rad` | rad |
| `front_bogie_heave_m` | m |
| `rear_bogie_heave_m` | m |

The MAT includes all states and complete track arrays, but the CSV does not include track displacements, track velocities or state velocities. `result` records RMS, rod length, transverse inertance/spring/damper values, loaded angle, natural length, static load, tangent stiffness/damping/inertance, sampled geometry extrema, optional reference-track error, maximum step, seed, retained frequency limits, amplitude multiplier and rear delay. It does not record MATLAB version, code revision or all spectrum constants in its summary; those constants must be recovered from the source snapshot.

The output names contain neither angle nor rod length nor run ID. Repeated runs can overwrite previous outputs. This task did not execute that branch.

### 7.2 TIXS output branch

The code forms `tag = sprintf('alpha%g',alphaDeg)` and writes beside the source:

| Intended filename | Contents/status |
|---|---|
| `tixs_body_acceleration_<tag>.png` | Single-response MATLAB plot, 200 dpi |
| `tixs_time_histories_<tag>.csv` | Track displacement and response table |
| `linear_tixs_acceleration_comparison_<tag>.png` | Delegated to the missing helper |
| `tixs_results_<tag>.mat` | Saved only after the comparison helper returns |

At the default angle, `<tag>` is `alpha45`. CSV columns are

| Column | Units |
|---|---|
| `time_s` | s |
| `front_track_m`, `rear_track_m` | m |
| `tixs_body_vertical_acceleration_m_s2` | m/s^2 |
| `linear_body_vertical_acceleration_m_s2` | m/s^2 |
| `front_tixs_relative_displacement_m`, `rear_tixs_relative_displacement_m` | m |

The intended MAT payload is only `result`, `t`, `aBody`, `aBodyLinear`, `relFront`, `relRear`. It omits `par`, full `track`, `Y`, `Ylin` and refined states. The result summary records angle, rod length, transverse coefficients, preload/natural length/tangent stiffness/equilibrium inertance, nonlinear/linear/refined RMS, convergence percentage, comparison change percentage, geometric margin, selected track metadata and paths. It does not fully serialize the implemented physical and solver configuration.

The missing `render_li2021_tixs_comparison(csvPath,comparisonFigurePath)` is called **after** the single-response figure and CSV are written but **before** constructing/saving `result`. If the helper remains unresolved in the execution environment, that call interrupts the remaining output and return path. No helper definition exists in the reviewed Main files; an external MATLAB path could supply one, but its presence and behavior are not established here.

Angle-only tags do not preserve runs when other parameters or inputs change. The code has no output-disable argument.

### 7.3 Invocation and future run records

The IBXS source filename matches its primary function. With MATLAB's working directory explicitly set to the project root, an invocation suppressing file outputs is

```matlab
addpath(fullfile(pwd,'IBXS Suspension'));
result = simulate_ibxs_li2021(0.002,false,30,1);
```

This command was not executed. The filename/declaration discrepancy and unresolved comparison helper prevent presenting the current TIXS chain as a verified complete reproduction entry point. Both models also require compliant output routing before generating preserved formal runs.

Future run documentation must record the complete settings here, spectrum settings from the companion document, invocation, source hashes/revision, actual MATLAB release/platform, solver settings, initial state, seed/generator, units and input/output grids. Changed inputs or parameters require a new `<run_id>`. The required storage is `data/<Suspension>/<run_id>/` for CSV/MAT and `pics/<Suspension>/<run_id>/` for figures plus their Matplotlib scripts; each result directory needs its own provenance README. Plot scripts must use relative CSV paths. No such run directories were needed or created for this documentation-only task.

## 8. Source, document and workspace discrepancies

| Finding | Evidence and implication | Status in this task |
|---|---|---|
| TIXS file/primary-function name mismatch | Filename `simulate_tixs_li2021.m`; declaration `simulate_li2021_tixs` at line 1 | Documented; not renamed |
| Missing TIXS comparison helper | Invocation at line 142; no definition among Main files | Full output chain not verified |
| Missing IBXS reference CSV | Code references Main `li2021_passive_reproduction/time_histories.csv` | Optional error remains `NaN` without a usable reference |
| Stale IBXS derivation name | Opening comment and force comment refer to `main.tex` | Matching local TeX identified without editing source |
| TIXS PDF/TeX content differs | PDF Section 1 lacks the current explicit gravity-free reference distinction; PDF Section 2.3 says the geometric term may change sign with $s$, while current TeX specifies nonnegative behavior on $0<s<l$ | Current TeX and code used for the stated physical range |
| TIXS PDF lacks current additions | Current TeX explicitly adds zero-static-actuator assumptions, complete static primary balance, full gravitational potential, loaded stiffness bound and conditioning discussion | Additions distinguished from rendered PDF; PDF not regenerated |
| No dedicated spectrum derivation in `docs/` | Numerical spectrum constants and realization only in the MATLAB functions | Spectrum settings documented from code |
| Current outputs use source directories | Both set `outDir = fileparts(mfilename('fullpath'))` | Violates required run-separated `data/` and `pics/` routing |
| Current figures are generated by MATLAB | No co-located Matplotlib realization scripts in Main | Does not satisfy the required CSV-to-Matplotlib workflow |
| TIXS source figure has a 2:1 canvas | `Position = [100,100,900,450]` | Unlike the required default 3:2; helper comparison style unknown |
| IBXS source figure uses a 3:2 canvas | 900 by 600 pixels and 9 by 6 inch paper | Ratio agrees; storage/generation workflow still differs |
| Existing output naming permits collisions | Fixed IBXS names; TIXS angle-only tag | New run identifiers and collision handling are not implemented |
| Run environment not recorded | No MATLAB version/release or successful run log supplied | No execution success inferred |

The single-response figures do not use comparison legends. No available helper source establishes the TIXS comparison legend placement. The future default requirement remains a legible legend **inside** the plotting area, with explicit units and a 3:2 figure ratio.

The IBXS PDF's substantive equations match the inspected TeX. The TIXS PDF differences are established by text comparison; no compilation timestamp or exact historical revision is inferred. Neither PDF was modified.

## 9. Source snapshot and checks performed

These SHA-256 hashes identify the files used on 2026-10-13. Line references above refer to these snapshots.

| Project-relative source | SHA-256 |
|---|---|
| `IBXS Suspension/simulate_ibxs_li2021.m` | `039580c2619396b30668f142628269da235debd1fc85e900142acd3dc9744289` |
| `TIXS Suspension/simulate_tixs_li2021.m` | `f0b7ae9647e034f2dbb507b83fb2e91d2cd1f1d842396c749a1bd3f938210e7b` |
| `docs/IBXS_Lagrange_Derivation.tex` | `83c9e743258a8f8da023d7a18ad9a0794312ee6d06f2bd73e38d0b140f015d40` |
| `docs/IBXS_Lagrange_Derivation.pdf` | `c1184a846c062101ae8875aeb88183f861d34870c0e6f350c20ed8af9f0f3ada` |
| `docs/TIXS_Lagrange_Derivation.tex` | `761e0e535ec21e0d8fd1737b8d4ff030265bba2343afb970c2d793c46df53fdf` |
| `docs/TIXS_Lagrange_Derivation.pdf` | `07acf355529d9b8bd7fb0670150fb6dfb45049b745fdbf02e937827afb32220e` |

The review read both complete MATLAB files, both complete TeX sources and extracted all PDF pages. Static calculations independently reproduced default preload, natural length, tangent coefficients, admissible stroke bounds, static primary loads and the minimum stable angle. Documentation links and unchanged-source hashes were checked at handoff.

No MATLAB solver, equilibrium assertion, RMS convergence assertion, historical-track comparison or plotting helper was executed. Consequently, this document reports settings and derived static quantities, not newly verified dynamic performance. The simulation sources and derivation files remain unchanged.
