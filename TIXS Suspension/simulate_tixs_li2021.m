function result = simulate_tixs_li2021(alphaDeg,writeOutputs,runId,stopTime)
% SIMULATE_TIXS_LI2021 Passive loaded TIXS and conventional linear comparison.
% Empty arguments use JSON defaults. Plotting is a separate Matplotlib step.
sourceDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(sourceDir);
addpath(fullfile(projectRoot,'common'));
cfg = load_suspension_config(projectRoot,'TIXS');
if nargin < 1 || isempty(alphaDeg), alphaDeg = cfg.secondary.alpha_deg; end
if nargin < 2 || isempty(writeOutputs), writeOutputs = true; end
if nargin < 3, runId = ''; end
if nargin < 4 || isempty(stopTime), stopTime = cfg.solver.duration_s; end
validateattributes(alphaDeg,{'numeric'},{'scalar','real','finite','>',0,'<',90});
validateattributes(writeOutputs,{'logical','numeric'},{'scalar','binary'});
validateattributes(stopTime,{'numeric'},{'scalar','real','finite','positive'});
cfg.secondary.alpha_deg = alphaDeg;
cfg.solver.duration_s = stopTime;
assert(strcmp(cfg.secondary.damper_orientation,'vertical'),'TIXS requires vertical damping.');
assert(cfg.refinement.enabled,'The TIXS benchmark requires its refined-step verification.');
runTimer = tic;
g = cfg.vehicle.g;
m2 = cfg.vehicle.mc; m1 = cfg.vehicle.m1; I2 = cfg.vehicle.Ic;
L = cfg.vehicle.d;
K1 = cfg.vehicle.k1; C1 = cfg.vehicle.c1;
K2 = cfg.secondary.k; C2 = cfg.secondary.c;
l = cfg.secondary.l; b = cfg.secondary.b;
alpha = deg2rad(alphaDeg);

% Each TIXS branch supports one-half of the static car-body weight.
P = (m2*g/2)*ones(2,1);
F0 = -P;
w0 = 2*l*cos(alpha);
wn = w0 - P/(K2*tan(alpha));
Ktan = (2*K2*l*sin(alpha)^3-P)./(2*l*sin(alpha)*cos(alpha)^2);
mu0 = b*tan(alpha)^2;
assert(all(wn > 0),'TIXS natural spring length is nonpositive.');
assert(all(Ktan > 0),'The passive loaded equilibrium has negative stiffness.');

track = make_li2021_track(cfg.track,L);
B = [1,1; L,-L; -1,0; 0,-1];
H1 = [0,0,1,0; 0,0,0,1];
M0 = diag([m2,I2,m1,m1]);
par = struct('B',B,'M0',M0,'H1',H1,'K1',K1,'C1',C1, ...
    'K2',K2,'C2',C2,'l',l,'b',b,'alpha',alpha,'wn',wn,'F0',F0);

% Verify that the declared loaded operating point is a true zero-input
% equilibrium before the track excitation is introduced.
zeroTrack = struct('t',[0;20],'xf',[0;0],'xr',[0;0], ...
    'vf',[0;0],'vr',[0;0]);
[aEquilibrium,~] = tixsAcceleration(0,zeros(4,1),zeros(4,1), ...
    par,zeroTrack);
assert(norm(aEquilibrium,inf) < 1e-10, ...
    'Loaded static equilibrium residual is nonzero.');

assert(stopTime <= track.t(end),'Response interval exceeds the track record.');
assert(abs(stopTime/cfg.solver.output_step_s-round(stopTime/cfg.solver.output_step_s)) < 1e-9, ...
    'Response duration must be a multiple of output_step_s.');
tOut = (0:cfg.solver.output_step_s:stopTime)';
opts = odeset('RelTol',cfg.solver.rel_tol,'AbsTol',cfg.solver.abs_tol,'MaxStep',cfg.solver.max_step_s);
[t,Y] = ode45(@(tt,y)tixsRhs(tt,y,par,track),tOut,cfg.solver.initial_state(:),opts);

validate_solution(t,Y,tOut,'TIXS');

