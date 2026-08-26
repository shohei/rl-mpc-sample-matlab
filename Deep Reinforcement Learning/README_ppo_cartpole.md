# RL Toolbox サンプル: PPOによるCart-Pole制御（連続行動空間）

`dqn_cartpole_demo.m`（DQN・離散行動空間）と同じCart-Pole課題を、Proximal Policy Optimization（PPO）エージェントと連続行動空間（カートに加える力を連続値で指定）に拡張したサンプルです。DQNが「オフポリシー・価値ベース・離散行動」であるのに対し、PPOは「オンポリシー・方策勾配（アクター・クリティック）・連続行動」という異なるアプローチを取ります。

## ファイル

- `ppo_cartpole_demo.m` — 環境構築・既定ハイパーパラメータでの学習・チューニング後のハイパーパラメータでの学習・比較・可視化を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Reinforcement Learning Toolbox
- Deep Learning Toolbox（PPOのアクター・クリティックのニューラルネットワークに使用）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
ppo_cartpole_demo
```

学習には1分程度かかります（既定設定300エピソード＋チューニング後設定最大500エピソードの2回分）。

## グリッドワールド版・DQN版との違い

| 項目 | `rl_gridworld_demo.m` | `dqn_cartpole_demo.m` | `ppo_cartpole_demo.m` |
| --- | --- | --- | --- |
| 状態空間 | 離散 | 連続（4次元） | 連続（4次元） |
| 行動空間 | 離散（上下左右） | 離散（-10N / +10N） | **連続**（-10〜+10Nの任意の値） |
| 学習方式 | オフポリシー（Q学習） | オフポリシー（DQN、リプレイバッファ） | **オンポリシー**（PPO、方策勾配） |
| ネットワーク構成 | テーブル | 価値関数のみ（Critic） | **アクター（方策）+ クリティック（価値関数）** |
| エージェント | `rlQAgent` | `rlDQNAgent` | `rlPPOAgent` |

## やっていること

1. **環境構築**（`rlPredefinedEnv("CartPole-Continuous")`）
   - 観測: カート位置・速度・ポール角度・角速度（`dqn_cartpole_demo.m` と同じ）
   - 行動: カートに加える連続的な力（-10〜+10 N）
2. **既定ハイパーパラメータでのPPO学習**（`rlPPOAgent(obsInfo, actInfo)`）
   - 観測・行動の仕様から、連続ガウス方策（平均をtanh+スケーリング、標準偏差をSoftplusで出力）を持つアクターと、状態価値関数のクリティックを自動生成
   - 最大300エピソードで学習するが、**この課題・この設定では収束しない**（直近10エピソードの平均報酬が -41.0 で終了）ことを確認
3. **チューニング後のハイパーパラメータでのPPO学習**
   - `ExperienceHorizon`（1回の方策更新に使う経験の長さ）を512→1024、`MiniBatchSize` を128→256、`NumEpoch`（1バッチあたりの更新回数）を3→5、`EntropyLossWeight`（探索を促すエントロピー正則化の重み）を0.01→0.02に変更
   - アクター・クリティック両方の学習率を1e-3に設定
   - 同じ最大300エピソード相当の学習で、直近10エピソードの平均報酬が大きく改善することを確認
4. **比較**
   - エピソード数・直近10エピソードの平均報酬・最高エピソード報酬を表形式でコンソール出力
   - 両設定の移動平均報酬の学習曲線を1つのFigureに重ねて表示
5. **チューニング後エージェントの評価**（`sim`）
   - `plot(env)` でカートポールが動く様子をライブアニメーション表示
   - カート位置・ポール角度・実際に加えた力（連続値）の時系列を3段のプロットで表示

## 実行結果の例

```text
Observation: CartPole States (x, dx, theta, dtheta)
Action: CartPole Action, range = [-10, 10] N (continuous)

