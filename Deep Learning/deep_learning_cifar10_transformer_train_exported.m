%% Train whatever network Deep Network Designer just exported (with results)
% Workflow:
%   1) Run deep_learning_cifar10_transformer_designer_demo.m -- it opens
%      Deep Network Designer with a starter Vision-Transformer-style
%      network for CIFAR-10.
%   2) In the app, edit the network (add/remove layers, rewire
%      connections, change attention heads, etc.), then click Export.
%      The app proposes the variable name "net" (or "net_1", "net_2", ...
%      if "net" is already taken in the workspace) in an editable dialog
%      -- accept the suggestion or type your own name, then click OK.
%   3) Run *this* script. It looks for a dlnetwork variable in the base
%      workspace (preferring one named "net"; if several dlnetwork
%      variables exist, it lists them and uses the last one), trains it
%      on CIFAR-10, and reports test accuracy, a confusion matrix, and
%      sample predictions -- the same evaluation this project's other
%      CIFAR-10/waveform demos use.
%
% This also works right after deep_learning_cifar10_transformer_designer_demo.m
% without ever opening the app (it will just train that script's
% un-edited starter network).

close all;

%% Find the network to train
netVar = "";
if exist('net', 'var') && isa(net, 'dlnetwork')
    netVar = "net";
else
    candidateVars = who;
    isDlnetwork = cellfun(@(v) isa(eval(v), 'dlnetwork'), candidateVars);
    dlnetworkVars = candidateVars(isDlnetwork);
    if isempty(dlnetworkVars)
        error(['No dlnetwork variable found in the base workspace. Run ' ...
            'deep_learning_cifar10_transformer_designer_demo.m first, ' ...
            'edit the network in Deep Network Designer, and click Export ' ...
            'before running this script.']);
    elseif isscalar(dlnetworkVars)
        netVar = dlnetworkVars{1};
    else
        fprintf('Multiple dlnetwork variables found: %s\n', strjoin(dlnetworkVars, ', '));
        netVar = dlnetworkVars{end};
    end
end
netToTrain = eval(netVar);
fprintf('Training dlnetwork variable "%s" (%d layers, %d learnable parameter arrays)\n', ...
    netVar, numel(netToTrain.Layers), height(netToTrain.Learnables));

%% Recover CIFAR-10 data: reuse it if present, otherwise (re)load it
dataDir = fullfile(fileparts(mfilename('fullpath')), 'data');
batchesDir = fullfile(dataDir, 'cifar-10-batches-mat');

if ~(exist('XTrain', 'var') && exist('YTrain', 'var') && exist('XTest', 'var') && exist('YTest', 'var'))
    fprintf('No CIFAR-10 data found in the workspace; loading it from %s...\n', batchesDir);
    if ~exist(batchesDir, 'dir')
        error(['CIFAR-10 data not found. Run deep_learning_cifar10_transformer_designer_demo.m ' ...
            'or deep_learning_cifar10_architectures_demo.m first to download it.']);
    end
    meta = load(fullfile(batchesDir, 'batches.meta.mat'));
    classNames = reshape(string(meta.label_names), 1, []);
    [XTrainAll, YTrainAll] = loadCifarBatches(batchesDir, ...
        ["data_batch_1", "data_batch_2", "data_batch_3", "data_batch_4", "data_batch_5"], classNames);
    [XTestAll, YTestAll] = loadCifarBatches(batchesDir, "test_batch", classNames);
    [XTrain, YTrain] = subsetPerClass(XTrainAll, YTrainAll, classNames, 1500);
    [XTest, YTest] = subsetPerClass(XTestAll, YTestAll, classNames, 300);
elseif ~exist('classNames', 'var')
    classNames = categories(YTrain)';
end
fprintf('Train: %d images, Test: %d images\n', numel(YTrain), numel(YTest));

