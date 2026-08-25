%% Model Predictive Control Toolbox Demo: Reusable Rocket Landing (1D)
% The same simplified, Falcon-9-style "suicide burn" landing problem as
% rocket_landing_demo.m (Reinforcement Learning Toolbox), but solved with
% classical Model Predictive Control instead of trial-and-error learning.
%
% Unlike the RL version, MPC uses the known physics model directly, so
% there is no reward shaping, no training, and no run-to-run variability:
% the controller lands correctly on every run.
%
% Approach: a smooth, dynamically-feasible reference descent trajectory
% (a linear velocity ramp from v0 to 0 that reaches h=0 at the same
% instant) is computed analytically, and a linear MPC controller tracks
% it in closed loop, respecting the throttle bound 0 <= u <= 1.

clear;
close all;

%% Physical parameters (matched to rocket_landing_demo.m for comparison)
g = 9.81;              % gravity, m/s^2
mass = 25000;           % rocket mass, kg
Tmax = 450000;          % max engine thrust, N
Ts = 0.1;                % sample time, s
fuelRate = 8;             % fuel units/s at full throttle (for reporting only)
h0 = 500;                 % initial altitude, m
v0 = -60;                 % initial vertical velocity, m/s
safeVelocity = 5;         % m/s -- landing is "soft" if |v| <= this at touchdown

%% Design a dynamically-feasible reference descent trajectory
% A linear velocity ramp v_ref(t) = v0*(1 - t/T) integrates to an
% altitude profile that reaches exactly h=0 at t=T when T = -2*h0/v0.
% This guarantees the reference itself is a valid, gentle landing -- MPC
% only has to track it, not discover a landing strategy from scratch.
T = -2 * h0 / v0;
N = round(T / Ts);
tRef = (0:N)' * Ts;
vRef = v0 * (1 - tRef / T);
hRef = h0 + v0 * tRef - v0 * tRef.^2 / (2 * T);
reqAccel = -v0 / T;
reqThrottle = (reqAccel + g) * mass / Tmax;

fprintf('Reference trajectory duration: %.1f s (%d steps)\n', T, N);
fprintf('Required (constant) throttle to follow it exactly: %.3f\n', reqThrottle);

%% Linear plant model: double integrator, throttle -> acceleration
% dh/dt = v
% dv/dt = (Tmax/mass)*u - g   (affine offset handled via Model.Nominal.DX)
A = [0 1; 0 0];
B = [0; Tmax / mass];
C = eye(2);
D = [0; 0];
plant = ss(A, B, C, D);

%% MPC controller
PredictionHorizon = 20;
ControlHorizon = 5;
mpcobj = mpc(plant, Ts, PredictionHorizon, ControlHorizon);
mpcobj.MV = struct('Min', 0, 'Max', 1);
mpcobj.OV(1).ScaleFactor = h0;
mpcobj.OV(2).ScaleFactor = abs(v0);
mpcobj.Model.Nominal = struct('X', [0; 0], 'U', 0, 'Y', [0; 0], 'DX', [0; -g]);
mpcobj.Weights.OutputVariables = [1 1];
mpcobj.Weights.ManipulatedVariables = 0;
mpcobj.Weights.ManipulatedVariablesRate = 0.05;

%% Closed-loop simulation with exact state feedback
% mpcstate.Plant is set directly from the true state each step, bypassing
% the built-in Kalman disturbance estimator (its default integrating
% output-disturbance model otherwise introduces a noticeable tracking lag
% for this deterministic, fully-observed problem).
xc = mpcstate(mpcobj);
xk = [h0; v0];

hist.t = zeros(N + 1, 1);
hist.h = zeros(N + 1, 1);
hist.v = zeros(N + 1, 1);
hist.u = zeros(N, 1);
hist.h(1) = xk(1);
hist.v(1) = xk(2);

kEnd = N + 1;
for k = 1:N
    xc.Plant = xk;
    rk = hRef(min(k + 1, N + 1):min(k + PredictionHorizon, N + 1));
    rk = [rk, vRef(min(k + 1, N + 1):min(k + PredictionHorizon, N + 1))];
    if isempty(rk)
        rk = [hRef(end), vRef(end)];
    end
    uk = mpcmove(mpcobj, xc, xk, rk);
    uk = min(max(uk, 0), 1);

    accel = (Tmax / mass) * uk - g;
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
if abs(vFinal) <= safeVelocity
    outcome = "SOFT LANDING";
end
fuelUsed = fuelRate * sum(uTraj) * Ts;

fprintf('\n--- Landing result ---\n');
fprintf('Outcome: %s\n', outcome);
fprintf('Touchdown time: %.1f s\n', t(end));
fprintf('Touchdown velocity: %.2f m/s (safe if |v| <= %.1f)\n', vFinal, safeVelocity);
fprintf('Fuel used (for comparison with the RL demo''s units): %.1f%%\n', fuelUsed);

%% Plot the landing trajectory against the reference, and the throttle command
figure('Name', 'MPC Rocket Landing Trajectory');

subplot(3, 1, 1);
plot(tRef, hRef, 'k--', 'LineWidth', 1);
hold on;
plot(t, hTraj, 'b-', 'LineWidth', 1.5);
ylabel('Altitude h (m)');
title(sprintf('MPC-tracked landing -- %s (touchdown v = %.2f m/s)', outcome, vFinal));
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

%% Animate the descent and save it as a GIF (same style as the RL demo)
figure('Name', 'MPC Rocket Landing Animation');
axAnim = axes;
xlim(axAnim, [-1, 1]);
ylim(axAnim, [0, h0 * 1.05]);
ylabel(axAnim, 'Altitude (m)');
title(axAnim, sprintf('MPC rocket landing animation -- %s', outcome));
hold(axAnim, 'on');
yline(axAnim, 0, 'k-', 'LineWidth', 3);
rocketMarker = plot(axAnim, 0, hTraj(1), 'v', 'MarkerSize', 16, ...
    'MarkerFaceColor', [0.2 0.4 0.85], 'MarkerEdgeColor', 'k');
flameMarker = plot(axAnim, 0, hTraj(1), '^', 'MarkerSize', 1, ...
    'MarkerFaceColor', [1 0.6 0], 'MarkerEdgeColor', 'none');

gifFile = fullfile(fileparts(mfilename('fullpath')), 'mpc_rocket_landing_animation.gif');
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
