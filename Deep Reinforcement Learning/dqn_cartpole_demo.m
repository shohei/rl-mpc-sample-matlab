%% Reinforcement Learning Toolbox Demo: DQN on the Cart-Pole (continuous states)
% Extends the tabular Q-learning grid-world sample (rl_gridworld_demo.m)
% to a continuous 4-dimensional state space using a Deep Q-Network (DQN)
% agent with a neural-network critic, on the built-in Cart-Pole
% environment with a discrete action space (push cart left/right).

clear;
close all;
rng(0);

%% Create the environment
% Observation: [x, dx, theta, dtheta] (continuous, unbounded)
% Action: apply a force of -10 or +10 N to the cart (discrete)
env = rlPredefinedEnv("CartPole-Discrete");

obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

fprintf('Observation: %s (%s)\n', obsInfo.Name, obsInfo.Description);
fprintf('Action: %s, values = %s\n', actInfo.Name, mat2str(actInfo.Elements));

%% Create the DQN agent
% rlDQNAgent(obsInfo, actInfo) builds a default fully-connected critic
% network sized from the observation/action dimensions.
agent = rlDQNAgent(obsInfo, actInfo);

fprintf('\n--- Default critic network ---\n');
disp(getModel(getCritic(agent)).Layers);

%% Train the agent
% "training-progress" opens a live window plotting episode reward and
% the moving-average reward as training proceeds (same as the grid-world
% sample). A 200-step cap matches the classic CartPole "solved" criterion
% of an average reward >= 195 over a trailing window of episodes.
trainOpts = rlTrainingOptions(...
    MaxEpisodes = 150, ...
    MaxStepsPerEpisode = 200, ...
    StopTrainingCriteria = "AverageReward", ...
    StopTrainingValue = 195, ...
    ScoreAveragingWindowLength = 20, ...
    Plots = "training-progress", ...
    Verbose = false);

trainStats = train(agent, env, trainOpts);

fprintf('\n--- Training complete ---\n');
fprintf('Episodes run: %d\n', numel(trainStats.EpisodeReward));
fprintf('Average reward (last 10 episodes): %.1f\n', mean(trainStats.EpisodeReward(end-9:end)));
fprintf('Best single-episode reward: %.1f\n', max(trainStats.EpisodeReward));

%% Redraw the training curve as a standalone, savable figure
figure('Name', 'Training Progress');
plot(trainStats.EpisodeReward, 'Color', [0.7 0.7 0.9]);
hold on;
plot(trainStats.AverageReward, 'b-', 'LineWidth', 2);
yline(trainOpts.StopTrainingValue, 'r--', 'Target average reward');
xlabel('Episode');
ylabel('Reward (steps balanced)');
title('DQN training progress on Cart-Pole');
legend('Episode reward', 'Average reward (window = 20)', 'Location', 'southeast');
grid on;
hold off;

%% Simulate the trained policy, animating the cart-pole live
plot(env);   % opens a live cart-pole view that updates during sim()
simOpts = rlSimulationOptions(MaxSteps = 200);
experience = sim(env, agent, simOpts);

rewardData = experience.Reward.Data;
totalReward = sum(rewardData);
numSteps = numel(rewardData);
fprintf('\n--- Evaluation run ---\n');
fprintf('Steps balanced before termination (or cap): %d\n', numSteps);
fprintf('Total reward: %.1f\n', totalReward);

%% Plot the state trajectory (cart position and pole angle over time)
states = squeeze(experience.Observation.CartPoleStates.Data); % 4 x N
t = experience.Observation.CartPoleStates.Time;

figure('Name', 'Cart-Pole State Trajectory');

subplot(2, 1, 1);
plot(t, states(1, :), 'b-', 'LineWidth', 1.5);
ylabel('Cart position x (m)');
title('Learned policy: cart-pole state trajectory');
grid on;

subplot(2, 1, 2);
plot(t, rad2deg(states(3, :)), 'r-', 'LineWidth', 1.5);
yline(0, 'k:');
xlabel('Time step');
ylabel('Pole angle \theta (deg)');
grid on;