%% Train
% Note: ExecutionEnvironment="parallel-cpu" was tried here to distribute
% mini-batches across the local parallel pool, but for this network/data
% size the pool-startup and inter-worker communication overhead made
% training slower overall (188s vs. 100s serial) and reduced accuracy (the
% effective batching across workers changes convergence within the same
% MaxEpochs) -- so it's left off. Parallel training tends to help mainly
% for larger models/datasets/batch sizes where per-step compute dominates
% the communication overhead.
options = trainingOptions('adam', ...
    MaxEpochs = 12, ...
    MiniBatchSize = 128, ...
    InitialLearnRate = 1e-3, ...
    ValidationData = {XTest, YTest}, ...
    ValidationFrequency = 30, ...
    Shuffle = 'every-epoch', ...
    Metrics = "accuracy", ...
    Plots = 'training-progress', ...
    Verbose = false);

tic;
[netTrained, info] = trainnet(XTrain, YTrain, netToTrain, 'crossentropy', options);
trainTime = toc;

%% Evaluate on the held-out test set
scores = minibatchpredict(netTrained, XTest);
classNamesCat = categories(YTest);
predLabels = scores2label(scores, classNamesCat);
accuracy = mean(predLabels == YTest);

fprintf('\n--- Test set evaluation ---\n');
fprintf('Training time: %.1f s\n', trainTime);
fprintf('Test accuracy: %.2f%% (%d / %d correct)\n', ...
    accuracy * 100, sum(predLabels == YTest), numel(YTest));

%% Training curve
figure('Name', 'Training Curve (Exported Network)');
plot(info.ValidationHistory.Iteration, info.ValidationHistory.Accuracy, '-o', 'LineWidth', 1.5);
xlabel('Iteration');
ylabel('Validation accuracy (%)');
title(sprintf('"%s" validation accuracy during training', netVar));
grid on;

%% Confusion matrix
figure('Name', 'Confusion Matrix (Exported Network)');
confusionchart(YTest, predLabels);
title(sprintf('Test accuracy: %.1f%%', accuracy * 100));

%% Sample predictions
figure('Name', 'Sample Predictions (Exported Network)');
sampleIdx = randperm(numel(YTest), 20);
for i = 1:20
    subplot(4, 5, i);
    imshow(XTest(:, :, :, sampleIdx(i)));
    trueLabel = YTest(sampleIdx(i));
    predLabel = predLabels(sampleIdx(i));
    if trueLabel == predLabel
        color = 'g';
    else
        color = 'r';
    end
    title(sprintf('%s (true: %s)', string(predLabel), string(trueLabel)), 'Color', color, 'FontSize', 8);
end
sgtitle(sprintf('Sample predictions -- "%s" (green = correct, red = wrong)', netVar));

%% Local functions (only used if CIFAR-10 data needs to be (re)loaded)
function [X, Y] = loadCifarBatches(batchesDir, batchNames, classNames)
    XCell = {};
    YCell = {};
    for b = batchNames
        s = load(fullfile(batchesDir, b + ".mat"));
        n = size(s.data, 1);
        imgs = zeros(32, 32, 3, n, 'uint8');
        for i = 1:n
            row = s.data(i, :);
            r = reshape(row(1:1024), 32, 32)';
            g = reshape(row(1025:2048), 32, 32)';
            bChan = reshape(row(2049:3072), 32, 32)';
            imgs(:, :, :, i) = cat(3, r, g, bChan);
        end
        XCell{end + 1} = imgs; %#ok<AGROW>
        YCell{end + 1} = double(s.labels) + 1; %#ok<AGROW>
    end
    X = cat(4, XCell{:});
    labelIdx = cat(1, YCell{:});
    Y = categorical(classNames(labelIdx));
    Y = Y(:);
end

function [Xs, Ys] = subsetPerClass(X, Y, classNames, n)
    idxAll = [];
    for c = classNames
        idxC = find(Y == c);
        idxC = idxC(1:min(n, numel(idxC)));
        idxAll = [idxAll; idxC]; %#ok<AGROW>
    end
    idxAll = idxAll(randperm(numel(idxAll)));
    Xs = X(:, :, :, idxAll);
    Ys = Y(idxAll);
    Ys = Ys(:);
end
