%% CIFAR-10 + Deep Network Designer: build/edit a Transformer (ViT-style) visually
% A simplified fork of deep_learning_cifar10_architectures_demo.m: same
% CIFAR-10 data pipeline, but only ONE starter network (no side-by-side
% architecture comparison), and the goal here is just to get that network
% open in Deep Network Designer so you can try out Transformer ideas on
% it by hand -- training is a separate, later step.
%
% The starter network is a small Vision-Transformer-style model:
%   image -> non-overlapping 4x4 patches embedded via a strided
%   convolution -> flattened into a sequence of patch tokens -> a
%   standard Transformer encoder (self-attention + feed-forward blocks,
%   same pattern as deep_learning_transformer_waveform_demo.m) ->
%   pooled -> classified.
% Patchifying an image into a token sequence needs one small piece of
% plumbing self-attention doesn't come with out of the box: a
% functionLayer that reshapes the convolution's image-shaped output
% (H x W x C x B) into a sequence (C x T x B, T = H*W patches).
%
% To try your own idea, either edit buildVitStarterNet below, or just
% run this script and rebuild the network directly in the app.

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
classNames = reshape(string(meta.label_names), 1, []); % row vector: "for c = classNames" must iterate elementwise

[XTrainAll, YTrainAll] = loadCifarBatches(batchesDir, ...
    ["data_batch_1", "data_batch_2", "data_batch_3", "data_batch_4", "data_batch_5"], classNames);
[XTestAll, YTestAll] = loadCifarBatches(batchesDir, "test_batch", classNames);

%% Take a manageable subset
% XTrain/YTrain/XTest/YTest are left in the base workspace so that once
% you've designed a network you like, you can train it the same way as
% deep_learning_cifar10_architectures_demo.m does (trainnet(XTrain,
% YTrain, exportedNet, "crossentropy", options)).
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
sgtitle('Sample training images');

%% Build a starter Vision-Transformer-style network
dModel = 32;
numHeads = 4;
dFF = 64;
numBlocks = 2;
patchSize = 4; % 32x32 image -> 8x8 = 64 patch tokens
net = buildVitStarterNet(dModel, numHeads, dFF, numBlocks, patchSize, numel(classNames));
fprintf('\nStarter network: patchSize=%d, dModel=%d, numHeads=%d, dFF=%d, numBlocks=%d\n', ...
    patchSize, dModel, numHeads, dFF, numBlocks);

%% Show the architecture, then open it for editing in Deep Network Designer
figure('Name', 'Starter Network Architecture Graph');
plot(net);
title('CIFAR-10 ViT-style starter network');

fprintf('\nOpening Deep Network Designer...\n');
fprintf('Edit the network (add/remove layers, rewire connections, change\n');
fprintf('attention heads, etc.), then use Export to send it back to the\n');
fprintf('workspace. From there, train it the same way as\n');
fprintf('deep_learning_cifar10_architectures_demo.m does with trainnet.\n');

deepNetworkDesigner(net);

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

function net = buildVitStarterNet(dModel, numHeads, dFF, numBlocks, patchSize, numClasses)
    % Patch embedding: a strided convolution turns the image into a grid
    % of patch embeddings (kernel size = stride = patchSize is the
    % standard "ViT patchify" trick), then a functionLayer reshapes that
    % image-shaped output (H x W x C x B) into a sequence (C x T x B).
    reshapeToSequence = @(x) dlarray( ...
        permute(reshape(stripdims(x), [], size(x, 3), size(x, 4)), [2 1 3]), 'CTB');

    lgraph = layerGraph();
    lgraph = addLayers(lgraph, [
        imageInputLayer([32 32 3], 'Normalization', 'zscore', 'Name', 'input')
        convolution2dLayer(patchSize, dModel, 'Stride', patchSize, 'Name', 'patch_embed')
        functionLayer(reshapeToSequence, 'Formattable', true, 'Name', 'to_sequence')
        ]);
    lgraph = addLayers(lgraph, sinusoidalPositionEncodingLayer(dModel, 'Name', 'posenc'));
    lgraph = addLayers(lgraph, additionLayer(2, 'Name', 'embed_plus_pos'));
    lgraph = connectLayers(lgraph, 'to_sequence', 'posenc');
    lgraph = connectLayers(lgraph, 'to_sequence', 'embed_plus_pos/in1');
    lgraph = connectLayers(lgraph, 'posenc', 'embed_plus_pos/in2');

    prevName = 'embed_plus_pos';
    for b = 1:numBlocks
        tag = sprintf('b%d_', b);

        lgraph = addLayers(lgraph, selfAttentionLayer(numHeads, dModel, 'Name', [tag 'attn']));
        lgraph = addLayers(lgraph, additionLayer(2, 'Name', [tag 'attn_res']));
        lgraph = addLayers(lgraph, layerNormalizationLayer('Name', [tag 'norm1']));
        lgraph = connectLayers(lgraph, prevName, [tag 'attn']);
        lgraph = connectLayers(lgraph, [tag 'attn'], [tag 'attn_res/in1']);
        lgraph = connectLayers(lgraph, prevName, [tag 'attn_res/in2']);
        lgraph = connectLayers(lgraph, [tag 'attn_res'], [tag 'norm1']);

        lgraph = addLayers(lgraph, fullyConnectedLayer(dFF, 'Name', [tag 'ff1']));
        lgraph = addLayers(lgraph, reluLayer('Name', [tag 'ff_relu']));
        lgraph = addLayers(lgraph, fullyConnectedLayer(dModel, 'Name', [tag 'ff2']));
        lgraph = addLayers(lgraph, additionLayer(2, 'Name', [tag 'ff_res']));
        lgraph = addLayers(lgraph, layerNormalizationLayer('Name', [tag 'norm2']));
        lgraph = connectLayers(lgraph, [tag 'norm1'], [tag 'ff1']);
        lgraph = connectLayers(lgraph, [tag 'ff1'], [tag 'ff_relu']);
        lgraph = connectLayers(lgraph, [tag 'ff_relu'], [tag 'ff2']);
        lgraph = connectLayers(lgraph, [tag 'ff2'], [tag 'ff_res/in1']);
        lgraph = connectLayers(lgraph, [tag 'norm1'], [tag 'ff_res/in2']);
        lgraph = connectLayers(lgraph, [tag 'ff_res'], [tag 'norm2']);

        prevName = [tag 'norm2'];
    end

    lgraph = addLayers(lgraph, globalAveragePooling1dLayer('Name', 'pool'));
    lgraph = addLayers(lgraph, fullyConnectedLayer(numClasses, 'Name', 'fc'));
    lgraph = addLayers(lgraph, softmaxLayer('Name', 'softmax'));
    lgraph = connectLayers(lgraph, prevName, 'pool');
    lgraph = connectLayers(lgraph, 'pool', 'fc');
    lgraph = connectLayers(lgraph, 'fc', 'softmax');

    net = dlnetwork(lgraph);
end