% Integrate the exact same track realization with the original linear
% secondary suspension, using the same solver tolerances for comparison.
Clinear = C2*(B*B.') + C1*(H1.'*H1);
Klinear = K2*(B*B.') + K1*(H1.'*H1);
[tLin,Ylin] = ode45(@(tt,y)linearRhs(tt,y,M0,Clinear, ...
    Klinear,H1,K1,C1,track),tOut,cfg.solver.initial_state(:),opts);
validate_solution(tLin,Ylin,tOut,'Linear baseline');
assert(isequal(t,tLin),'Linear and TIXS output grids differ.');

nOut = numel(t);
aBody = zeros(nOut,1);
aBodyLinear = zeros(nOut,1);
relFront = zeros(nOut,1);
relRear = zeros(nOut,1);
for j = 1:nOut
    [qdd,r] = tixsAcceleration(t(j),Y(j,1:4).',Y(j,5:8).', ...
        par,track);
    aBody(j) = qdd(1);
    relFront(j) = r(1);
    relRear(j) = r(2);
    dyLinear = linearRhs(t(j),Ylin(j,:).',M0,Clinear, ...
        Klinear,H1,K1,C1,track);
    aBodyLinear(j) = dyLinear(5);
end

% Continuous-time RMS estimated by trapezoidal integration on the uniform
% requested output grid, preserving the original trapezoidal definition.
rms10 = sqrt(trapz(t,aBody.^2)/(t(end)-t(1)));
rmsLinear10 = sqrt(trapz(t,aBodyLinear.^2)/(t(end)-t(1)));
% The synthesized track contains frequencies up to 80 Hz. Repeat the TIXS
% integration with a smaller maximum step to check the reported RMS.
fineOpts = odeset('RelTol',cfg.refinement.rel_tol,'AbsTol',cfg.refinement.abs_tol, ...
    'MaxStep',cfg.refinement.max_step_s);
[tFine,Yfine] = ode45(@(tt,y)tixsRhs(tt,y,par,track), ...
    tOut,cfg.solver.initial_state(:),fineOpts);
