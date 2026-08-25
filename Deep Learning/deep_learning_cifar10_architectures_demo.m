%% Deep Learning Toolbox Demo: CIFAR-10 -- comparing network architectures
% A harder benchmark than deep_learning_digit_classification_demo.m:
% CIFAR-10 is 32x32 RGB photos of real objects (10 classes), which needs
% a network to learn actual visual features instead of simple strokes.
%
% This script is structured so you can swap in different layer
% connectivity and compare them directly: two architectures (a plain
% sequential CNN and a CNN with a residual/skip connection, both with a
% similar parameter budget) are trained back-to-back on the same data
% split, and their learning curves and test accuracy are compared.
%
% To try your own architecture: add a new "build___Net" local function
% at the bottom (returning a dlnetwork) and add it to the `architectures`
% list below.

clear;
close all;
rng(0);

%% Download and load CIFAR-10 (cached locally under data/, gitignored)
dataDir = fullfile(fileparts(mfilename('fullpath')), 'data');
archiveFile = fullfile(dataDir, 'cifar-10-matlab.tar.gz');
batchesDir = fullfile(dataDir, 'cifar-10-batches-mat');

if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end
if ~exist(batchesDir, 'dir')
    if ~exist(archiveFile, 'file')
        fprintf('Downloading CIFAR-10 (~183 MB)...\n');
        websave(archiveFile, 'https://www.cs.toronto.edu/~kriz/cifar-10-matlab.tar.gz');
    end
    fprintf('Extracting CIFAR-10...\n');
    untar(archiveFile, dataDir);
end

meta = load(fullfile(batchesDir, 'batches.meta.mat'));
classNames = reshape(string(meta.label_names), 1, []); % ensure a row vector so "for c = classNames" iterates elementwise

[XTrainAll, YTrainAll] = loadCifarBatches(batchesDir, ...
    ["data_batch_1", "data_batch_2", "data_batch_3", "data_batch_4", "data_batch_5"], classNames);
[XTestAll, YTestAll] = loadCifarBatches(batchesDir, "test_batch", classNames);

%% Take a manageable subset (this is a CPU-friendly demo, not a leaderboard run)
% Set these higher (up to 5000/1000) -- and increase MaxEpochs below -- if
% you have more time or a GPU.
numTrainPerClass = 1500;
numTestPerClass = 300;
[XTrain, YTrain] = subsetPerClass(XTrainAll, YTrainAll, classNames, numTrainPerClass);
[XTest, YTest] = subsetPerClass(XTestAll, YTestAll, classNames, numTestPerClass);

fprintf('Classes: %s\n', strjoin(classNames, ', '));
fprintf('Train: %d images (%d/class), Test: %d images (%d/class)\n', ...
    numel(YTrain), numTrainPerClass, numel(YTest), numTestPerClass);

%% Show a sample grid of training images
figure('Name', 'CIFAR-10 Sample Images');
sampleIdx = randperm(numel(YTrain), 20);
for i = 1:20
    subplot(4, 5, i);
    imshow(XTrain(:, :, :, sampleIdx(i)));
    title(string(YTrain(sampleIdx(i))));
end
sgtitle('Sample CIFAR-10 training images');

%% Define the architectures to compare
% Add your own build___Net(numClasses) function below and list it here.
numClasses = numel(classNames);
architectures = {
    "Plain CNN",    @() buildPlainNet(numClasses)
    "Residual CNN", @() buildResidualNet(numClasses)
    };

options = trainingOptions('adam', ...
    MaxEpochs = 12, ...
    MiniBatchSize = 128, ...
    InitialLearnRate = 1e-3, ...
    ValidationData = {XTest, YTest}, ...
    ValidationFrequency = 30, ...
    Metrics = "accuracy", ...
    Shuffle = 'every-epoch', ...
    Plots = 'none', ...
    Verbose = false);

results = struct('Name', {}, 'Net', {}, 'Info', {}, 'TestAccuracy', {}, 'TrainTime', {});
for i = 1:size(architectures, 1)
    name = architectures{i, 1};
    net = architectures{i, 2}();
    fprintf('\n=== Training "%s" (%d learnable parameters) ===\n', name, numLearnables(net));

    tic;
    [netTrained, info] = trainnet(XTrain, YTrain, net, 'crossentropy', options);
    trainTime = toc;

    scores = minibatchpredict(netTrained, XTest);
    predLabels = scores2label(scores, categories(YTest));
    acc = mean(predLabels == YTest);

    fprintf('"%s": test accuracy = %.2f%%, training time = %.1f s\n', name, acc * 100, trainTime);

    results(end + 1) = struct('Name', name, 'Net', netTrained, 'Info', info, ...
        'TestAccuracy', acc, 'TrainTime', trainTime); %#ok<SAGROW>
