%% Deep Learning Toolbox Demo: Transformer Encoder for Waveform Classification
% A small Transformer encoder (self-attention, not recurrence) built from
% Deep Learning Toolbox layers, trained to classify short time-series
% into one of four synthetic waveform types: sine, square, sawtooth, or
% noise. The dataset is generated on the fly (no download needed).
%
% Architecture (a standard "encoder-only" Transformer block):
%   sequenceInputLayer
%     -> fullyConnectedLayer (per-timestep embedding, 1 -> dModel channels)
%     -> + sinusoidalPositionEncodingLayer (position information)
%     -> [ selfAttentionLayer -> +residual -> layerNorm
%          -> feed-forward (fc-relu-fc) -> +residual -> layerNorm ] x numBlocks
%     -> globalAveragePooling1dLayer (pool over time -> fixed-size vector)
%     -> fullyConnectedLayer(numClasses) -> softmax
%
% To try a different architecture, change dModel/numHeads/dFF/numBlocks
% below, or edit buildTransformerEncoder at the bottom of this file.

clear;
close all;
rng(0);

%% Generate a synthetic waveform classification dataset
classNames = ["sine", "square", "sawtooth", "noise"];
seqLength = 64;
numPerClass = 200;

[X, Y] = generateWaveforms(classNames, seqLength, numPerClass);
fprintf('Generated %d sequences (%d per class, length %d)\n', numel(Y), numPerClass, seqLength);

cv = cvpartition(Y, 'HoldOut', 0.2);
XTrain = X(training(cv));
YTrain = Y(training(cv));
XTest = X(test(cv));
YTest = Y(test(cv));
fprintf('Train: %d, Test: %d\n', numel(YTrain), numel(YTest));

%% Show a sample waveform from each class
figure('Name', 'Sample Waveforms');
for c = 1:numel(classNames)
    idx = find(Y == classNames(c), 1);
    subplot(2, 2, c);
    plot(X{idx}, 'LineWidth', 1.2);
    title(classNames(c));
    xlabel('Time step');
    ylim([-3 3]);
    grid on;
end
sgtitle('One example sequence per class');

%% Build the Transformer encoder
dModel = 32;
numHeads = 4;
dFF = 64;
numBlocks = 2;
net = buildTransformerEncoder(dModel, numHeads, dFF, numBlocks, numel(classNames));
fprintf('\nTransformer encoder: dModel=%d, numHeads=%d, dFF=%d, numBlocks=%d\n', ...
    dModel, numHeads, dFF, numBlocks);

%% Visualize the architecture
% A static graph of the layer connections (nodes = layers, edges = data
% flow -- this is where the attention residual connections are visible).
figure('Name', 'Transformer Architecture Graph');
plot(net);
title('Transformer encoder architecture');

% For a more detailed, interactive view (per-layer activation sizes,
% learnable parameter counts, and the same graph), use the Network
% Analyzer app:
analyzeNetwork(net);

%% Train
options = trainingOptions('adam', ...
    MaxEpochs = 25, ...
    MiniBatchSize = 32, ...
    InitialLearnRate = 1e-3, ...
    ValidationData = {XTest, YTest}, ...
    ValidationFrequency = 15, ...
    Shuffle = 'every-epoch', ...
    Plots = 'training-progress', ...
    Verbose = false);

netTrained = trainnet(XTrain, YTrain, net, 'crossentropy', options);

%% Evaluate on the held-out test set
scores = minibatchpredict(netTrained, XTest);
predLabels = scores2label(scores, categories(YTest));
accuracy = mean(predLabels == YTest);

fprintf('\n--- Test set evaluation ---\n');
fprintf('Test accuracy: %.2f%% (%d / %d correct)\n', ...
    accuracy * 100, sum(predLabels == YTest), numel(YTest));

figure('Name', 'Confusion Matrix');
confusionchart(YTest, predLabels);
title(sprintf('Test accuracy: %.1f%%', accuracy * 100));

