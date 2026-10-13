function result = simulate_ibxs_li2021(maxStep,writeOutputs,alphaDeg,rodLength,runId,stopTime)
% SIMULATE_IBXS_LI2021 Loaded IBXS benchmark; see README.md and config/.
% Optional positional overrides: MaxStep, output flag, angle, rod length,
% lowercase run ID and response duration. Empty arguments use JSON defaults.
sourceDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(sourceDir);
addpath(fullfile(projectRoot,'common'));
cfg = load_suspension_config(projectRoot,'IBXS');
if nargin < 1 || isempty(maxStep), maxStep = cfg.solver.max_step_s; end
if nargin < 2 || isempty(writeOutputs), writeOutputs = true; end
if nargin < 3 || isempty(alphaDeg), alphaDeg = cfg.secondary.alpha_deg; end
if nargin < 4 || isempty(rodLength), rodLength = cfg.secondary.l; end
if nargin < 5, runId = ''; end
if nargin < 6 || isempty(stopTime), stopTime = cfg.solver.duration_s; end
validateattributes(maxStep,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(alphaDeg,{'numeric'},{'scalar','real','finite','>',0,'<',90});
validateattributes(rodLength,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(writeOutputs,{'logical','numeric'},{'scalar','binary'});
validateattributes(stopTime,{'numeric'},{'scalar','real','finite','positive'});
cfg.solver.max_step_s = maxStep;
cfg.solver.duration_s = stopTime;
cfg.secondary.alpha_deg = alphaDeg;
cfg.secondary.l = rodLength;
assert(strcmp(cfg.secondary.damper_orientation,'horizontal'),'IBXS requires horizontal damping.');
runTimer = tic;

% Li et al. vehicle and primary suspension, in SI units.
par.mc = cfg.vehicle.mc;
par.Ic = cfg.vehicle.Ic;
par.m1 = cfg.vehicle.m1;
par.d = cfg.vehicle.d;
par.k1 = cfg.vehicle.k1;
par.c1 = cfg.vehicle.c1;

% Each horizontal X-unit has the stated linear-group internal coefficients.
par.kX = cfg.secondary.k;
par.cX = cfg.secondary.c;
par.b = cfg.secondary.b;
par.l = rodLength;
par.alphaDeg = alphaDeg;
par.alpha = deg2rad(par.alphaDeg);
par.g = cfg.vehicle.g;
par.H0 = 2*par.l*sin(par.alpha);
par.w0 = 2*par.l*cos(par.alpha);
par.P = par.mc*par.g/2;  % Static load per branch.
par.wn = par.w0-par.P/(par.kX*tan(par.alpha));
par.B = [1,1; -par.d,par.d; -1,0; 0,-1];
par.M0 = diag([par.mc,par.Ic,par.m1,par.m1]);
par.Ktan = par.kX*tan(par.alpha)^2 ...
    -par.P/(2*par.l*sin(par.alpha)*cos(par.alpha)^2);
par.Ctan = par.cX*tan(par.alpha)^2;
par.mutan = par.b*tan(par.alpha)^2;
assert(par.wn > 0 && par.Ktan > 0, ...
    'The requested static configuration has no positive natural length or tangent stiffness.');

track = make_li2021_track(cfg.track,par.d);
roadFit.front = griddedInterpolant(track.t,track.front,'linear','none');
roadFit.rear = griddedInterpolant(track.t,track.rear,'linear','none');
roadFit.vFront = griddedInterpolant(track.t,track.vFront,'linear','none');
roadFit.vRear = griddedInterpolant(track.t,track.vRear,'linear','none');
assert(stopTime <= track.t(end),'Response interval exceeds the track record.');
assert(abs(stopTime/cfg.solver.output_step_s-round(stopTime/cfg.solver.output_step_s)) < 1e-9, ...
    'Response duration must be a multiple of output_step_s.');
tOut = (0:cfg.solver.output_step_s:stopTime)';
opts = odeset('RelTol',cfg.solver.rel_tol,'AbsTol',cfg.solver.abs_tol,'MaxStep',maxStep);
[t,Y] = ode45(@(tt,y)ibxsRhs(tt,y,par,roadFit),tOut,cfg.solver.initial_state(:),opts);
validate_solution(t,Y,tOut,'IBXS');

% Evaluate acceleration from the equations, avoiding numerical differentiation.
aBody = zeros(numel(t),1);
minH = inf;
maxH = -inf;
minW = inf;
for j = 1:numel(t)
    [qdd,geom] = ibxsAcceleration(t(j),Y(j,1:4).', ...
        Y(j,5:8).',par,roadFit);
    aBody(j) = qdd(1);
    minH = min(minH,min(geom.H));
    maxH = max(maxH,max(geom.H));
    minW = min(minW,min(geom.w));
end
rms10 = sqrt(trapz(t,aBody.^2)/(t(end)-t(1)));

assert(all(isfinite(aBody)),'IBXS acceleration contains NaN or Inf.');
frontRoad = roadFit.front(t); rearRoad = roadFit.rear(t);
frontRoadV = roadFit.vFront(t); rearRoadV = roadFit.vRear(t);
trackDifference = [];
referenceStatus = 'not_configured';
if ~isempty(cfg.reference_track_csv)
    referenceCsv = fullfile(projectRoot,cfg.reference_track_csv);
    assert(isfile(referenceCsv),'Configured reference CSV is missing: %s',referenceCsv);
    ref = readtable(referenceCsv);
    assert(all(ismember({'time_s','front_track_m','rear_track_m'},ref.Properties.VariableNames)), ...
        'Reference CSV has missing track columns.');
    assert(numel(ref.time_s) == numel(t) && max(abs(ref.time_s-t)) < 1e-12, ...
        'Reference CSV time grid differs from this run.');
    assert(all(isfinite(ref{:,{'time_s','front_track_m','rear_track_m'}}),'all'), ...
        'Reference CSV contains NaN or Inf.');
    trackDifference = max(abs([frontRoad-ref.front_track_m;rearRoad-ref.rear_track_m]));
    referenceStatus = 'compared';
end

result = struct( ...
    'rms_0_10_s_m_s2',rms10, ...
    'rod_length_m',par.l, ...
    'inerter_inertance_per_branch_kg',par.b, ...
    'horizontal_spring_per_branch_N_m',par.kX, ...
    'horizontal_damper_per_branch_Ns_m',par.cX, ...
    'initial_angle_deg',par.alphaDeg, ...
    'spring_natural_length_m',par.wn, ...
    'static_load_per_branch_N',par.P, ...
    'tangent_stiffness_per_branch_N_m',par.Ktan, ...
    'tangent_damping_per_branch_Ns_m',par.Ctan, ...
    'tangent_inertance_per_branch_kg',par.mutan, ...
    'minimum_height_m',minH, ...
    'maximum_height_m',maxH, ...
    'minimum_hinge_span_m',minW, ...
    'reference_track_max_abs_difference_m',trackDifference, ...
    'solver_max_step_s',maxStep, ...
    'track_seed',track.seed, ...
    'track_f_min_hz',track.fMin, ...
    'track_f_max_hz',track.fMax, ...
    'track_spectrum_scale',track.spectrumScale, ...
    'track_rear_delay_s',track.tau);

result.reference_track_status = referenceStatus;
result.duration_s = stopTime;
result.runtime_seconds = toc(runTimer);
result.effective_config = cfg;
if ~writeOutputs
    return
end
history = table(t,aBody,Y(:,1),Y(:,2),Y(:,3),Y(:,4), ...
    frontRoad,rearRoad,frontRoadV,rearRoadV,Y(:,5),Y(:,6),Y(:,7),Y(:,8), ...
    'VariableNames',{'time_s','body_vertical_acceleration_m_s2', ...
    'body_heave_m','body_pitch_rad','front_bogie_heave_m','rear_bogie_heave_m', ...
    'front_track_m','rear_track_m','front_track_velocity_m_s','rear_track_velocity_m_s', ...
    'body_heave_velocity_m_s','body_pitch_velocity_rad_s','front_bogie_velocity_m_s','rear_bogie_velocity_m_s'});
payload = struct('par',par,'track',track,'t',t,'Y',Y,'aBody',aBody);
result = export_suspension_run(projectRoot,cfg,result,payload,history, ...
    'IBXS Suspension/simulate_ibxs_li2021.m',runId);
fprintf('IBXS acceleration RMS (0-%.6g s): %.9f m/s^2\n',stopTime,rms10);
end

function dy = ibxsRhs(tt,y,par,roadFit)
q = y(1:4);
qd = y(5:8);
qdd = ibxsAcceleration(tt,q,qd,par,roadFit);
dy = [qd;qdd];
end

function [qdd,geom] = ibxsAcceleration(tt,q,qd,par,roadFit)
r = par.B.'*q;
rd = par.B.'*qd;
H = par.H0-r;
if any(H <= 0 | H >= 2*par.l)
    error('X-unit geometry left its non-inverted physical stroke at t = %.9g s.',tt);
end
w = sqrt(4*par.l^2-H.^2);
J = H./w;
Jprime = -4*par.l^2./w.^3;
mu = par.b*J.^2;
muprime = 2*par.b*J.*Jprime;

% N_i = F_i - mu_i*rdd_i in Eq. (6.1) of docs/IBXS_Lagrange_Derivation.tex.
N = 0.5*muprime.*rd.^2 + par.cX*J.^2.*rd ...
    +par.kX*(w-par.wn).*J-par.P;
road = [roadFit.front(tt);roadFit.rear(tt)];
roadV = [roadFit.vFront(tt);roadFit.vRear(tt)];
G = par.k1*(q(3:4)-road)+par.c1*(qd(3:4)-roadV);
M = par.M0+par.B*diag(mu)*par.B.';
qdd = M\(-par.B*N-[0;0;G]);
geom = struct('H',H,'w',w);
end
