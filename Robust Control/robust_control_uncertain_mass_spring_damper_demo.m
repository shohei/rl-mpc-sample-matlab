%% Robust Control Toolbox Demo: Why "Looks Stable" Isn't "Is Robust"
% Takes the same mass-spring-damper plant used in the System Identification
% demo (System Identification/system_identification_mass_spring_damper_demo.m)
% and asks a different question: even if you had a perfect nominal model,
% real hardware always has some unmodeled fast dynamics (actuator lag,
% neglected time delay, structural flexibility...). This demo represents
% that as bounded multiplicative uncertainty and compares two controllers:
%   - a "naive" PID tuned aggressively against the nominal model alone,
%     which looks excellent on paper (infinite gain margin, ~65 deg phase
%     margin) but is NOT robustly stable once the uncertainty is considered;
%   - a robust H-infinity mixed-sensitivity controller (mixsyn) shaped
%     against the same uncertainty bound, which is robustly stable with
%     margin to spare.
% robstab, wcgain, and a Monte Carlo sweep over sampled uncertain plants
% (usample) quantify the difference.

clear;
close all;
rng(0);

%% Step 1: Nominal plant (same mass-spring-damper as the System ID demo)
m = 1; c = 0.6; k = 4;
Gnom = tf(1, [m c k]);
fprintf('Nominal plant: 1 / (m*s^2 + c*s + k), m=%.2f, c=%.2f, k=%.2f\n', m, c, k);

%% Step 2: Model unmodeled fast dynamics as bounded multiplicative uncertainty
% Gunc = Gnom * (1 + Wunc(s)*Delta), with Delta any stable dynamic system
% of peak gain <= 1. Wunc is small at low frequency (the nominal model is
% trustworthy there) and grows past wc, meaning the plant's true behavior
% near and above wc is essentially unknown.
wc = 3; % rad/s - frequency above which the nominal model is not trusted
Wunc = tf([1/wc 0], [1/(8*wc) 1]);
Delta = ultidyn('Delta', [1 1]);
Gunc = Gnom * (1 + Wunc * Delta);

figure('Name', 'Uncertainty Weight and Sampled Plants');
subplot(2, 1, 1);
bodemag(Wunc);
title('Multiplicative uncertainty weight W_{unc}(s)');
grid on;
subplot(2, 1, 2);
bodemag(Gunc);
title('Nominal plant (bold) with sampled uncertain plants');
grid on;

%% Step 3: A "naive" controller tuned only against the nominal model
% Target a closed-loop bandwidth (6 rad/s) beyond wc, ignoring the fact
% that the model is not trustworthy up there.
Cnaive = pidtune(Gnom, 'PIDF', 6);
[gm, pm] = margin(Gnom * Cnaive);

fprintf('\n--- Naive controller (aggressive PID, ignores uncertainty) ---\n');
fprintf('Nominal gain margin: %s, phase margin: %.1f deg (looks great on paper)\n', ...
    mat2str(gm), pm);

CLu_naive = feedback(Gunc * Cnaive, 1);
smNaive = robstab(CLu_naive);
fprintf('Robust stability margin (robstab): %.2f (< 1 means NOT robustly stable)\n', smNaive.LowerBound);

%% Step 4: A robust controller, shaped against the same uncertainty bound
% Mixed-sensitivity H-infinity loop shaping (mixsyn): W1 demands good
% low-frequency performance (tracking/disturbance rejection), and Wunc
% (as the T-weight) forces the design to respect ||Wunc*T||_inf < 1,
% which is exactly the robust stability condition for this uncertainty.
W1 = makeweight(100, 1, 0.5);
[Crobust, ~, gamma] = mixsyn(Gnom, W1, [], Wunc);

fprintf('\n--- Robust controller (mixsyn H-infinity, shaped against Wunc) ---\n');
fprintf('mixsyn achieved closed-loop norm gamma = %.3f (<1 => robust stability guaranteed)\n', gamma);

CLu_robust = feedback(Gunc * Crobust, 1);
smRobust = robstab(CLu_robust);
fprintf('Robust stability margin (robstab): %.2f\n', smRobust.LowerBound);

%% Step 5: Worst-case closed-loop sensitivity gain
Su_naive = feedback(1, Gunc * Cnaive);
Su_robust = feedback(1, Gunc * Crobust);
wcgNaive = wcgain(Su_naive);
wcgRobust = wcgain(Su_robust);

fprintf('\n--- Comparison ---\n');
fprintf('%-28s %14s %14s\n', '', 'Naive PID', 'Robust (mixsyn)');
fprintf('%-28s %14.2f %14.2f\n', 'robstab margin (>1 = robust)', smNaive.LowerBound, smRobust.LowerBound);
fprintf('%-28s %14s %14.2f\n', 'Worst-case |S| gain (wcgain)', 'Inf', wcgRobust.LowerBound);
fprintf('(worst-case gain is Inf for the naive controller because it is not robustly stable at all)\n');

%% Step 6: Monte Carlo sweep over sampled uncertain plants
nSamples = 30;
Gsamples = usample(Gunc, nSamples);
tSim = 0:0.02:15;

unstableNaive = false(nSamples, 1);
unstableRobust = false(nSamples, 1);

figure('Name', 'Monte Carlo Step Response Comparison');
subplot(2, 1, 1);
hold on;
for i = 1:nSamples
    CLi = feedback(Gsamples(:, :, i) * Cnaive, 1);
    unstableNaive(i) = any(real(pole(CLi)) >= 0);
    plot(tSim, step(CLi, tSim), 'Color', [0.3 0.3 0.9 0.5]);
end
yline(1, 'k--');
ylim([-2 4]);
xlabel('Time (s)');
ylabel('Output');
title(sprintf('Naive PID: %d / %d sampled plants are unstable', sum(unstableNaive), nSamples));
grid on;
hold off;

subplot(2, 1, 2);
hold on;
for i = 1:nSamples
    CLi = feedback(Gsamples(:, :, i) * Crobust, 1);
    unstableRobust(i) = any(real(pole(CLi)) >= 0);
    plot(tSim, step(CLi, tSim), 'Color', [0.3 0.7 0.3 0.5]);
end
yline(1, 'k--');
ylim([-2 4]);
xlabel('Time (s)');
ylabel('Output');
title(sprintf('Robust (mixsyn): %d / %d sampled plants are unstable', sum(unstableRobust), nSamples));
grid on;
hold off;

fprintf('\n--- Monte Carlo check over %d sampled plants from the uncertainty set ---\n', nSamples);
fprintf('Naive PID:        %d / %d samples unstable\n', sum(unstableNaive), nSamples);
fprintf('Robust (mixsyn):  %d / %d samples unstable\n', sum(unstableRobust), nSamples);
