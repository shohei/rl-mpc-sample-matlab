# Deep Learning Toolbox + RL Toolbox + LLM サンプル: LLM主導のDQNハイパーパラメータ調整（Cart-Pole）

`dqn_cartpole_demo.m`（ニューラルネットワーク critic を持つDQNエージェント）を拡張し、大規模言語モデル（LLM）をRLのワークフローに組み込んだサンプルです。LLMにDQNのハイパーパラメータを提案させ、既定値（ベースライン）と提案値（LLMチューニング）の2つのエージェントを同じ条件で学習・比較し、最後にLLMへ学習結果の分析レポートを書かせます。

## ファイル

- `llm_guided_dqn_cartpole_demo.m` — LLM問い合わせ・2エージェントの学習・比較・レポート生成を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Reinforcement Learning Toolbox
- Deep Learning Toolbox（DQNのニューラルネットワーク critic に使用）
- 追加のトールボックス・アドオンは不要（LLM呼び出しは標準の `webwrite`/`weboptions` のみで実装）
- （任意）ローカルのLLMサーバー、または OpenAI API キー — 詳細は下記「LLMの有効化」を参照

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
llm_guided_dqn_cartpole_demo
```

学習には数十秒〜1分程度かかります（各エージェント最大100エピソード×2回）。

## LLMの有効化

このスクリプトはLLMへの問い合わせを2回行います（①ハイパーパラメータの提案、②学習結果レポートの生成）。呼び出し先は次の優先順位で自動的に切り替わります。

1. **ローカルのOllamaサーバー**（`http://localhost:11434/api/chat`、既定モデル `llama3.2`）— APIキー不要。[Ollama](https://ollama.com/)をインストールし、`ollama pull llama3.2` などでモデルを取得した状態で起動しておくと自動的に使われます。
2. **OpenAI API**（`https://api.openai.com/v1/chat/completions`、既定モデル `gpt-4o-mini`）— 環境変数 `OPENAI_API_KEY` が設定されている場合に使用されます。
3. **オフラインのフォールバック** — 上記のどちらにも接続できない場合、固定の代替ハイパーパラメータと定型文のレポートを使ってパイプライン全体を最後まで実行します（ネットワーク接続なしでも動作確認できます）。

どの経路が使われたかはコンソール出力（`[LLM] ...`）と、ハイパーパラメータ・レポートの出典表示（`live LLM suggestion` / `offline heuristic fallback ...`）で確認できます。モデル名やエンドポイントはスクリプト冒頭の `llmConfig` 構造体で変更できます。

## やっていること

1. **ハイパーパラメータの提案**（`suggestHyperparameters` → `queryLLM`）
   - タスク（環境・観測・行動空間・学習エピソード数の制約）を説明するプロンプトを組み立て、LLMに `MiniBatchSize`・`EpsilonDecay`・`DiscountFactor`・`TargetSmoothFactor`・`LearnRate` をJSONで提案させる
   - LLMの応答からJSON部分を正規表現で抽出して `jsondecode`、値を妥当な範囲にクランプ
   - LLMに接続できない／JSONの解析に失敗した場合は、既定値とは異なる固定のオフライン代替値を使用
2. **環境構築**（`rlPredefinedEnv("CartPole-Discrete")`）— `dqn_cartpole_demo.m` と同一
3. **ベースラインエージェントの学習**（`rlDQNAgent(obsInfo, actInfo)`、RL Toolbox既定のハイパーパラメータ）
4. **LLMチューニングエージェントの学習**（同じ既定ネットワークに、LLM提案（またはフォールバック）のハイパーパラメータを `agent.AgentOptions` 経由で適用）
5. **比較**
   - 直近10エピソードの平均報酬・最高エピソード報酬・学習エピソード数を表形式でコンソール出力
   - 両エージェントの移動平均報酬の学習曲線を1つのFigureに重ねて表示
6. **学習結果レポートの生成**（`queryLLM`）
   - 2つの学習結果の要約をLLMに渡し、日本語で3〜5文の短いレポート（どちらが良かったか・技術的な理由・次の実験案）を書かせる
   - LLMに接続できない場合は `buildOfflineReport` が同様の内容を定型文で生成
   - レポートはコンソールに表示され、`llm_training_report.txt` としてこのフォルダに保存される（`.gitignore` 済みの実行時生成物）

## 実行結果の例（オフラインフォールバック時）

```text
[LLM] No local Ollama server and no OPENAI_API_KEY set.
--- DQN hyperparameters (offline heuristic fallback (no live LLM reachable)) ---
         MiniBatchSize: 128
          EpsilonDecay: 0.0100
        DiscountFactor: 0.9800
    TargetSmoothFactor: 0.0050
             LearnRate: 0.0050

--- Comparison ---
                                 Baseline    LLM-tuned
Episodes run                          100          100
Avg reward (last 10 ep.)             91.1        117.8
Best episode reward                 200.0        200.0

--- Training report (offline heuristic fallback (no live LLM reachable)) ---
直近10エピソードの平均報酬は、ベースラインが91.1、チューニング後のエージェントが117.8となり、...
```

Ollamaが起動している、または `OPENAI_API_KEY` が設定されている環境では、`[LLM] Got a response from ...` と表示され、ハイパーパラメータとレポートが実際のLLMの応答に置き換わります。

実行すると以下のウィンドウが開きます（各エージェントの学習ごとに1つずつ）。

- RL Toolbox純正の「Training Progress」アプリ（学習中のライブグラフ、2回分）
- `Baseline vs. LLM-Tuned Training Progress`（2エージェントの学習曲線を重ねた比較Figure）

## 補足・詰まりやすい点

- LLMへの問い合わせは標準MATLABの `webwrite`/`weboptions`（`MediaType = 'application/json'`）のみで実装しており、"Large Language Models (LLMs) with MATLAB" のような追加アドオンは不要です。Ollama・OpenAI以外のOpenAI互換エンドポイント（Azure OpenAI、ローカルLLMサーバー等）を使う場合は `llmConfig` とプロンプト送信部（`queryLLM` ローカル関数）を差し替えてください。
- DQNは乱数初期化・探索（ε-greedy）の影響で学習曲線の分散が大きいため、`rng(0)` で固定していても、LLMの提案値そのものが実行のたびに変わる場合は比較結果も変動します。オフラインフォールバック時は提案値が固定なので、`rng(0)` のもとでは結果は再現可能です。
- LLMがJSONオブジェクト以外の文章（前置きや説明）を含めて返すことがあるため、正規表現 `\{.*\}` で最初と最後の中括弧に挟まれた部分だけを抽出してから `jsondecode` しています。それでも解析に失敗した場合はオフライン代替値にフォールバックします。
- OpenAI APIを使う場合は課金が発生します。`OPENAI_API_KEY` を設定しない、またはローカルにOllamaを用意しない場合は常にオフラインフォールバックで完結し、追加費用はかかりません。

## アレンジ例

- `taskDescription` や `reportSystemPrompt` を変更し、LLMに他の観点（例: 探索戦略の説明、報酬設計の改善案）を尋ねる
- ベースラインと比較するハイパーパラメータの数を増やし（例: `ExperienceBufferLength`、`TargetUpdateFrequency`）、LLMへの提案依頼JSONスキーマを拡張
- `MaxEpisodes` を増やし、より長い学習でLLM提案の効果差が安定するかを確認
- LLM提案を複数回取得し、提案されたハイパーパラメータのばらつきや傾向を統計的に分析
