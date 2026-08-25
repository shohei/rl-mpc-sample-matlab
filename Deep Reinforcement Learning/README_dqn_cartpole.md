# RL Toolbox サンプル: DQNによるCart-Pole制御（連続状態空間）

`rl_gridworld_demo.m`（テーブル型Q学習・離散状態空間）を、ニューラルネットワークベースのDQN（Deep Q-Network）エージェントと連続状態空間の環境に拡張したサンプルです。カートを左右に押して、上に立てた棒（ポール）を倒さないように制御する方策を学習します。

## ファイル

- `dqn_cartpole_demo.m` — 環境構築・DQNエージェント学習・可視化を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Reinforcement Learning Toolbox
- Deep Learning Toolbox（DQNのニューラルネットワーク critic に使用）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
dqn_cartpole_demo
```

学習には数十秒程度かかります（150エピソード、手元の実行では約30〜35秒）。

## グリッドワールド版との違い

| 項目 | `rl_gridworld_demo.m` | `dqn_cartpole_demo.m` |
| --- | --- | --- |
| 状態空間 | 離散（5×5マスのセル） | 連続（`[x, dx, theta, dtheta]` の4次元） |
| 行動空間 | 離散（上下左右） | 離散（カートに -10N / +10N の力を加える） |
| 価値関数 | テーブル（`rlTable`） | ニューラルネットワーク（既定の全結合ネットワーク） |
| エージェント | `rlQAgent`（Q学習） | `rlDQNAgent`（Deep Q-Network） |
| 環境 | `createGridWorld` + `rlMDPEnv` | `rlPredefinedEnv("CartPole-Discrete")` |

## やっていること

1. **環境構築**（`rlPredefinedEnv("CartPole-Discrete")`）
   - 観測: カート位置 `x`、速度 `dx`、ポール角度 `theta`、角速度 `dtheta`（いずれも連続値）
   - 行動: カートに加える力 `-10` または `+10`（離散2値）
2. **エージェント構築**（`rlDQNAgent(obsInfo, actInfo)`）
   - 観測・行動の仕様から既定の全結合ニューラルネットワーク（256ユニット×2層 + ReLU）を持つDQN criticを自動生成
   - ネットワーク構成をコンソールに表示
3. **学習**（`train`）
   - 最大150エピソード、1エピソードあたり最大200ステップ
   - 直近20エピソードの移動平均報酬が195に達するか150エピソードで停止（古典的なCartPoleの「解けた」基準 195/200 に準拠）
   - `Plots="training-progress"` によりRL Toolbox純正の学習進捗ウィンドウをライブ表示
4. **可視化**
   - 学習曲線（エピソード報酬・移動平均報酬）を独立したFigureとして再描画
   - `plot(env)` を学習済みエージェントのシミュレーション前に呼ぶことで、カートポールが動く様子をライブアニメーション表示
   - シミュレーション結果からカート位置・ポール角度の時系列を2段のプロットで表示
5. **シミュレーション**（`sim`）と、何ステップ立て続けられたか・合計報酬をコンソール出力

## 実行結果の例

```text
Observation: CartPole States (x, dx, theta, dtheta)
Action: CartPole Action, values = [-10 10]

--- Default critic network ---
  6x1 Layer array with layers:
     1   'input_1'       Feature Input     4 features
     2   'fc_1'          Fully Connected   256 fully connected layer
     3   'relu_body'     ReLU              ReLU
     4   'fc_body'       Fully Connected   256 fully connected layer
     5   'body_output'   ReLU              ReLU
     6   'output'        Fully Connected   2 fully connected layer

--- Training complete ---
Episodes run: 150
Average reward (last 10 episodes): 76.7
Best single-episode reward: 200.0

--- Evaluation run ---
Steps balanced before termination (or cap): 94
Total reward: 88.0
```

実行すると以下のウィンドウが開きます。

- RL Toolbox純正の「Training Progress」アプリ（学習中のライブグラフ）
- `Training Progress`（学習曲線を再描画した保存用Figure）
- カートポールのライブアニメーション（`Cart Pole Visualizer`）
- `Cart-Pole State Trajectory`（カート位置・ポール角度の時系列）

## 補足・詰まりやすい点

- `sim` の戻り値 `experience` に含まれる観測データのフィールド名は `Observation.CartPoleStates`（`timeseries`、サイズ `4×1×N`）です。`squeeze` して `4×N` の行列として扱っています。グリッドワールド版の `MDPObservations` とは名前が異なる点に注意してください（フィールド名は環境の観測チャンネル名に由来します）。
- DQNは乱数初期化・探索（ε-greedy）による学習曲線の分散が大きいため、同じ `rng` シードでも実行のたびに最終的な平均報酬が変動します。上記の例では150エピソードで完全な収束（195以上）には至っていませんが、学習前半に比べて明らかに長くバランスを保てるようになっている点が確認できます。より安定した結果が欲しい場合は `MaxEpisodes` を増やしてください（目安として300〜500エピソードでほぼ確実に解けます）。
- 学習前にワークスペースが以前のセッションの変数・Figureで汚れていると、内部で古いグラフィックスオブジェクトへの参照エラー（警告として表示され学習自体は継続）が発生することがあります。本スクリプトは冒頭で `clear; close all;` を実行し、これを避けています。

## アレンジ例

- `agent.AgentOptions`（`rlDQNAgentOptions`）で `MiniBatchSize`・`TargetUpdateFrequency`・`EpsilonGreedyExploration` などを調整して学習の安定性・速度を比較
- `rlPredefinedEnv("CartPole-Continuous")` や `"DoubleIntegrator-Continuous"` に切り替えて、連続行動空間向けのエージェント（`rlDDPGAgent`、`rlTD3Agent`など）と比較
- `MaxEpisodes` を増やし、`StopTrainingValue` に到達して学習が早期終了する様子を確認
