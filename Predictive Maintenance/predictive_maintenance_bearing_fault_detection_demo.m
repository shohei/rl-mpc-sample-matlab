%% Predictive Maintenance Toolbox Demo: Bearing Fault Detection via Envelope Spectrum
% A classic vibration-based fault diagnosis workflow: a rolling-element
% bearing with a localized outer-race defect produces a train of impacts
% at its characteristic fault frequency (BPFO) that excite a structural
% resonance. That impact train is normally buried in broadband vibration
% noise in the raw time signal, but shows up as a sharp peak at BPFO in
% the envelope spectrum of the resonance band. The demo:
%   1. computes the bearing's characteristic fault frequency bands from
%      its physical geometry (bearingFaultBands),
%   2. compares the envelope spectrum and fault-band power of a healthy
%      vs. a faulty (outer-race defect) simulated vibration signal,
%      confirming the anomaly is specific to the outer-race band and not
%      a generic broadband change,
%   3. calibrates a detection threshold from healthy-only data and
%      validates it: false-alarm rate on fresh healthy signals, and
%      detection rate across a sweep of fault severities.

clear;
close all;
rng(0);

%% Step 1: Bearing geometry and characteristic fault frequency bands
FR = 25;    % shaft rotational speed (Hz) = 1500 rpm
NB = 9;     % number of rolling elements
DB = 0.31;  % roller/ball diameter
DP = 1.25;  % pitch diameter
beta = 0;   % contact angle (deep-groove ball bearing, no thrust load)

[FB, info] = bearingFaultBands(FR, NB, DB, DP, beta);

fprintf('Characteristic fault frequencies (shaft speed = %d Hz):\n', FR);
for i = 1:numel(info.Labels)
    fprintf('  %-6s %7.2f Hz  (band %.2f - %.2f Hz)\n', info.Labels{i}, info.Centers(i), FB(i, 1), FB(i, 2));
end
fprintf('(1Fo = outer race, 1Fi = inner race, 1Fb = ball/roller, 1Fc = cage)\n');

%% Step 2: Simulate healthy vs. faulty (outer-race defect) vibration signals
fs = 20000;         % sample rate (Hz)
duration = 1;        % seconds
t = (0:1/fs:duration - 1/fs)';
N = numel(t);

healthyAmp = 0.05;      % 1x shaft-rotation vibration amplitude
noiseStd = 0.3;         % broadband measurement/mounting noise
resonanceFreq = 3000;   % structural resonance excited by each impact (Hz)
decayRate = 800;        % decay rate of each impact's resonance ring-down
bpfo = info.Centers(1); % outer-race fault frequency
impulsePeriod = 1 / bpfo;
envBand = [2000 4000];  % frequency band around the excited resonance

healthySignal = simulateBearingVibration(t, FR, healthyAmp, noiseStd, 0, ...
    impulsePeriod, decayRate, resonanceFreq);
faultySignal = simulateBearingVibration(t, FR, healthyAmp, noiseStd, 1.0, ...
    impulsePeriod, decayRate, resonanceFreq);

figure('Name', 'Raw Vibration Signals');
tZoom = t <= 0.1;
subplot(2, 1, 1);
plot(t(tZoom), healthySignal(tZoom));
title('Healthy bearing (time domain)');
ylabel('Acceleration (g)');
grid on;
subplot(2, 1, 2);
plot(t(tZoom), faultySignal(tZoom));
title('Faulty bearing, outer-race defect (time domain) - the fault is not obvious by eye');
xlabel('Time (s)');
ylabel('Acceleration (g)');
grid on;

%% Step 3: Envelope spectrum and fault-band power - is the anomaly fault-specific?
[esHealthy, fEnv] = envspectrum(healthySignal, fs, 'Band', envBand);
[esFaulty, ~] = envspectrum(faultySignal, fs, 'Band', envBand);

figure('Name', 'Envelope Spectrum');
plot(fEnv, esHealthy, 'b-', 'DisplayName', 'Healthy');
hold on;
plot(fEnv, esFaulty, 'r-', 'DisplayName', 'Faulty (outer-race defect)');
for i = 1:numel(info.Labels)
    xline(info.Centers(i), 'k:', info.Labels{i});
end
xlim([0 300]);
xlabel('Frequency (Hz)');
ylabel('Envelope spectrum amplitude');
title('Envelope spectrum: the outer-race fault shows up as a peak at BPFO');
legend('Location', 'best');
grid on;
hold off;

metricsHealthy = faultBandMetrics(esHealthy, fEnv, FB);
metricsFaulty = faultBandMetrics(esFaulty, fEnv, FB);

