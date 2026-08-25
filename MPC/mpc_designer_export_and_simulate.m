%% Simulate whatever "mpcobj" MPC Designer just exported (with rocket animation)
% Workflow:
%   1) Run mpc_designer_rocket_landing_demo.m -- it opens MPC Designer
%      with the rocket-landing controller (variable name "mpcobj").
%   2) In the app's Tune tab, drag the Weight/Estimation tuning sliders
%      (or edit weights/constraints directly) until you like the response.
%   3) Click the "Export" button in the Tune tab's Analysis section.
%      Because the app was launched as mpcDesigner(mpcobj), Export writes
%      the tuned controller straight back to the base workspace variable
%      "mpcobj" (MATLAB uses the input variable name as the controller's
%      label internally, so no dialog/renaming is needed).
%   4) Run *this* script. It picks up the current "mpcobj" from the base
%      workspace, closes the loop against the true rocket dynamics, and
%      produces the same plots/animation as mpc_rocket_landing_demo.m --
%      so you can see exactly how your slider tuning changed the landing.
%
% This script does not rebuild the controller itself, so it also works
% right after running mpc_rocket_landing_demo.m without ever opening the
% app, or with any other "mpcobj" you assign into the base workspace by
% hand.

if ~exist('mpcobj', 'var') || ~isa(mpcobj, 'mpc')
    error(['No MPC controller found in the base workspace. Run ' ...
        'mpc_designer_rocket_landing_demo.m first, tune it in the app, ' ...
        'and click Export (Tune tab > Analysis section) before running this script.']);
end

close all;

%% Recover the physical parameters this controller was designed for
% Prefer whatever this session already has (from mpc_designer_rocket_landing_demo.m
% or mpc_rocket_landing_demo.m); fall back to the standard demo values
% otherwise, so this script also works after a fresh "clear".
Ts = mpcobj.Ts;
accelGain = mpcobj.Model.Plant.B(2);          % Tmax/mass, from the prediction model
g = -mpcobj.Model.Nominal.DX(2);               % gravity, recovered from the nominal offset

if exist('x0', 'var') && numel(x0) == 2
    h0 = x0(1);
    v0 = x0(2);
elseif exist('h0', 'var') && exist('v0', 'var')
    x0 = [h0; v0];
else
    h0 = 500;
    v0 = -60;
    x0 = [h0; v0];
    fprintf('No initial condition found in the workspace; using the default x0 = [%.0f; %.0f].\n', h0, v0);
end

if ~exist('safeVelocity', 'var')
    safeVelocity = 5;
end
if ~exist('fuelRate', 'var')
    fuelRate = 8;
end

%% Reference trajectory: reuse it if present, otherwise regenerate it
if ~(exist('tRef', 'var') && exist('hRef', 'var') && exist('vRef', 'var'))
    T = -2 * h0 / v0;
    N = round(T / Ts);
    tRef = (0:N)' * Ts;
    vRef = v0 * (1 - tRef / T);
    hRef = h0 + v0 * tRef - v0 * tRef.^2 / (2 * T);
end
N = numel(tRef) - 1;

fprintf('Simulating the current "mpcobj" (PredictionHorizon=%d, ControlHorizon=%d)\n', ...
    mpcobj.PredictionHorizon, mpcobj.ControlHorizon);
fprintf('Weights: OutputVariables=%s, ManipulatedVariables=%.3g, ManipulatedVariablesRate=%.3g\n', ...
    mat2str(mpcobj.Weights.OutputVariables), mpcobj.Weights.ManipulatedVariables, ...
    mpcobj.Weights.ManipulatedVariablesRate);

%% Closed-loop simulation with exact state feedback (same as mpc_rocket_landing_demo.m)
xc = mpcstate(mpcobj);
xk = x0;
P = mpcobj.PredictionHorizon;

hist.t = zeros(N + 1, 1);
hist.h = zeros(N + 1, 1);
hist.v = zeros(N + 1, 1);
hist.u = zeros(N, 1);
hist.h(1) = xk(1);
hist.v(1) = xk(2);

