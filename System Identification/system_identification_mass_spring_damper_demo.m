%% System Identification Toolbox Demo: Modeling a Mass-Spring-Damper from Data
% The classic "hello world" of system identification: simulate a known
% second-order mechanical system (mass-spring-damper) driven by a random
% binary input, corrupt the measured output with noise, and estimate
% models directly from the input/output data - as if the physical
% parameters (mass, damping, stiffness) were unknown.
%
% Four model structures are estimated and validated on held-out data:
%   - tfest : continuous-time transfer function (2 poles, physically motivated)
%   - ssest : black-box continuous-time state-space model (order 2)
%   - arx   : discrete-time polynomial model with an "equation-error" noise model
%   - oe    : discrete-time polynomial model with an "output-error" noise model
%
% Because the simulated noise here is pure additive measurement noise
% (added after the true dynamics), the output-error-type estimators
% (tfest, ssest, oe) are expected to fit the validation data much better
% than arx, which assumes the noise enters through the same dynamics as
% the input. This illustrates why picking a model structure that matches
% the actual noise process matters, not just picking the right model order.

clear;
close all;
rng(0);

%% Step 1: Define the ground-truth system (normally unknown - here used to
%% generate synthetic data and to check the estimates against the truth)
m = 1;      % mass (kg)
c = 0.6;    % damping (N.s/m)
k = 4;      % stiffness (N/m)
Gc = tf(1, [m c k]);

Ts = 0.05;                  % sample time (s)
Gd = c2d(Gc, Ts, 'zoh');    % "true" plant as seen by a sampled-data system

[wnTrue, zetaTrue] = damp(Gc);
fprintf('True system: 1 / (m*s^2 + c*s + k), m=%.2f, c=%.2f, k=%.2f\n', m, c, k);
fprintf('  natural frequency = %.3f rad/s, damping ratio = %.3f\n', wnTrue(1), zetaTrue(1));

%% Step 2: Generate estimation and validation data
% A random binary input excites the system over a broad frequency range;
% independent noise realizations keep the estimation and validation sets
% statistically independent.
N = 800;
uEst = idinput(N);
uVal = idinput(N);

noiseStd = 0.01;
yEst = lsim(Gd, uEst) + noiseStd * randn(N, 1);
yVal = lsim(Gd, uVal) + noiseStd * randn(N, 1);

dataEst = iddata(yEst, uEst, Ts, 'Name', 'Estimation data');
dataVal = iddata(yVal, uVal, Ts, 'Name', 'Validation data');
dataEst.InputName = 'Force'; dataEst.OutputName = 'Position';
dataVal.InputName = 'Force'; dataVal.OutputName = 'Position';

figure('Name', 'Estimation Data');
plot(dataEst);
title('Input/output data used for estimation (random binary input + measurement noise)');

%% Step 3: Estimate models with different structures
sysTF = tfest(dataEst, 2, 0);     % 2 poles, 0 zeros, continuous time
sysSS = ssest(dataEst, 2);        % black-box state-space, order 2
sysARX = arx(dataEst, [2 2 1]);   % na=2, nb=2, nk=1 (equation-error noise model)
sysOE = oe(dataEst, [2 2 1]);     % nb=2, nf=2, nk=1 (output-error noise model)

models = {sysTF, sysSS, sysARX, sysOE};
modelNames = {'tfest (TF, 2 poles)', 'ssest (state-space, order 2)', ...
              'arx([2 2 1])', 'oe([2 2 1])'};

%% Step 4: Validate every model on the held-out data
[ymod, fitCell] = compare(dataVal, sysTF, sysSS, sysARX, sysOE);
fitPct = cellfun(@(f) f, fitCell);

fprintf('\n--- Validation fit (NRMSE %%, higher is better) ---\n');
for i = 1:numel(modelNames)
    fprintf('%-32s %6.1f%%\n', modelNames{i}, fitPct(i));
end

figure('Name', 'Validation Fit Comparison');
bar(fitPct);
set(gca, 'XTickLabel', modelNames);
xtickangle(20);
ylabel('Fit to validation data (%)');
title('Model structure comparison on held-out validation data');
grid on;

%% Step 5: Time-domain comparison of measured vs. simulated output
figure('Name', 'Measured vs. Simulated Output');
t = dataVal.SamplingInstants;
hold on;
plot(t, dataVal.OutputData, 'k.', 'DisplayName', 'Measured (validation)');
colors = lines(numel(models));
for i = 1:numel(models)
    plot(t, ymod{i}.OutputData, 'LineWidth', 1.5, 'Color', colors(i, :), ...
        'DisplayName', sprintf('%s (%.1f%%)', modelNames{i}, fitPct(i)));
end
xlabel('Time (s)');
ylabel('Position');
title('Estimated models vs. measured validation data');
legend('Location', 'best');
grid on;
hold off;

%% Step 6: Compare identified continuous-time dynamics to the (usually unknown) truth
[wnTF, zetaTF] = damp(sysTF);
[wnSS, zetaSS] = damp(sysSS);

fprintf('\n--- Identified vs. true natural frequency / damping ratio ---\n');
fprintf('%-24s %10s %10s\n', '', 'wn (rad/s)', 'zeta');
fprintf('%-24s %10.3f %10.3f\n', 'True system', wnTrue(1), zetaTrue(1));
fprintf('%-24s %10.3f %10.3f\n', 'tfest estimate', wnTF(1), zetaTF(1));
fprintf('%-24s %10.3f %10.3f\n', 'ssest estimate', wnSS(1), zetaSS(1));

figure('Name', 'Bode Comparison');
bode(Gc, 'k--', sysTF, 'b-', sysSS, 'r-.');
legend('True system', 'tfest', 'ssest');
grid on;