fprintf('\n--- Fault-band power: healthy vs. faulty (which band lights up?) ---\n');
fprintf('%-8s %14s %14s %10s\n', 'Band', 'Healthy power', 'Faulty power', 'Ratio');
bandPowerVars = {'BandPower1', 'BandPower2', 'BandPower3', 'BandPower4'};
for i = 1:numel(bandPowerVars)
    pH = metricsHealthy.(bandPowerVars{i});
    pF = metricsFaulty.(bandPowerVars{i});
    fprintf('%-8s %14.4f %14.4f %9.1fx\n', info.Labels{i}, pH, pF, pF / pH);
end
fprintf('=> Only the outer-race band (1Fo = BPFO) grows sharply; the fault is correctly localized.\n');

%% Step 4: Calibrate a detection threshold from healthy-only data
nCal = 20;
bpfoPowerCal = zeros(nCal, 1);
for i = 1:nCal
    hs = simulateBearingVibration(t, FR, healthyAmp, noiseStd, 0, impulsePeriod, decayRate, resonanceFreq);
    [es, f] = envspectrum(hs, fs, 'Band', envBand);
    m = faultBandMetrics(es, f, FB);
    bpfoPowerCal(i) = m.BandPower1;
end
muHealthy = mean(bpfoPowerCal);
sigmaHealthy = std(bpfoPowerCal);
threshold = muHealthy + 4 * sigmaHealthy;

fprintf('\n--- Detection threshold (calibrated on %d healthy-only signals) ---\n', nCal);
fprintf('BPFO band power: mean = %.4f, std = %.4f -> threshold = %.4f\n', muHealthy, sigmaHealthy, threshold);

%% Step 5: Validate - false-alarm rate and detection rate vs. fault severity
nTrialsFA = 20;
falseAlarms = false(nTrialsFA, 1);
for i = 1:nTrialsFA
    hs = simulateBearingVibration(t, FR, healthyAmp, noiseStd, 0, impulsePeriod, decayRate, resonanceFreq);
    [es, f] = envspectrum(hs, fs, 'Band', envBand);
    m = faultBandMetrics(es, f, FB);
    falseAlarms(i) = m.BandPower1 > threshold;
end
fprintf('\nFalse-alarm rate on %d fresh healthy signals: %.0f%% (%d of %d)\n', ...
    nTrialsFA, 100 * mean(falseAlarms), sum(falseAlarms), nTrialsFA);

severities = [0 0.1 0.2 0.3 0.5 0.8 1.2];
nTrialsPerSeverity = 15;
detectionRate = zeros(size(severities));
for s = 1:numel(severities)
    detected = false(nTrialsPerSeverity, 1);
    for i = 1:nTrialsPerSeverity
        vib = simulateBearingVibration(t, FR, healthyAmp, noiseStd, severities(s), ...
            impulsePeriod, decayRate, resonanceFreq);
        [es, f] = envspectrum(vib, fs, 'Band', envBand);
        m = faultBandMetrics(es, f, FB);
        detected(i) = m.BandPower1 > threshold;
    end
    detectionRate(s) = mean(detected);
end

fprintf('\n--- Detection rate vs. fault severity (%d trials each) ---\n', nTrialsPerSeverity);
fprintf('%10s %14s\n', 'Severity', 'Detection rate');
for s = 1:numel(severities)
    fprintf('%10.2f %13.0f%%\n', severities(s), 100 * detectionRate(s));
end

figure('Name', 'Detection Rate vs. Fault Severity');
plot(severities, 100 * detectionRate, 'b-o', 'LineWidth', 1.5);
xlabel('Fault severity (impact amplitude, arbitrary units)');
ylabel('Detection rate (%)');
title('Outer-race fault detection rate rises sharply once impacts clear the noise floor');
ylim([-5 105]);
grid on;

%% Local functions

function vib = simulateBearingVibration(t, FR, healthyAmp, noiseStd, severity, impulsePeriod, decayRate, resonanceFreq)
% Simulate a bearing vibration signal: shaft-rotation harmonic + broadband
% noise, plus (if severity > 0) a periodic train of exponentially-decaying
% resonance impacts at the outer-race fault frequency, with slight timing
% jitter to mimic real-world slip between the rollers and the races.
    N = numel(t);
    duration = t(end) + t(2) - t(1);
    vib = healthyAmp * sin(2*pi*FR*t + 2*pi*rand) + noiseStd * randn(N, 1);

    if severity > 0
        impulseTimes = 0:impulsePeriod:duration;
        impulseTimes = impulseTimes + 0.02 * impulsePeriod * randn(size(impulseTimes));
        for ti = impulseTimes
            tau = t - ti;
            mask = tau >= 0;
            vib(mask) = vib(mask) + severity * exp(-decayRate * tau(mask)) .* sin(2*pi*resonanceFreq*tau(mask));
        end
    end
end
