%% Deep Network Designer: visually edit the Transformer architecture
% deep_learning_transformer_waveform_demo.m visualizes the network with
% plot(net) (a static graph) and analyzeNetwork(net) (a detailed,
% read-only layer inspector). Deep Network Designer goes a step further:
% it is a full GUI for building and *editing* a network -- you can drag
% in new layers from a palette, delete layers, and rewire connections
% (e.g. add another encoder block, change the number of attention heads,
% or add a skip connection) by clicking and dragging, then export the
% edited network back to the workspace or generate the equivalent
% MATLAB code for it.
%
% This script just builds the same (untrained) Transformer architecture
% as deep_learning_transformer_waveform_demo.m and opens it in the app,
% so you don't need to run the training script first.

clear;
close all;

dModel = 32;
numHeads = 4;
dFF = 64;
numBlocks = 2;
numClasses = 4; % sine, square, sawtooth, noise

net = buildTransformerEncoder(dModel, numHeads, dFF, numBlocks, numClasses);

fprintf('Opening Deep Network Designer with the Transformer encoder...\n');
fprintf('In the app you can: drag in layers from the palette, delete/rewire\n');
fprintf('connections, then use Export to send the edited network back to\n');
fprintf('the workspace (or "Generate Code" to get the equivalent script).\n');

deepNetworkDesigner(net);

%% Local function (same architecture as deep_learning_transformer_waveform_demo.m)
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
