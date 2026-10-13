function track = make_li2021_track(settings,supportDistance)
% Shared random-phase realization for IBXS, TIXS and its linear comparison.
v = settings.speed_km_h/3.6;
Av = settings.Av;
OmegaR = settings.OmegaR;
OmegaC = settings.OmegaC;
seed = settings.seed;
recordSeconds = settings.record_seconds;
N = settings.sample_count;
fMin = settings.f_min_hz;
fMax = settings.f_max_hz;
spectrumScale = settings.amplitude_scale;
assert(v > 0 && recordSeconds > 0 && N >= 4 && mod(N,2) == 0 && N == fix(N), ...
    'Invalid track speed, duration or even FFT length.');
assert(Av > 0 && OmegaR > 0 && OmegaC > 0 && spectrumScale > 0 && ...
    fMin > 0 && fMax > fMin && fMax < N/(2*recordSeconds),'Invalid spectrum settings.');
assert(seed >= 0 && seed == fix(seed) && strcmp(settings.rng_algorithm,'twister'), ...
    'The benchmark requires an explicit nonnegative integer twister seed.');
dt = recordSeconds/N;
tTrack = (0:N-1)'*dt;
df = 1/recordSeconds;
f = (0:N/2)'*df;
Omega = 2*pi*f/v;
Sv = Av*OmegaC^2./((Omega.^2+OmegaR^2).*(Omega.^2+OmegaC^2));
St = (2*pi/v)*Sv;
St(f < fMin | f > fMax) = 0;
previousRng = rng;
restoreRng = onCleanup(@()rng(previousRng)); %#ok<NASGU>
rng(seed,'twister');
phase = 2*pi*rand(N/2-1,1);
amplitude = spectrumScale*sqrt(2*St(2:N/2)*df);
X = complex(zeros(N,1));
X(2:N/2) = (N/2)*amplitude.*exp(1i*phase);
X(N/2+2:N) = conj(X(N/2:-1:2));
xFront = real(ifft(X));
tau = 2*supportDistance/v;
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
track = struct('t',tTrack,'front',xFront,'rear',xRear, ...
    'vFront',vFront,'vRear',vRear,'seed',seed,'fMin',fMin, ...
    'fMax',fMax,'spectrumScale',spectrumScale,'tau',tau);
% Retain the field aliases used in the unchanged TIXS acceleration routine.
track.xf = xFront; track.xr = xRear;
track.vf = vFront; track.vr = vRear;
assert(all(isfinite([xFront;xRear;vFront;vRear])),'Track realization is not finite.');
end
