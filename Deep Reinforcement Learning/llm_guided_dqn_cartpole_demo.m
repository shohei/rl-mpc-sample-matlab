%% Deep Learning Toolbox + Reinforcement Learning Toolbox + LLM Demo:
%% LLM-Guided DQN Hyperparameter Tuning on Cart-Pole
% Extends the neural-network DQN sample (dqn_cartpole_demo.m) by putting a
% large language model "in the loop" of the RL workflow:
%   1. An LLM is asked to propose DQN hyperparameters for a Cart-Pole
%      agent under a tight training budget.
%   2. A baseline agent (Reinforcement Learning Toolbox default
%      hyperparameters, Deep Learning Toolbox critic network) and an
%      "LLM-tuned" agent are trained back to back and compared.
%   3. The LLM is asked again, this time to write a short natural-language
%      report on which agent trained better and why.
%
% The LLM calls use plain webwrite/webread (no extra add-ons required):
% a local Ollama server (http://localhost:11434) is tried first, then the
% OpenAI API if OPENAI_API_KEY is set in the environment. If neither is
% reachable, the script falls back to a deterministic offline heuristic
% so the full pipeline still runs end to end without network access.

clear;
close all;
rng(0);

%% LLM endpoint configuration
llmConfig.ollamaUrl = "http://localhost:11434/api/chat";
llmConfig.ollamaModel = "llama3.2";
llmConfig.openaiUrl = "https://api.openai.com/v1/chat/completions";
llmConfig.openaiModel = "gpt-4o-mini";
llmConfig.openaiApiKey = getenv("OPENAI_API_KEY");

%% Step 1: Ask the LLM to propose DQN hyperparameters
taskDescription = strjoin([...
    "Environment: MATLAB Reinforcement Learning Toolbox rlPredefinedEnv(""CartPole-Discrete"")." ...
    "Observation: [x, dx, theta, dtheta], continuous, unbounded." ...
    "Action: apply -10 N or +10 N to the cart (2 discrete actions)." ...
    "Agent: rlDQNAgent with the toolbox's default fully-connected critic network." ...
    "Training budget: at most 100 episodes, 200 steps per episode - short, so the agent" ...
    "must learn fast and explore efficiently." ...
    "Suggest hyperparameter values (as a plain, tunable starting point, not extreme values)" ...
    "for: MiniBatchSize, EpsilonDecay, DiscountFactor, TargetSmoothFactor, LearnRate."], " ");

[hp, hpSource] = suggestHyperparameters(llmConfig, taskDescription);

fprintf('--- DQN hyperparameters (%s) ---\n', hpSource);
disp(hp);

%% Step 2: Create the environment (shared by both agents)
env = rlPredefinedEnv("CartPole-Discrete");
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

fprintf('Observation: %s (%s)\n', obsInfo.Name, obsInfo.Description);
fprintf('Action: %s, values = %s\n\n', actInfo.Name, mat2str(actInfo.Elements));

trainOptsTemplate = rlTrainingOptions(...
    MaxEpisodes = 100, ...
    MaxStepsPerEpisode = 200, ...
    StopTrainingCriteria = "AverageReward", ...
    StopTrainingValue = 195, ...
    ScoreAveragingWindowLength = 20, ...
    Plots = "training-progress", ...
    Verbose = false);

%% Step 3: Train the baseline agent (Reinforcement Learning Toolbox defaults)
fprintf('=== Training baseline agent (default hyperparameters) ===\n');
baselineAgent = rlDQNAgent(obsInfo, actInfo);
baselineStats = train(baselineAgent, env, trainOptsTemplate);

%% Step 4: Train the LLM-tuned agent
fprintf('\n=== Training LLM-tuned agent ===\n');
tunedAgent = rlDQNAgent(obsInfo, actInfo);
tunedOpts = rlDQNAgentOptions;
tunedOpts.MiniBatchSize = hp.MiniBatchSize;
tunedOpts.EpsilonGreedyExploration.EpsilonDecay = hp.EpsilonDecay;
tunedOpts.DiscountFactor = hp.DiscountFactor;
tunedOpts.TargetSmoothFactor = hp.TargetSmoothFactor;
tunedOpts.CriticOptimizerOptions.LearnRate = hp.LearnRate;
tunedAgent.AgentOptions = tunedOpts;

tunedStats = train(tunedAgent, env, trainOptsTemplate);

%% Step 5: Compare the two training runs
baselineFinalAvg = lastNAverage(baselineStats.EpisodeReward, 10);
tunedFinalAvg = lastNAverage(tunedStats.EpisodeReward, 10);

fprintf('\n--- Comparison ---\n');
fprintf('%-28s %12s %12s\n', '', 'Baseline', 'LLM-tuned');
fprintf('%-28s %12d %12d\n', 'Episodes run', numel(baselineStats.EpisodeReward), numel(tunedStats.EpisodeReward));
fprintf('%-28s %12.1f %12.1f\n', 'Avg reward (last 10 ep.)', baselineFinalAvg, tunedFinalAvg);
fprintf('%-28s %12.1f %12.1f\n', 'Best episode reward', max(baselineStats.EpisodeReward), max(tunedStats.EpisodeReward));

figure('Name', 'Baseline vs. LLM-Tuned Training Progress');
hold on;
plot(baselineStats.AverageReward, 'b-', 'LineWidth', 2, 'DisplayName', 'Baseline (default hyperparameters)');
plot(tunedStats.AverageReward, 'r-', 'LineWidth', 2, 'DisplayName', sprintf('LLM-tuned (%s)', hpSource));
yline(trainOptsTemplate.StopTrainingValue, 'k--', 'DisplayName', 'Target average reward');
xlabel('Episode');
ylabel('Average reward (window = 20)');
title('DQN training progress: baseline vs. LLM-tuned hyperparameters');
legend('Location', 'southeast');
grid on;
hold off;

%% Step 6: Ask the LLM to summarize the comparison in a short report
resultsSummary = sprintf([...
    'Baseline DQN agent (Reinforcement Learning Toolbox default hyperparameters): ' ...
    'ran %d episodes, average reward over the last 10 episodes = %.1f, best single-episode ' ...
    'reward = %.1f.\n' ...
    'LLM-tuned DQN agent (hyperparameters: MiniBatchSize=%d, EpsilonDecay=%.4f, ' ...
    'DiscountFactor=%.3f, TargetSmoothFactor=%.4f, LearnRate=%.4f, source: %s): ' ...
    'ran %d episodes, average reward over the last 10 episodes = %.1f, best single-episode ' ...
    'reward = %.1f.\n' ...
    'The target average reward (a "solved" Cart-Pole policy) is 195 over a 20-episode window.'], ...
    numel(baselineStats.EpisodeReward), baselineFinalAvg, max(baselineStats.EpisodeReward), ...
    hp.MiniBatchSize, hp.EpsilonDecay, hp.DiscountFactor, hp.TargetSmoothFactor, hp.LearnRate, hpSource, ...
    numel(tunedStats.EpisodeReward), tunedFinalAvg, max(tunedStats.EpisodeReward));

reportSystemPrompt = strjoin([...
    "You are a reinforcement learning engineer writing a short internal report in Japanese" ...
    "(3-5 sentences) comparing two DQN training runs on the Cart-Pole task." ...
    "State which run performed better, give a plausible technical reason based on the" ...
    "hyperparameter differences, and suggest one concrete next experiment." ...
    "Reply with plain Japanese text only, no markdown, no headings."], " ");

[llmReport, reportOk] = queryLLM(llmConfig, reportSystemPrompt, resultsSummary);

if reportOk
    reportText = llmReport;
    reportSource = "live LLM";
else
    reportText = buildOfflineReport(baselineFinalAvg, tunedFinalAvg, hp, hpSource);
    reportSource = "offline heuristic fallback (no live LLM reachable)";
end

fprintf('\n--- Training report (%s) ---\n%s\n', reportSource, reportText);

reportPath = fullfile(fileparts(mfilename('fullpath')), 'llm_training_report.txt');
fid = fopen(reportPath, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', reportText);
fclose(fid);
fprintf('\nReport saved to: %s\n', reportPath);

%% Local functions

function [hp, source] = suggestHyperparameters(cfg, taskDescription)
% Ask the LLM for DQN hyperparameters; fall back to a fixed offline
% heuristic (distinct from the toolbox defaults) if no LLM is reachable
% or its reply cannot be parsed as JSON.
    defaults = struct('MiniBatchSize', 64, 'EpsilonDecay', 0.005, ...
        'DiscountFactor', 0.99, 'TargetSmoothFactor', 1e-3, 'LearnRate', 1e-2);
    fallback = struct('MiniBatchSize', 128, 'EpsilonDecay', 0.01, ...
        'DiscountFactor', 0.98, 'TargetSmoothFactor', 5e-3, 'LearnRate', 5e-3);

    systemPrompt = strjoin([...
        "You are a reinforcement learning engineer tuning a DQN agent in MATLAB's" ...
        "Reinforcement Learning Toolbox under a tight training budget." ...
        "Reply with ONLY a single JSON object (no markdown, no explanation) with these" ...
        "five numeric fields: MiniBatchSize, EpsilonDecay, DiscountFactor," ...
        "TargetSmoothFactor, LearnRate."], " ");

    [raw, ok] = queryLLM(cfg, systemPrompt, taskDescription);

    if ok
        try
            jsonText = regexp(raw, '\{.*\}', 'match', 'once');
            parsed = jsondecode(jsonText);
            hp = defaults;
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                f = fields{i};
                if isfield(parsed, f) && isnumeric(parsed.(f)) && isscalar(parsed.(f))
                    hp.(f) = double(parsed.(f));
                end
            end
            hp = clampHyperparameters(hp);
            source = "live LLM suggestion";
            return;
        catch
            fprintf('[LLM] Could not parse hyperparameters from the reply, using offline fallback.\n');
        end
    end

    hp = fallback;
    source = "offline heuristic fallback (no live LLM reachable)";
end

function hp = clampHyperparameters(hp)
% Keep LLM-suggested values within a sane range for a short training run.
    hp.MiniBatchSize = round(min(max(hp.MiniBatchSize, 16), 256));
    hp.EpsilonDecay = min(max(hp.EpsilonDecay, 1e-3), 0.05);
    hp.DiscountFactor = min(max(hp.DiscountFactor, 0.8), 0.999);
    hp.TargetSmoothFactor = min(max(hp.TargetSmoothFactor, 1e-4), 1e-2);
    hp.LearnRate = min(max(hp.LearnRate, 1e-4), 1e-1);
end

function [replyText, ok] = queryLLM(cfg, systemPrompt, userPrompt)
% Send a chat request to a local Ollama server first (no API key
% required); fall back to the OpenAI API if OPENAI_API_KEY is set.
% Returns ok=false if neither endpoint is reachable, so callers can fall
% back to an offline heuristic instead of erroring out.
    replyText = "";
    ok = false;

    messages = [struct("role", "system", "content", systemPrompt), ...
                struct("role", "user", "content", userPrompt)];

    try
        payload = struct("model", cfg.ollamaModel, "messages", messages, "stream", false);
        options = weboptions('MediaType', 'application/json', 'Timeout', 30);
        response = webwrite(cfg.ollamaUrl, payload, options);
        replyText = string(response.message.content);
        ok = true;
        fprintf('[LLM] Got a response from the local Ollama server (%s).\n', cfg.ollamaModel);
        return;
    catch
        % No local Ollama server running - fall through to OpenAI.
    end

    if ~isempty(cfg.openaiApiKey)
        try
            payload = struct("model", cfg.openaiModel, "messages", messages);
            options = weboptions('MediaType', 'application/json', 'Timeout', 30, ...
                'HeaderFields', {'Authorization', "Bearer " + cfg.openaiApiKey});
            response = webwrite(cfg.openaiUrl, payload, options);
            replyText = string(response.choices(1).message.content);
            ok = true;
            fprintf('[LLM] Got a response from the OpenAI API (%s).\n', cfg.openaiModel);
            return;
        catch ME
            fprintf('[LLM] OpenAI request failed: %s\n', ME.message);
        end
    else
        fprintf('[LLM] No local Ollama server and no OPENAI_API_KEY set.\n');
    end
end

function avg = lastNAverage(rewards, n)
    n = min(n, numel(rewards));
    avg = mean(rewards(end - n + 1:end));
end

function report = buildOfflineReport(baselineAvg, tunedAvg, hp, hpSource)
% Deterministic Japanese-language summary used when no live LLM is
% reachable, so the demo still produces a complete "report" end to end.
    if tunedAvg > baselineAvg
        winner = "LLM提案（またはオフラインの代替提案）のハイパーパラメータを用いたエージェント";
        margin = tunedAvg - baselineAvg;
    else
        winner = "既定のハイパーパラメータを用いたベースラインエージェント";
        margin = baselineAvg - tunedAvg;
    end

    report = sprintf([...
        '直近10エピソードの平均報酬は、ベースラインが%.1f、チューニング後のエージェントが%.1f' ...
        'となり、%sが約%.1fポイント上回りました。'  ...
        'チューニング設定はMiniBatchSize=%d、EpsilonDecay=%.4f、DiscountFactor=%.3f、' ...
        'TargetSmoothFactor=%.4f、LearnRate=%.4f（%s）であり、探索率の減衰速度やミニバッチ' ...
        'サイズの違いが学習の立ち上がり速度に影響したと考えられます。' ...
        '次の実験としては、エピソード数を増やして両設定を再学習し、乱数シードを変えた複数回' ...
        '試行で平均性能を比較することを推奨します。'], ...
        baselineAvg, tunedAvg, winner, margin, ...
        hp.MiniBatchSize, hp.EpsilonDecay, hp.DiscountFactor, hp.TargetSmoothFactor, hp.LearnRate, hpSource);
end
