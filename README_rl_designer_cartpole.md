# Reinforcement Learning Designer サンプル: Cart-Pole（ノーコード）

Reinforcement Learning Designerは、コードを書かずにGUI操作だけで強化学習エージェントの作成・学習・シミュレーションができるアプリです。`dqn_cartpole_demo.m`（`rlDQNAgent`・`train`をスクリプトで直接呼び出す方式）と同じCart-Pole問題を、今回はアプリのボタン操作だけで解きます。

GUIアプリはスクリプトだけで最後まで自動操作することはできないため、本サンプルは「スクリプトでできる部分（環境をワークスペースに用意してアプリを開く）」と「GUIで行う部分（インポート・エージェント作成・学習・シミュレーション）」に分かれています。

## ファイル

- `rl_designer_cartpole_demo.m` — Cart-Pole環境をベースワークスペースに作成し、Reinforcement Learning Designerアプリを起動するスクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Reinforcement Learning Toolbox
- Deep Learning Toolbox（DQNエージェントに使用）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
rl_designer_cartpole_demo
```

コンソールに環境情報が表示された後、Reinforcement Learning Designerアプリのウィンドウが開きます（既に開いている場合はそのウィンドウがフォーカスされます）。

## アプリでの操作手順

アプリが開いたら、以下の手順で進めます（メニュー名は概ね共通ですが、MATLABのバージョンにより多少表記が異なる場合があります）。

1. **環境のインポート**
   ツールストリップの「Environment」セクションから「New」→「Import from MATLAB workspace」を選び、ワークスペース変数の一覧からスクリプトが作成した `env`（`CartPoleDiscreteAction`）を選択してインポートします。
2. **エージェントの作成**
   「Agent」セクションの「New」をクリックし、エージェントの種類として **DQN** を選びます。ネットワーク構成（既定の全結合ネットワークでよい）やエージェントオプション（割引率・探索率など、`dqn_cartpole_demo.m`の`rlDQNAgentOptions`に相当）をダイアログで設定し、作成します。
3. **学習オプションの設定と学習**
   「Train」タブに切り替え、最大エピソード数・エピソードあたり最大ステップ数・停止条件（平均報酬など、`rlTrainingOptions`に相当）を設定してから「Train」ボタンを押します。学習中は報酬の推移がアプリ内にライブ表示されます（スクリプト版で`Plots="training-progress"`を指定したときと同じグラフです）。
4. **学習済みエージェントのシミュレーション**
   学習が終わったら「Simulate」タブで学習済みエージェントを選び、シミュレーションを実行してCart-Poleを実際に制御する様子を確認します。
5. **エクスポート（任意）**
   「Export」から、学習済みエージェントをMATLABワークスペースの変数としてエクスポートできます。エクスポートしたエージェントは`sim(env, exportedAgent)`のように、通常のスクリプトから`dqn_cartpole_demo.m`と同じ関数で扱えます。セッション全体（環境・複数エージェント・学習結果）を`.mat`ファイルとして保存し、後で`reinforcementLearningDesigner("セッションファイル.mat")`のように再度開くこともできます。

## `dqn_cartpole_demo.m`との違い

| | `dqn_cartpole_demo.m`（スクリプト） | `rl_designer_cartpole_demo.m`（GUI） |
| --- | --- | --- |
| エージェント作成 | `rlDQNAgent(obsInfo, actInfo)` | アプリの「New Agent」ダイアログ |
| 学習オプション | `rlTrainingOptions(...)` | 「Train」タブのフォーム |
| 学習の実行 | `train(agent, env, trainOpts)` | 「Train」ボタン |
| 結果の確認 | `sim`＋自作のプロット・アニメーション | アプリ内蔵の「Simulate」ビュー |
| 再現性 | スクリプトなので設定がそのままコードに残る | GUI操作なので、必要なら「Export」でコードやセッションとして保存する必要がある |
| 向いている用途 | 自動化・繰り返し実行・細かいチューニング | 初めてRLを試す・素早く試行錯誤する・GUIでネットワーク構成を視覚的に確認する |

## 補足

- アプリはMATLABデスクトップ上のウィンドウとして開くため、この操作自体はスクリプトから自動化できません（本サンプルは「環境を用意してアプリを開く」ところまでを担当します）。
- アプリで作成したエージェントや学習結果をコードとして再利用したい場合は、「Export」機能でワークスペースまたは`.mat`セッションファイルに書き出してください。
- 同じCart-Pole問題を先にスクリプト版（`dqn_cartpole_demo.m`）で試しておくと、アプリのどの操作がコードのどの行に対応するかが分かりやすくなります。

## アレンジ例

- インポートする環境を`rl_gridworld_demo.m`で使った`createGridWorld`ベースの環境や、`rocket_landing_demo.m`のカスタム`rlFunctionEnv`に差し替えて、GUIでも学習できるか試す
- DQN以外のエージェント（PPO、SACなど）をアプリ上で作成し、Cart-Poleでの学習曲線を比較する
- アプリの「Export」で得たエージェントを使い、`dqn_cartpole_demo.m`のプロット・アニメーションコードで可視化する