end

%% Compare validation-accuracy learning curves across architectures
figure('Name', 'Architecture Comparison: Learning Curves');
hold on;
for i = 1:numel(results)
    valAcc = results(i).Info.ValidationHistory.Accuracy;
    valIter = results(i).Info.ValidationHistory.Iteration;
    plot(valIter, valAcc, '-o', 'DisplayName', results(i).Name, 'LineWidth', 1.5);
end
hold off;
xlabel('Iteration');
ylabel('Validation accuracy (%)');
title('Validation accuracy during training');
legend('Location', 'southeast');
grid on;

%% Compare final test accuracy and training time
figure('Name', 'Architecture Comparison: Summary');
subplot(1, 2, 1);
bar(categorical([results.Name]), [results.TestAccuracy] * 100);
ylabel('Test accuracy (%)');
title('Final test accuracy');
grid on;

subplot(1, 2, 2);
bar(categorical([results.Name]), [results.TrainTime]);
ylabel('Training time (s)');
title('Training time');
grid on;

fprintf('\n--- Summary ---\n');
for i = 1:numel(results)
    fprintf('%-14s test accuracy = %5.2f%%   training time = %6.1f s\n', ...
        results(i).Name, results(i).TestAccuracy * 100, results(i).TrainTime);
end

%% Local functions
function [X, Y] = loadCifarBatches(batchesDir, batchNames, classNames)
    % Loads one or more CIFAR-10 .mat batches into a 32x32x3xN uint8
    % array and a categorical label vector.
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
    Y = Y(:); % indexing a row vector (classNames) yields a row; force a column
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
    Ys = Ys(:); % indexing follows Y's orientation, not idxAll's; force a column
end

function n = numLearnables(net)
    n = 0;
    for i = 1:height(net.Learnables)
        n = n + numel(net.Learnables.Value{i});
    end
end

function net = buildPlainNet(numClasses)
    % A straightforward sequential CNN: three conv-bn-relu-pool blocks.
    layers = [
        imageInputLayer([32 32 3], 'Normalization', 'zscore')

        convolution2dLayer(3, 16, 'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        maxPooling2dLayer(2, 'Stride', 2)

        convolution2dLayer(3, 32, 'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        maxPooling2dLayer(2, 'Stride', 2)

        convolution2dLayer(3, 64, 'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        maxPooling2dLayer(2, 'Stride', 2)

        fullyConnectedLayer(numClasses)
        softmaxLayer];
    net = dlnetwork(layers);
end

function net = buildResidualNet(numClasses)
    % Same overall depth/filter budget as buildPlainNet, but the middle
    % block is a residual block: the block's input is added to its
    % output (via a 1x1-conv shortcut to match channel count) before the
    % final ReLU, using layerGraph + additionLayer for the non-sequential
    % connection.
    lgraph = layerGraph();

    lgraph = addLayers(lgraph, [
        imageInputLayer([32 32 3], 'Normalization', 'zscore', 'Name', 'input')

        convolution2dLayer(3, 16, 'Padding', 'same', 'Name', 'conv1')
        batchNormalizationLayer('Name', 'bn1')
        reluLayer('Name', 'relu1')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool1')
        ]);

    % Residual block on the pool1 output
    lgraph = addLayers(lgraph, [
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'res_conv1')
        batchNormalizationLayer('Name', 'res_bn1')
        reluLayer('Name', 'res_relu1')
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'res_conv2')
        batchNormalizationLayer('Name', 'res_bn2')
        ]);
    lgraph = addLayers(lgraph, convolution2dLayer(1, 32, 'Name', 'res_shortcut'));
    lgraph = addLayers(lgraph, additionLayer(2, 'Name', 'res_add'));
    lgraph = addLayers(lgraph, reluLayer('Name', 'res_relu2'));

    lgraph = addLayers(lgraph, [
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool2')

        convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'conv3')
        batchNormalizationLayer('Name', 'bn3')
        reluLayer('Name', 'relu3')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool3')

        fullyConnectedLayer(numClasses, 'Name', 'fc')
        softmaxLayer('Name', 'softmax')
        ]);

    lgraph = connectLayers(lgraph, 'pool1', 'res_conv1');
    lgraph = connectLayers(lgraph, 'pool1', 'res_shortcut');
    lgraph = connectLayers(lgraph, 'res_bn2', 'res_add/in1');
    lgraph = connectLayers(lgraph, 'res_shortcut', 'res_add/in2');
    lgraph = connectLayers(lgraph, 'res_add', 'res_relu2');
    lgraph = connectLayers(lgraph, 'res_relu2', 'pool2');

    net = dlnetwork(lgraph);
end
