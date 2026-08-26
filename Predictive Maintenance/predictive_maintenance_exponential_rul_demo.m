%% Predictive Maintenance Toolbox Demo: Remaining Useful Life (RUL) Estimation
%% with an Exponential Degradation Model
% A condition indicator (e.g., the RMS of a vibration signal) is simulated
% for a fleet of machines whose health degrades exponentially over time
% until it crosses a failure threshold - a standard synthetic stand-in for
% "overall trend" features used in real vibration-based condition
% monitoring. The demo walks through the core Predictive Maintenance
% Toolbox degradation-model workflow:
%   1. fit an exponentialDegradationModel to a fleet of historical
%      run-to-failure trajectories (population-level priors),
%   2. stream partial measurements from a new, still-healthy unit and
%      update the RUL estimate (and its uncertainty) as more data arrives,
%   3. check how well the predicted RUL and its confidence interval track
%      the true remaining life across a held-out fleet of test units.

clear;
close all;
rng(0);

% Short observation windows of noisy data can transiently look
% non-monotonic to the exponential model; this expected, benign warning
% is suppressed so the console output stays focused on the results.
warningState = warning('off', 'predmaint:analysis:warnExpDataAndPhiNotMatch');
cleanupWarning = onCleanup(@() warning(warningState));

%% Ground-truth degradation law (normally unknown - here used to generate data)
% Condition indicator: y(t) = phi + theta*exp(beta*t) + noise
% theta (initial degradation rate) and beta (growth rate) vary unit to
% unit, mimicking manufacturing/operating variability across a fleet.
phi0 = 0;
thetaMean = 0.05; thetaStd = 0.015;
betaMean = 0.06;  betaStd = 0.008;
noiseStd = 0.08;
failThreshold = 3.0;
tGrid = (0:250)';

%% Step 1: Simulate a fleet of historical run-to-failure trajectories
nTrain = 15;
trainTables = cell(nTrain, 1);
trainLifetimes = zeros(nTrain, 1);
for i = 1:nTrain
    theta_i = max(0.01, thetaMean + thetaStd * randn);
    beta_i = max(0.02, betaMean + betaStd * randn);
    trainTables{i} = simulateDegradationUnit(theta_i, beta_i, phi0, noiseStd, failThreshold, tGrid);
    trainLifetimes(i) = trainTables{i}.Time(end);
end

figure('Name', 'Historical Fleet Degradation');
hold on;
for i = 1:nTrain
    plot(trainTables{i}.Time, trainTables{i}.Condition, 'Color', [0.4 0.6 0.9]);
end
yline(failThreshold, 'r--', 'Failure threshold', 'LineWidth', 1.5);
xlabel('Time (operating hours)');
ylabel('Condition indicator');
title(sprintf('Historical fleet: %d run-to-failure trajectories', nTrain));
grid on;
hold off;

