%% Deep Learning Toolbox Demo: Handwritten Digit Classification (CNN)
% A simple convolutional neural network trained to classify handwritten
% digits (0-9), using the digit image dataset bundled with Deep Learning
% Toolbox. This is the classic "hello world" of deep learning in MATLAB:
% load images, define a small CNN, train it with trainnet, and evaluate
% accuracy on held-out test images.

clear;
close all;
rng(0);

%% Load the built-in digit dataset (10,000 28x28 grayscale images, 10 classes)
digitDatasetPath = fullfile(matlabroot, 'toolbox', 'nnet', 'nndemos', 'nndatasets', 'DigitDataset');
imds = imageDatastore(digitDatasetPath, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

fprintf('Dataset: %d images, %d classes\n', numel(imds.Files), numel(categories(imds.Labels)));
disp(countEachLabel(imds));

[imdsTrain, imdsTest] = splitEachLabel(imds, 0.8, 'randomize');
fprintf('Train: %d images, Test: %d images\n', numel(imdsTrain.Files), numel(imdsTest.Files));

%% Show a sample grid of training images
figure('Name', 'Sample Training Images');
sampleIdx = randperm(numel(imdsTrain.Files), 20);
for i = 1:20
    subplot(4, 5, i);
    imshow(readimage(imdsTrain, sampleIdx(i)));
    title(string(imdsTrain.Labels(sampleIdx(i))));
end
sgtitle('Sample training images with labels');

%% Define a small CNN
layers = [
    imageInputLayer([28 28 1], 'Normalization', 'zscore')

    convolution2dLayer(3, 8, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, 'Stride', 2)

    convolution2dLayer(3, 16, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, 'Stride', 2)

    fullyConnectedLayer(10)
    softmaxLayer];

net = dlnetwork(layers);

%% Train the network
options = trainingOptions('adam', ...
    MaxEpochs = 8, ...
    MiniBatchSize = 128, ...
    InitialLearnRate = 1e-3, ...
    ValidationData = imdsTest, ...
    ValidationFrequency = 20, ...
    Shuffle = 'every-epoch', ...
    Plots = 'training-progress', ...
    Verbose = false);

netTrained = trainnet(imdsTrain, net, 'crossentropy', options);

%% Evaluate on the held-out test set
scores = minibatchpredict(netTrained, imdsTest);
classNames = categories(imdsTest.Labels);
predLabels = scores2label(scores, classNames);
accuracy = mean(predLabels == imdsTest.Labels);

fprintf('\n--- Test set evaluation ---\n');
fprintf('Test accuracy: %.2f%% (%d / %d correct)\n', ...
    accuracy * 100, sum(predLabels == imdsTest.Labels), numel(imdsTest.Labels));

figure('Name', 'Confusion Matrix');
confusionchart(imdsTest.Labels, predLabels);
title(sprintf('Test accuracy: %.1f%%', accuracy * 100));

%% Visualize predictions on a sample of test images
figure('Name', 'Sample Predictions');
sampleIdx = randperm(numel(imdsTest.Files), 20);
for i = 1:20
    subplot(4, 5, i);
    imshow(readimage(imdsTest, sampleIdx(i)));
    trueLabel = imdsTest.Labels(sampleIdx(i));
    predLabel = predLabels(sampleIdx(i));
    if trueLabel == predLabel
        color = 'g';
    else
        color = 'r';
    end
    title(sprintf('pred: %s (true: %s)', string(predLabel), string(trueLabel)), 'Color', color);
end
sgtitle('Sample predictions on test images (green = correct, red = wrong)');
