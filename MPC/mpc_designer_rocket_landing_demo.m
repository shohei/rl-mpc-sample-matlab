%% MPC Designer Demo: Reusable Rocket Landing (interactive GUI tuning)
% MPC Designer is a GUI app for designing, tuning, and simulating Model
% Predictive Controllers -- the low-code counterpart to the scripted
% workflow used in mpc_rocket_landing_demo.m (same 1D suicide-burn
% landing problem, same linear plant and mpc object, but here you can
% drag weight sliders and watch the closed-loop response update live,
% instead of editing mpcobj.Weights and re-running the script by hand).
%
% Unlike Reinforcement Learning Designer, mpcDesigner *does* accept a
% ready-made plant or mpc object as an input argument, so this script can
% hand the app a fully configured controller directly. The one thing it
% cannot do from the command line is set up the simulation scenario
% (initial condition, time-varying reference) -- that part is done in the
% app's Scenario editor. See README_mpc_designer_rocket_landing.md.

clear;
close all;

%% Physical parameters (matched to mpc_rocket_landing_demo.m for comparison)
g = 9.81;              % gravity, m/s^2
mass = 25000;           % rocket mass, kg
Tmax = 450000;           % max engine thrust, N
Ts = 0.1;                 % sample time, s
h0 = 500;                 % initial altitude, m
v0 = -60;                 % initial vertical velocity, m/s

%% Reference descent trajectory (same construction as mpc_rocket_landing_demo.m)
% A linear velocity ramp v0->0 whose integral also reaches h=0 at t=T.
T = -2 * h0 / v0;
N = round(T / Ts);
tRef = (0:N)' * Ts;
vRef = v0 * (1 - tRef / T);
hRef = h0 + v0 * tRef - v0 * tRef.^2 / (2 * T);

fprintf('Reference trajectory duration: %.1f s (%d steps)\n', T, N);
fprintf('Variables tRef, hRef, vRef, and x0 = [h0;v0] are in the base workspace\n');
fprintf('for use in the app''s Scenario editor (initial condition + reference signal).\n');

x0 = [h0; v0]; % kept in the workspace for the app's Scenario editor

%% Linear plant model: double integrator, throttle -> acceleration
A = [0 1; 0 0];
B = [0; Tmax / mass];
C = eye(2);
D = [0; 0];
plant = ss(A, B, C, D);
plant.OutputName = {'Altitude', 'Velocity'};
plant.InputName = {'Throttle'};

%% MPC controller (same design as mpc_rocket_landing_demo.m)
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

fprintf('\nOpening MPC Designer with the rocket-landing controller "mpcobj"...\n');
fprintf('In the app: open the Scenario editor, set the initial altitude/velocity\n');
fprintf('and import the reference signal, then use the weight sliders to tune live.\n');
fprintf('See README_mpc_designer_rocket_landing.md for the full walkthrough.\n');

mpcDesigner(mpcobj);