%% Visualize predictions on a sample of test sequences
figure('Name', 'Sample Predictions');
sampleIdx = randperm(numel(YTest), min(12, numel(YTest)));
for i = 1:numel(sampleIdx)
    subplot(3, 4, i);
    plot(XTest{sampleIdx(i)}, 'LineWidth', 1.2);
    trueLabel = YTest(sampleIdx(i));
    predLabel = predLabels(sampleIdx(i));
    if trueLabel == predLabel
        color = 'g';
    else
        color = 'r';
    end
    title(sprintf('pred: %s (true: %s)', string(predLabel), string(trueLabel)), 'Color', color);
    ylim([-3 3]);
end
sgtitle('Sample predictions on test sequences (green = correct, red = wrong)');

%% Local functions
function [X, Y] = generateWaveforms(classNames, T, nPerClass)
    % Generates nPerClass random-phase/frequency/amplitude examples of
    % each waveform type, each as a T-by-1 sequence (T x numFeatures,
    % the orientation trainnet expects for cell-array sequence data).
    t = (0:T - 1)';
    numObs = numel(classNames) * nPerClass;
    X = cell(numObs, 1);
    labels = strings(numObs, 1);
    idx = 1;
    for c = 1:numel(classNames)
        for i = 1:nPerClass
            freq = 0.05 + 0.1 * rand();
            phase = 2 * pi * rand();
            amp = 0.7 + 0.6 * rand();
            noiseLevel = 0.1;
            switch classNames(c)
                case "sine"
                    s = amp * sin(2 * pi * freq * t + phase);
                case "square"
                    s = amp * square(2 * pi * freq * t + phase);
                case "sawtooth"
                    s = amp * sawtooth(2 * pi * freq * t + phase);
                case "noise"
                    s = zeros(T, 1);
                    noiseLevel = 1.0;
            end
            s = s + noiseLevel * randn(T, 1);
            X{idx} = s;
            labels(idx) = classNames(c);
            idx = idx + 1;
        end
    end
    Y = categorical(labels);
end

function net = buildTransformerEncoder(dModel, numHeads, dFF, numBlocks, numClasses)
    lgraph = layerGraph();
    lgraph = addLayers(lgraph, sequenceInputLayer(1, 'Normalization', 'zscore', 'Name', 'input'));
    lgraph = addLayers(lgraph, fullyConnectedLayer(dModel, 'Name', 'embed'));
    lgraph = addLayers(lgraph, sinusoidalPositionEncodingLayer(dModel, 'Name', 'posenc'));
    lgraph = addLayers(lgraph, additionLayer(2, 'Name', 'embed_plus_pos'));
    lgraph = connectLayers(lgraph, 'input', 'embed');
    lgraph = connectLayers(lgraph, 'input', 'posenc');
    lgraph = connectLayers(lgraph, 'embed', 'embed_plus_pos/in1');
    lgraph = connectLayers(lgraph, 'posenc', 'embed_plus_pos/in2');

    prevName = 'embed_plus_pos';
    for b = 1:numBlocks
        tag = sprintf('b%d_', b);

        % Self-attention sub-block, with a residual connection and layer norm
        lgraph = addLayers(lgraph, selfAttentionLayer(numHeads, dModel, 'Name', [tag 'attn']));
        lgraph = addLayers(lgraph, additionLayer(2, 'Name', [tag 'attn_res']));
        lgraph = addLayers(lgraph, layerNormalizationLayer('Name', [tag 'norm1']));
        lgraph = connectLayers(lgraph, prevName, [tag 'attn']);
        lgraph = connectLayers(lgraph, [tag 'attn'], [tag 'attn_res/in1']);
        lgraph = connectLayers(lgraph, prevName, [tag 'attn_res/in2']);
        lgraph = connectLayers(lgraph, [tag 'attn_res'], [tag 'norm1']);

        % Position-wise feed-forward sub-block, also with a residual + norm
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
