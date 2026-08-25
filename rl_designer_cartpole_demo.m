%% Reinforcement Learning Designer Demo: Cart-Pole (no-code workflow)
% Reinforcement Learning Designer is a GUI app for building, training,
% and simulating RL agents without writing training code -- it is the
% low-code counterpart to the scripted workflow used in
% dqn_cartpole_demo.m (same Cart-Pole problem, same DQN agent type, but
% configured and trained by clicking through the app instead of calling
% rlDQNAgent/train directly).
%
% A GUI app cannot be driven end-to-end from a script, so this file does
% the one thing that *can* be scripted reliably: create the environment
% in the base workspace (so the app's Import dialog can find it) and
% launch the app. See README_rl_designer_cartpole.md for the click-through
% steps to import the environment, create an agent, train it, and
% simulate the result inside the app.

clear;
close all;

env = rlPredefinedEnv("CartPole-Discrete");
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

fprintf('Environment "env" created in the base workspace: %s\n', class(env));
fprintf('Observation: %s (%s)\n', obsInfo.Name, obsInfo.Description);
fprintf('Action: %s, values = %s\n', actInfo.Name, mat2str(actInfo.Elements));

fprintf('\nOpening Reinforcement Learning Designer...\n');
fprintf('In the app: Environments > New > Import from workspace > select "env",\n');
fprintf('then Agents > New to create and train a DQN agent.\n');
fprintf('See README_rl_designer_cartpole.md for the full step-by-step walkthrough.\n');

reinforcementLearningDesigner;
