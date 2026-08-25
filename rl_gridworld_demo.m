%% Reinforcement Learning Toolbox Demo: Q-learning on a 5x5 Grid World
% A simple agent learns to navigate from the start cell [2,1] to the
% terminal cell [5,5] while avoiding an obstacle, using tabular
% Q-learning (rlQAgent).

rng(0);

%% Create the grid world
GW = createGridWorld(5, 5);
GW.CurrentState = "[2,1]";
GW.TerminalStates = "[5,5]";
GW.ObstacleStates = "[3,3]";

% Standard move rewards: -1 per step, +10 for reaching the goal
GW.R(:, :, :) = -1;
GW.R(state2idx(GW, "[4,5]"), state2idx(GW, "[5,5]"), :) = 10;
GW.R(state2idx(GW, "[5,4]"), state2idx(GW, "[5,5]"), :) = 10;
updateStateTranstionForObstacles(GW);

env = rlMDPEnv(GW);
startStateIdx = find(GW.States == "[2,1]");
env.ResetFcn = @() startStateIdx;

obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

%% Create the Q-learning agent
qTable = rlTable(obsInfo, actInfo);
critic = rlQValueFunction(qTable, obsInfo, actInfo);

agentOpts = rlQAgentOptions;
agentOpts.EpsilonGreedyExploration.Epsilon = 0.3;
agentOpts.EpsilonGreedyExploration.EpsilonDecay = 0.01;
agentOpts.DiscountFactor = 0.9;

agent = rlQAgent(critic, agentOpts);

%% Train the agent
% "training-progress" opens a live window plotting episode reward and
% the moving-average reward as training proceeds.
trainOpts = rlTrainingOptions(...
    MaxEpisodes = 200, ...
    MaxStepsPerEpisode = 50, ...
    StopTrainingCriteria = "AverageReward", ...
    StopTrainingValue = 8, ...
    ScoreAveragingWindowLength = 20, ...
    Plots = "training-progress", ...
    Verbose = false);

trainStats = train(agent, env, trainOpts);

fprintf('--- Training complete ---\n');
fprintf('Episodes run: %d\n', numel(trainStats.EpisodeReward));
fprintf('Final average reward: %.2f\n', trainStats.AverageReward(end));

%% Redraw the training curve as a standalone, savable figure
figure('Name', 'Training Progress');
plot(trainStats.EpisodeReward, 'Color', [0.7 0.7 0.9]);
hold on;
plot(trainStats.AverageReward, 'b-', 'LineWidth', 2);
yline(trainOpts.StopTrainingValue, 'r--', 'Target average reward');
xlabel('Episode');
ylabel('Reward');
title('Q-learning training progress');
legend('Episode reward', 'Average reward (window = 20)', 'Location', 'southeast');
grid on;
hold off;

%% Simulate the trained policy, animating the agent live in the grid
plot(env);   % opens a live grid-world view that updates during sim()
simOpts = rlSimulationOptions(MaxSteps = 20);
experience = sim(env, agent, simOpts);

states = squeeze(experience.Observation.MDPObservations.Data);
path = arrayfun(@(s) char(GW.States(s)), states, 'UniformOutput', false);

fprintf('\n--- Learned path from [2,1] to [5,5] ---\n');
fprintf('%s\n', strjoin(path, ' -> '));

%% Draw a static summary figure of the learned path
coords = cell2mat(cellfun(@(s) sscanf(s, '[%d,%d]')', path, 'UniformOutput', false));
rows = coords(:, 1);
cols = coords(:, 2);
gridSize = GW.GridSize(1);

% Cell-center plotting coordinates: row 1 at the top, matching the
% GridWorld's [row,col] state convention.
toXY = @(r, c) deal(c, gridSize - r + 1);
[px, py] = toXY(rows, cols);

figure('Name', 'Learned Path Summary');
hold on;
axis equal;
xlim([0.5, gridSize + 0.5]);
ylim([0.5, gridSize + 0.5]);
set(gca, 'XTick', 1:gridSize, 'YTick', 1:gridSize, 'YDir', 'normal');
grid on;

% Obstacle and goal cells
obsCoords = sscanf(GW.ObstacleStates, '[%d,%d]')';
[ox, oy] = toXY(obsCoords(1), obsCoords(2));
goalCoords = sscanf(GW.TerminalStates, '[%d,%d]')';
[gx, gy] = toXY(goalCoords(1), goalCoords(2));

patch(ox + [-0.5 0.5 0.5 -0.5], oy + [-0.5 -0.5 0.5 0.5], [0.5 0.5 0.5], 'DisplayName', 'Obstacle');
patch(gx + [-0.5 0.5 0.5 -0.5], gy + [-0.5 -0.5 0.5 0.5], [0.6 0.9 0.6], 'DisplayName', 'Goal');

plot(px, py, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b', 'DisplayName', 'Learned path');
plot(px(1), py(1), 'ks', 'MarkerSize', 12, 'MarkerFaceColor', 'y', 'DisplayName', 'Start');
text(px + 0.1, py + 0.1, string(0:numel(px) - 1), 'FontSize', 9);

title('Learned path through the grid world');
xlabel('column');
ylabel('row');
legend('Location', 'eastoutside');
hold off;