=== Training PPO agent (default hyperparameters) ===
--- Default actor network ---
  10×1 Layer array with layers:
     1   'input_1'       Feature Input     4 features
     2   'fc_1'          Fully Connected   256 fully connected layer
     3   'relu_body'     ReLU              ReLU
     4   'fc_body'       Fully Connected   256 fully connected layer
     5   'body_output'   ReLU              ReLU
     6   'fc_mean'       Fully Connected   1 fully connected layer
     7   'tanh'          Tanh              Hyperbolic tangent
     8   'scale'         Scaling           Scaling
     9   'fc_std'        Fully Connected   1 fully connected layer
    10   'std'           Softplus          Softplus

=== Training PPO agent (tuned hyperparameters) ===

--- Comparison ---
                                  Default        Tuned
Episodes run                          300          500
Avg reward (last 10 ep.)            -41.0        182.1
Best episode reward                  38.8        199.3

--- Evaluation run (tuned PPO agent) ---
Steps balanced before termination (or cap): 200
Total reward: 197.1
```

実行すると以下のウィンドウが開きます。

- RL Toolbox純正の「Training Progress」アプリ（既定設定・チューニング後設定それぞれの学習中のライブグラフ、計2回）
- `Default vs. Tuned PPO Training Progress`（両設定の学習曲線を重ねた比較Figure）
- カートポールのライブアニメーション（`Cart Pole Visualizer`、チューニング後エージェントの評価シミュレーション）
- `PPO Cart-Pole State and Action Trajectory`（カート位置・ポール角度・力の時系列を3段で表示）

## 補足・詰まりやすい点

- **既定のPPOハイパーパラメータではこの課題を解けませんでした（直近10エピソード平均報酬 -41.0）。** `CartPole-Continuous` 環境は、倒れずにいられれば1ステップごとに+1、倒れると-50のペナルティを与える報酬設計（`env.RewardForNotFalling` / `env.PenaltyForFalling`）のため、方策が十分学習される前に何度も早期に倒れると平均報酬は大きく負になります。PPOはオンポリシー手法であるため、1回の方策更新に使う経験の量（`ExperienceHorizon`・`MiniBatchSize`）や1バッチあたりの更新回数（`NumEpoch`）が少なすぎると、DQNのような経験再生ベースの手法に比べて学習が不安定・停滞しやすい傾向があります。本サンプルはこれをそのまま示しており、「PPOを使えば自動的にうまくいく」わけではなく、オンポリシー手法特有のハイパーパラメータ調整が重要であることを表しています。
- チューニング後の設定でも、直近10エピソードの移動平均報酬（182.1）は目標の195にはわずかに届きませんでしたが、最高エピソード報酬は199.3、評価シミュレーションでは200ステップ全てバランスを保ち報酬197.1を達成しており、実質的にはほぼ解けている状態です。PPOはエピソードごとの分散が大きいため、移動平均だけでなく最良エピソードや評価時の挙動も合わせて確認することが重要です。
- `experience.Action` に含まれる行動データのフィールド名は `CartPoleAction`（`timeseries`、サイズ `1×1×N`）です。DQN版で使った `experience.Observation.CartPoleStates` と同様、フィールド名は環境のチャンネル名に由来します。
- 乱数シードは `rng(0)` で固定していますが、2回の学習（既定設定→チューニング後設定）は同一スクリプト内で連続して実行されるため、チューニング後の学習は既定設定の学習で消費された乱数列の続きから始まります。学習結果（学習曲線・最終的な平均報酬）は環境やMATLABバージョン、実行順序により多少変動する場合があります。

## アレンジ例

- `ExperienceHorizon`・`MiniBatchSize`・`NumEpoch`・`EntropyLossWeight` を1つずつ既定値に戻し、どのハイパーパラメータが収束の成否に最も効いているかを切り分ける
- `MaxEpisodes` をさらに増やし、既定ハイパーパラメータでも十分な時間をかければ収束するかを確認
- `rlPPOAgentOptions` の `ClipFactor`（クリッピングの範囲）や `GAEFactor`（Generalized Advantage Estimationの割引率）を変更し、学習の安定性への影響を確認
- `rlTRPOAgent`（Trust Region Policy Optimization）に差し替え、同じ連続行動空間・オンポリシー方策勾配でもPPOとの違いを比較
- `llm_guided_dqn_cartpole_demo.m` と同様に、LLMにPPOのハイパーパラメータを提案させる形に拡張
