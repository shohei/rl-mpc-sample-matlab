%% Reinforcement Learning Toolbox Demo: PPO on the Cart-Pole (continuous action)
% Extends the neural-network DQN sample (dqn_cartpole_demo.m) to a
% continuous force action using Proximal Policy Optimization (PPO) - an
% on-policy actor-critic method, as opposed to DQN's off-policy
% value-based learning. Same physical system (Cart-Pole), same
% Deep Learning Toolbox-based networks under the hood, different learning
% algorithm and action space:
%   - DQN:  discrete action (-10 N or +10 N), off-policy, replay buffer
%   - PPO:  continuous action (any force in [-10, 10] N), on-policy,
%           clipped surrogate objective, actor (policy) + critic (value)
%
% PPO is more sensitive to its batch-size-related hyperparameters than
% DQN is: the demo first trains with the toolbox's default PPO options
% (which does not solve Cart-Pole in a modest episode budget here), then
% retrains with a larger experience horizon/minibatch, more epochs per
% update, and higher entropy weight - and compares the two runs directly.

clear;
close all;
rng(0);

%% Step 1: Create the environment (continuous force action)
% Observation: [x, dx, theta, dtheta] (continuous, unbounded)
% Action: apply a continuous force in [-10, 10] N to the cart
env = rlPredefinedEnv("CartPole-Continuous");

obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

fprintf('Observation: %s (%s)\n', obsInfo.Name, obsInfo.Description);
fprintf('Action: %s, range = [%g, %g] N (continuous)\n\n', actInfo.Name, actInfo.LowerLimit, actInfo.UpperLimit);

trainOptsTemplate = rlTrainingOptions(...
    MaxStepsPerEpisode = 200, ...
    StopTrainingCriteria = "AverageReward", ...
    StopTrainingValue = 195, ...
    ScoreAveragingWindowLength = 20, ...
    Plots = "training-progress", ...
    Verbose = false);

%% Step 2: Train with the toolbox's default PPO hyperparameters
fprintf('=== Training PPO agent (default hyperparameters) ===\n');
defaultAgent = rlPPOAgent(obsInfo, actInfo);

fprintf('--- Default actor network ---\n');
disp(getModel(getActor(defaultAgent)).Layers);

defaultTrainOpts = trainOptsTemplate;
defaultTrainOpts.MaxEpisodes = 300;
defaultStats = train(defaultAgent, env, defaultTrainOpts);

%% Step 3: Train with tuned PPO hyperparameters
% A larger experience horizon and minibatch give PPO more (and more
% stable) data per policy update; more epochs per update extract more
% learning signal from each batch of experience; a higher entropy weight
% keeps exploring for longer before committing to a policy.
fprintf('\n=== Training PPO agent (tuned hyperparameters) ===\n');
tunedAgent = rlPPOAgent(obsInfo, actInfo);
tunedOpts = tunedAgent.AgentOptions;
tunedOpts.ExperienceHorizon = 1024;
tunedOpts.MiniBatchSize = 256;
tunedOpts.NumEpoch = 5;
tunedOpts.EntropyLossWeight = 0.02;
tunedOpts.ActorOptimizerOptions.LearnRate = 1e-3;
tunedOpts.CriticOptimizerOptions.LearnRate = 1e-3;
tunedAgent.AgentOptions = tunedOpts;

tunedTrainOpts = trainOptsTemplate;
tunedTrainOpts.MaxEpisodes = 500;
tunedStats = train(tunedAgent, env, tunedTrainOpts);

%% Step 4: Compare the two training runs
defaultFinalAvg = lastNAverage(defaultStats.EpisodeReward, 10);
tunedFinalAvg = lastNAverage(tunedStats.EpisodeReward, 10);

fprintf('\n--- Comparison ---\n');
fprintf('%-28s %12s %12s\n', '', 'Default', 'Tuned');
fprintf('%-28s %12d %12d\n', 'Episodes run', numel(defaultStats.EpisodeReward), numel(tunedStats.EpisodeReward));
fprintf('%-28s %12.1f %12.1f\n', 'Avg reward (last 10 ep.)', defaultFinalAvg, tunedFinalAvg);
fprintf('%-28s %12.1f %12.1f\n', 'Best episode reward', max(defaultStats.EpisodeReward), max(tunedStats.EpisodeReward));

figure('Name', 'Default vs. Tuned PPO Training Progress');
hold on;
plot(defaultStats.AverageReward, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Default PPO hyperparameters');
plot(tunedStats.AverageReward, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Tuned PPO hyperparameters');
yline(trainOptsTemplate.StopTrainingValue, 'k--', 'DisplayName', 'Target average reward');
xlabel('Episode');
ylabel('Average reward (window = 20)');
title('PPO on Cart-Pole (continuous action): default vs. tuned hyperparameters');
legend('Location', 'southeast');
grid on;
hold off;

%% Step 5: Simulate the tuned policy, animating the cart-pole live
plot(env); % opens a live cart-pole view that updates during sim()
simOpts = rlSimulationOptions(MaxSteps = 200);
experience = sim(env, tunedAgent, simOpts);

rewardData = experience.Reward.Data;
totalReward = sum(rewardData);
numSteps = numel(rewardData);
fprintf('\n--- Evaluation run (tuned PPO agent) ---\n');
fprintf('Steps balanced before termination (or cap): %d\n', numSteps);
fprintf('Total reward: %.1f\n', totalReward);

%% Step 6: Plot the state and action trajectory
states = squeeze(experience.Observation.CartPoleStates.Data); % 4 x N
actions = squeeze(experience.Action.CartPoleAction.Data);
t = experience.Observation.CartPoleStates.Time;

figure('Name', 'PPO Cart-Pole State and Action Trajectory');

subplot(3, 1, 1);
plot(t, states(1, :), 'b-', 'LineWidth', 1.5);
ylabel('Cart position x (m)');
title('Learned PPO policy: cart-pole state and action trajectory');
grid on;

subplot(3, 1, 2);
plot(t, rad2deg(states(3, :)), 'r-', 'LineWidth', 1.5);
yline(0, 'k:');
ylabel('Pole angle \theta (deg)');
grid on;

subplot(3, 1, 3);
stairs(t(1:numel(actions)), actions, 'm-', 'LineWidth', 1.2);
xlabel('Time step');
ylabel('Force (N)');
grid on;

%% Local functions

function avg = lastNAverage(rewards, n)
    n = min(n, numel(rewards));
    avg = mean(rewards(end - n + 1:end));
end