kEnd = N + 1;
for k = 1:N
    xc.Plant = xk;
    rk = hRef(min(k + 1, N + 1):min(k + P, N + 1));
    rk = [rk, vRef(min(k + 1, N + 1):min(k + P, N + 1))];
    if isempty(rk)
        rk = [hRef(end), vRef(end)];
    end
    uk = mpcmove(mpcobj, xc, xk, rk);
    uk = min(max(uk, 0), 1);

    accel = accelGain * uk - g;
    xk = xk + Ts * [xk(2); accel];

    hist.u(k) = uk;
    hist.t(k + 1) = k * Ts;
    hist.h(k + 1) = xk(1);
    hist.v(k + 1) = xk(2);

    if xk(1) <= 0
        kEnd = k + 1;
        break;
    end
end

t = hist.t(1:kEnd);
hTraj = hist.h(1:kEnd);
vTraj = hist.v(1:kEnd);
uTraj = hist.u(1:kEnd - 1);

vFinal = vTraj(end);
outcome = "CRASH";
if hTraj(end) <= 0.01 && abs(vFinal) <= safeVelocity
    outcome = "SOFT LANDING";
end
fuelUsed = fuelRate * sum(uTraj) * Ts;

fprintf('\n--- Landing result (tuned controller) ---\n');
fprintf('Outcome: %s\n', outcome);
fprintf('Touchdown time: %.1f s\n', t(end));
fprintf('Touchdown velocity: %.2f m/s (safe if |v| <= %.1f)\n', vFinal, safeVelocity);
fprintf('Fuel used: %.1f%%\n', fuelUsed);

%% Plot the landing trajectory against the reference, and the throttle command
figure('Name', 'MPC Designer: Tuned Landing Trajectory');

subplot(3, 1, 1);
plot(tRef, hRef, 'k--', 'LineWidth', 1);
hold on;
plot(t, hTraj, 'b-', 'LineWidth', 1.5);
ylabel('Altitude h (m)');
title(sprintf('Tuned MPC landing -- %s (touchdown v = %.2f m/s)', outcome, vFinal));
legend('Reference', 'Actual', 'Location', 'northeast');
grid on;

subplot(3, 1, 2);
plot(tRef, vRef, 'k--', 'LineWidth', 1);
hold on;
plot(t, vTraj, 'r-', 'LineWidth', 1.5);
yline(-safeVelocity, 'k:', 'safe limit');
yline(safeVelocity, 'k:');
ylabel('Velocity v (m/s)');
grid on;

subplot(3, 1, 3);
stairs(t(1:end-1), uTraj, 'm-', 'LineWidth', 1.5);
ylim([-0.05, 1.05]);
xlabel('Time (s)');
ylabel('Throttle');
grid on;

%% Animate the descent and save it as a GIF
figure('Name', 'MPC Designer: Tuned Landing Animation');
axAnim = axes;
xlim(axAnim, [-1, 1]);
ylim(axAnim, [0, h0 * 1.05]);
ylabel(axAnim, 'Altitude (m)');
title(axAnim, sprintf('Tuned MPC landing animation -- %s', outcome));
hold(axAnim, 'on');
yline(axAnim, 0, 'k-', 'LineWidth', 3);
rocketMarker = plot(axAnim, 0, hTraj(1), 'v', 'MarkerSize', 16, ...
    'MarkerFaceColor', [0.2 0.4 0.85], 'MarkerEdgeColor', 'k');
flameMarker = plot(axAnim, 0, hTraj(1), '^', 'MarkerSize', 1, ...
    'MarkerFaceColor', [1 0.6 0], 'MarkerEdgeColor', 'none');

gifFile = fullfile(fileparts(mfilename('fullpath')), 'mpc_designer_tuned_landing_animation.gif');
animFig = ancestor(axAnim, 'figure');

for k = 1:numel(t)
    set(rocketMarker, 'YData', hTraj(k));
    thr = 0;
    if k <= numel(uTraj)
        thr = uTraj(k);
    end
    set(flameMarker, 'YData', max(hTraj(k) - 15 * thr, 0), 'MarkerSize', 1 + 20 * thr);
    drawnow;

    frame = getframe(animFig);
    [imgIdx, cmap] = rgb2ind(frame2im(frame), 256);
    if k == 1
        imwrite(imgIdx, cmap, gifFile, 'gif', 'LoopCount', Inf, 'DelayTime', 0.05);
    else
        imwrite(imgIdx, cmap, gifFile, 'gif', 'WriteMode', 'append', 'DelayTime', 0.05);
    end

    pause(0.02);
end
hold(axAnim, 'off');

fprintf('\nAnimation saved to: %s\n', gifFile);