validate_solution(tFine,Yfine,tOut,'Refined TIXS');
aFine = zeros(numel(tFine),1);
for j = 1:numel(tFine)
    qddFine = tixsAcceleration(tFine(j),Yfine(j,1:4).', ...
        Yfine(j,5:8).',par,track);
    aFine(j) = qddFine(1);
end
rmsFine10 = sqrt(trapz(tFine,aFine.^2)/(tFine(end)-tFine(1)));
rmsConvergencePercent = 100*abs(rmsFine10-rms10)/rmsFine10;
assert(rmsConvergencePercent < cfg.refinement.rms_difference_limit_percent, ...
    'TIXS RMS failed the refined-step convergence check.');
frontRoad = interp1(track.t,track.xf,t,'linear');
rearRoad = interp1(track.t,track.xr,t,'linear');

% Check that neither branch approached the geometric endpoints.
sFront = l*sin(alpha)+relFront/2;
sRear = l*sin(alpha)+relRear/2;
minEndpointMarginM = min([sFront; sRear; l-sFront; l-sRear]);
assert(minEndpointMarginM > 0,'The solution crossed a TIXS geometric limit.');

assert(all(isfinite([aBody;aBodyLinear;aFine])),'Response acceleration contains NaN or Inf.');
frontRoadV = interp1(track.t,track.vf,t,'linear');
rearRoadV = interp1(track.t,track.vr,t,'linear');

result = struct('alpha_deg',alphaDeg,'rod_length_m',l, ...
    'inertance_per_branch_kg',b,'spring_stiffness_per_branch_N_m',K2, ...
    'damping_per_branch_Ns_m',C2, ...
    'static_load_per_branch_N',P(1), ...
    'spring_natural_length_m',wn(1), ...
    'tangent_stiffness_per_branch_N_m',Ktan(1), ...
    'equivalent_inertance_at_equilibrium_kg',mu0, ...
    'rms10_m_s2',rms10,'linear_rms10_m_s2',rmsLinear10, ...
    'refined_step_rms10_m_s2',rmsFine10, ...
    'rms_convergence_percent',rmsConvergencePercent, ...
    'rms_change_percent',100*(rms10/rmsLinear10-1), ...
    'min_geometric_endpoint_margin_m',minEndpointMarginM, ...
    'seed',track.seed,'f_min_hz',track.fMin, ...
    'f_max_hz',track.fMax,'spectrum_scale',track.spectrumScale, ...
    'rear_delay_s',track.tau);
result.duration_s = stopTime;
result.runtime_seconds = toc(runTimer);
result.effective_config = cfg;
if ~writeOutputs
    return
end
history = table(t,frontRoad,rearRoad,aBody,aBodyLinear,relFront,relRear, ...
    frontRoadV,rearRoadV,Y(:,1),Y(:,2),Y(:,3),Y(:,4),Y(:,5),Y(:,6),Y(:,7),Y(:,8), ...
    'VariableNames',{'time_s','front_track_m','rear_track_m', ...
    'tixs_body_vertical_acceleration_m_s2','linear_body_vertical_acceleration_m_s2', ...
    'front_tixs_relative_displacement_m','rear_tixs_relative_displacement_m', ...
    'front_track_velocity_m_s','rear_track_velocity_m_s', ...
    'body_heave_m','body_pitch_rad','front_bogie_heave_m','rear_bogie_heave_m', ...
    'body_heave_velocity_m_s','body_pitch_velocity_rad_s','front_bogie_velocity_m_s','rear_bogie_velocity_m_s'});
payload = struct('par',par,'track',track,'t',t,'Y',Y,'aBody',aBody, ...
    'tLin',tLin,'Ylin',Ylin,'aBodyLinear',aBodyLinear,'relFront',relFront,'relRear',relRear, ...
    'tFine',tFine,'Yfine',Yfine,'aFine',aFine);
result = export_suspension_run(projectRoot,cfg,result,payload,history, ...
    'TIXS Suspension/simulate_tixs_li2021.m',runId);
fprintf('TIXS acceleration RMS (0-%.6g s): %.9f m/s^2; refinement %.6g%%\n', ...
    stopTime,rms10,rmsConvergencePercent);
end

function dy = tixsRhs(tt,y,par,track)
[qdd,~] = tixsAcceleration(tt,y(1:4),y(5:8),par,track);
dy = [y(5:8);qdd];
end

function [qdd,r] = tixsAcceleration(tt,q,qd,par,track)
r = par.B.'*q;
rd = par.B.'*qd;
s = par.l*sin(par.alpha)+r/2;
D = par.l^2-s.^2;
if any(s <= 0 | s >= par.l | D <= 0)
    error('TIXS geometric range exceeded at t = %.8g s.',tt);
end
R = sqrt(D);
mu = par.b*s.^2./D;
mup = par.b*par.l^2*s./D.^2;
Vp = -par.K2*(2*R-par.wn).*s./R;
H = 0.5*mup.*rd.^2 + par.C2*rd + Vp-par.F0;
road = [interp1(track.t,track.xf,tt,'linear'); ...
        interp1(track.t,track.xr,tt,'linear')];
roadV = [interp1(track.t,track.vf,tt,'linear'); ...
         interp1(track.t,track.vr,tt,'linear')];
primary = par.K1*(q(3:4)-road)+par.C1*(qd(3:4)-roadV);
M = par.M0 + par.B*diag(mu)*par.B.';
qdd = M\(-par.B*H-par.H1.'*primary);
end

function dy = linearRhs(tt,y,M,C,K,H1,K1,C1,track)
road = [interp1(track.t,track.xf,tt,'linear'); ...
        interp1(track.t,track.xr,tt,'linear')];
roadV = [interp1(track.t,track.vf,tt,'linear'); ...
         interp1(track.t,track.vr,tt,'linear')];
q = y(1:4);
qd = y(5:8);
qdd = M\(H1.'*(K1*road+C1*roadV)-C*qd-K*q);
dy = [qd;qdd];
end