fprintf('Training fleet lifetimes: %s\n', mat2str(trainLifetimes'));

%% Step 2: Fit a population-level exponential degradation model
popModel = exponentialDegradationModel;
fit(popModel, trainTables, 'Time', 'Condition');

fprintf('\n--- Fitted population parameters vs. ground truth ---\n');
fprintf('%-12s %10s %10s\n', '', 'True mean', 'Fitted');
fprintf('%-12s %10.4f %10.4f\n', 'theta', thetaMean, popModel.Theta);
fprintf('%-12s %10.4f %10.4f\n', 'beta', betaMean, popModel.Beta);
fprintf('%-12s %10.4f %10.4f\n', 'phi', phi0, popModel.Phi);

%% Step 3: Stream measurements from a new test unit and track the RUL estimate
theta_test = max(0.01, thetaMean + thetaStd * randn);
beta_test = max(0.02, betaMean + betaStd * randn);
testUnit = simulateDegradationUnit(theta_test, beta_test, phi0, noiseStd, failThreshold, tGrid);
trueLifetime = testUnit.Time(end);

checkpoints = round(linspace(0.25, 0.9, 5) * trueLifetime);
streamModel = clonePriorModel(popModel);

fprintf('\n--- Streaming RUL prediction for one held-out test unit (true lifetime = %d) ---\n', trueLifetime);
fprintf('%6s %10s %10s %10s %10s\n', 't', 'estRUL', 'ciLow', 'ciHigh', 'trueRUL');

estRULHistory = zeros(size(checkpoints));
ciLowHistory = zeros(size(checkpoints));
ciHighHistory = zeros(size(checkpoints));
trueRULHistory = zeros(size(checkpoints));
prevT = -1;
pdfRUL = table();
for i = 1:numel(checkpoints)
    cp = checkpoints(i);
    mask = testUnit.Time > prevT & testUnit.Time <= cp;
    update(streamModel, testUnit(mask, :));
    prevT = cp;

    [estRUL, ciRUL, pdfRUL] = predictRUL(streamModel, failThreshold);
    trueRUL = trueLifetime - cp;

    estRULHistory(i) = estRUL;
    ciLowHistory(i) = ciRUL(1);
    ciHighHistory(i) = ciRUL(2);
    trueRULHistory(i) = trueRUL;

    fprintf('%6d %10.2f %10.2f %10.2f %10d\n', cp, estRUL, ciRUL(1), ciRUL(2), trueRUL);
end

figure('Name', 'Test Unit: Condition Indicator');
plot(testUnit.Time, testUnit.Condition, 'b-');
hold on;
yline(failThreshold, 'r--', 'Failure threshold');
xline(checkpoints, 'k:');
xlabel('Time (operating hours)');
ylabel('Condition indicator');
title('Test unit condition trace (dotted lines = prediction checkpoints)');
grid on;
hold off;

figure('Name', 'RUL Prediction Over Time');
hold on;
fill([checkpoints, fliplr(checkpoints)], [ciLowHistory, fliplr(ciHighHistory)], ...
    [0.85 0.85 1], 'EdgeColor', 'none', 'DisplayName', 'Confidence interval');
plot(checkpoints, estRULHistory, 'b-o', 'LineWidth', 1.5, 'DisplayName', 'Estimated RUL');
plot(checkpoints, trueRULHistory, 'k--', 'LineWidth', 1.5, 'DisplayName', 'True RUL');
xlabel('Time of prediction (operating hours)');
ylabel('Remaining useful life (operating hours)');
title('RUL estimate converges toward the truth as more data streams in');
legend('Location', 'best');
grid on;
hold off;

figure('Name', 'Final RUL Probability Density');
plot(pdfRUL.RUL, pdfRUL.ProbabilityDensity, 'b-', 'LineWidth', 1.5);
hold on;
xline(trueRULHistory(end), 'k--', 'True RUL', 'LineWidth', 1.5);
xlabel('Remaining useful life (operating hours)');
ylabel('Probability density');
title(sprintf('Predicted RUL distribution at t=%d', checkpoints(end)));
grid on;
hold off;

%% Step 4: Does the RUL estimate get better with more data? (fleet-level check)
% For a fleet of held-out units, predict RUL after observing a fixed
% *fraction* of each unit's own life (30%/50%/70%/90%) and check the
% absolute error against the (known, since this is synthetic) true
% remaining life, plus whether the true RUL falls inside the reported
% 90% confidence interval (nominal coverage check).
nTest = 15;
obsFractions = [0.3 0.5 0.7 0.9];
absError = nan(nTest, numel(obsFractions));
covered = false(nTest, numel(obsFractions));

for u = 1:nTest
    theta_u = max(0.01, thetaMean + thetaStd * randn);
    beta_u = max(0.02, betaMean + betaStd * randn);
    unitData = simulateDegradationUnit(theta_u, beta_u, phi0, noiseStd, failThreshold, tGrid);
    lifetime_u = unitData.Time(end);

    for k = 1:numel(obsFractions)
        obsTime = max(1, round(obsFractions(k) * lifetime_u));
        if obsTime >= lifetime_u
            continue;
        end
        testModel = clonePriorModel(popModel);
        update(testModel, unitData(unitData.Time <= obsTime, :));
        [estRUL, ciRUL] = predictRUL(testModel, failThreshold);
        trueRUL = lifetime_u - obsTime;

        absError(u, k) = abs(estRUL - trueRUL);
        covered(u, k) = trueRUL >= ciRUL(1) && trueRUL <= ciRUL(2);
    end
end

fprintf('\n--- Fleet-level RUL accuracy vs. how much of each unit''s life is observed (%d units) ---\n', nTest);
fprintf('%18s %18s %12s\n', 'Observed fraction', 'Median abs. error', 'CI coverage');
for k = 1:numel(obsFractions)
    col = absError(:, k);
    validCol = col(~isnan(col));
    fprintf('%17.0f%% %15.1f h %11.0f%%\n', ...
        obsFractions(k) * 100, median(validCol), 100 * mean(covered(~isnan(col), k)));
end

%% Local functions

function unitTable = simulateDegradationUnit(theta, beta, phi, noiseStd, failThreshold, tGrid)
% Simulate one unit's condition-indicator trajectory from an exponential
% degradation law, truncated at the first sample that crosses the failure
% threshold (or at the end of tGrid if it never does).
    y = phi + theta * exp(beta * tGrid) + noiseStd * randn(size(tGrid));
    idxFail = find(y >= failThreshold, 1, 'first');
    if isempty(idxFail)
        idxFail = numel(tGrid);
    end
    unitTable = table(tGrid(1:idxFail), y(1:idxFail), 'VariableNames', {'Time', 'Condition'});
end

function freshMdl = clonePriorModel(popMdl)
% exponentialDegradationModel is a handle object but not copyable, and
% restart() does not reliably reset CurrentLifeTimeValue across repeated
% use in a loop. Building a fresh model from the fitted population
% parameters (used as this new unit's prior) gives each test unit a clean
% starting state while reusing everything learned from the fleet.
    freshMdl = exponentialDegradationModel( ...
        'Theta', popMdl.Theta, 'ThetaVariance', popMdl.ThetaVariance, ...
        'Beta', popMdl.Beta, 'BetaVariance', popMdl.BetaVariance, ...
        'Rho', popMdl.Rho, 'Phi', popMdl.Phi, ...
        'NoiseVariance', popMdl.NoiseVariance, ...
        'LifeTimeVariable', 'Time', 'DataVariables', 'Condition');
end
