# Predictive Maintenance Toolbox サンプル: 指数劣化モデルによる残存耐用年数（RUL）推定

Predictive Maintenance Toolbox の中核ワークフローである、劣化モデルによる残存耐用年数（RUL: Remaining Useful Life）推定のサンプルです。振動信号のRMSトレンドのような「状態指標（condition indicator）」を模した合成データを、既知の指数劣化則からノイズ付きで生成し、実際には未知のはずの物理パラメータを知らないふりをして、データだけからRULを推定します。

## ファイル

- `predictive_maintenance_exponential_rul_demo.m` — 母集団データ生成・モデル学習・逐次RUL予測・フリート全体での精度検証を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Predictive Maintenance Toolbox

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
predictive_maintenance_exponential_rul_demo
```

数秒で完了します。

## やっていること

1. **正解の劣化則の定義**（`y(t) = phi + theta*exp(beta*t) + noise`）
   - `theta`（初期劣化率）・`beta`（劣化の成長率）は機体ごとにばらつく（個体差）ものとし、`phi`（オフセット）は共通
   - 状態指標が固定の故障しきい値（`failThreshold = 3.0`）を超えた時点を「故障」とする
2. **過去の故障履歴データ（フリート）の生成**（15台分の寿命全体のトレンド）
   - 各機体の劣化トレンドを故障まで丸ごとシミュレーションし、`iddata` ならぬテーブル（`Time`・`Condition`列）としてまとめる
3. **母集団レベルの劣化モデルの学習**（`exponentialDegradationModel` + `fit`）
   - 15台分の履歴データから、`theta`・`beta`・`phi` の母集団分布（事前分布）を推定
   - 推定された母集団パラメータの平均値を、真の生成分布の平均と比較
4. **新しい機体のRULを逐次予測**（`update` + `predictRUL`）
   - 学習済みの母集団パラメータを事前分布として持つ、新規機体用のモデルインスタンスを作成
   - その機体の観測データを少しずつ（時刻を進めながら）`update` に与え、そのたびに `predictRUL` でRULの点推定値と90%信頼区間を取得
   - 真のRUL（このサンプルでは既知）と比較し、データが増えるにつれて信頼区間がどう変化するかを確認
   - 最終時点でのRULの確率密度関数（`predictRUL` の3番目の出力）も表示
5. **フリート全体でのRUL推定精度の検証**（15台の未知機体、寿命の30%/50%/70%/90%時点で予測）
   - 各観測割合ごとに、真のRULとの絶対誤差の中央値、および真のRULが90%信頼区間内に収まった割合（カバレッジ）を集計

## 実行結果の例

```text
Training fleet lifetimes: [53 70 50 79 88 46 66 67 70 66 90 70 78 74 68]

--- Fitted population parameters vs. ground truth ---
              True mean     Fitted
theta            0.0500     0.0437
beta             0.0600     0.0639
phi              0.0000    -0.0731

--- Streaming RUL prediction for one held-out test unit (true lifetime = 87) ---
     t     estRUL      ciLow     ciHigh    trueRUL
    22      44.08      20.22      72.25         65
    36      37.84      12.85      67.03         51
    50      60.58      31.65      98.82         37
    64      16.96       2.55      36.02         23
    78       8.51       0.37      24.56          9

--- Fleet-level RUL accuracy vs. how much of each unit's life is observed (15 units) ---
 Observed fraction  Median abs. error  CI coverage
               30%            11.4 h          93%
               50%             9.9 h         100%
               70%            10.1 h         100%
               90%             9.4 h         100%
```

実行すると以下のウィンドウが開きます。

- `Historical Fleet Degradation`（学習に使った15台分の故障までのトレンド）
- `Test Unit: Condition Indicator`（1台の新規機体の状態指標トレンドと予測時点）
- `RUL Prediction Over Time`（RUL点推定値・真のRUL・信頼区間の帯を時系列で表示）
- `Final RUL Probability Density`（最終予測時点でのRULの確率密度関数）

## 補足・詰まりやすい点

- **信頼区間のカバレッジ（93〜100%）はおおむね妥当ですが、絶対誤差の中央値は観測割合を増やしても劇的には縮まりません（11.4h → 9.9h → 10.1h → 9.4h）。** これは、母集団の事前分布（`ThetaVariance`・`BetaVariance`）がそれなりに確信度の高い（分散が小さい）ため、個々の機体のわずかなノイズ付きデータだけでは事後分布が母集団の平均から大きく動かない「ベイズ的な縮小（shrinkage）」が起きているためです。一方、1台の機体をより細かく（5段階で）逐次追跡した `Streaming RUL prediction` の結果を見ると、故障が近づく（データが十分蓄積される）ほど推定値・信頼区間ともに真のRULへ収束していく様子が確認できます。母集団の事前分布が強いほど、個体差が最終的に顕在化するまで予測が母集団平均寄りになる、という劣化モデルの基本的な性質を表しています。
- `update` を短い観測ウィンドウ（ノイズが乗った数点のデータ）に対して呼び出すと、`predmaint:analysis:warnExpDataAndPhiNotMatch`（「データが指数モデルの前提を満たしていない」）という警告が出ることがあります。ごく短い区間ではノイズにより見かけ上単調増加でなくなることがあるための想定内の警告のため、本スクリプトでは冒頭で `warning('off', ...)` により抑制し、`onCleanup` で終了時に元の警告設定へ戻しています。
- `exponentialDegradationModel` はハンドルクラスですが `matlab.mixin.Copyable` ではないため `copy()` できず、また `restart()` はループ内で使い回すと `CurrentLifeTimeValue` が正しくリセットされない場合があります。本スクリプトでは、学習済みモデルの `Theta`・`ThetaVariance`・`Beta`・`BetaVariance`・`Rho`・`Phi`・`NoiseVariance` を新しいモデルインスタンスの事前分布として明示的に渡す（`clonePriorModel` ローカル関数）ことで、機体ごとに独立したクリーンな状態から予測を開始しています。
- `predictRUL` にしきい値（`failThreshold`）を渡す前に、必ず `update(mdl, data)` でその機体の観測データをモデルへ反映しておく必要があります（`update` を呼ばずに `predictRUL(mdl, data)` の形でテーブルを直接渡す使い方は、本サンプルの用途ではエラーになります）。
- 乱数シードは `rng(0)` で固定していますが、結果はMATLAB・Predictive Maintenance Toolboxのバージョンにより多少変動する場合があります。

## アレンジ例

- `thetaStd`・`betaStd`（個体差の大きさ）を増やし、事前分布の確信度が下がることで、個々の機体データがより早く効いてくる（ベイズ的縮小が弱まる）様子を確認
- `linearDegradationModel` に差し替えて、同じ合成データに対する当てはまりや予測傾向の違いを比較
- `pairwiseSimilarityModel` などの類似度ベースモデルを使い、指数劣化モデルとは異なるアプローチでのRUL推定を試す
- フリートのサイズ（`nTrain`）を変え、母集団パラメータの推定精度・信頼区間のカバレッジがどう変化するかを確認
- 状態指標を、`Wavelet` フォルダのサンプルのようにRMSやスペクトル特徴量として実際の振動波形から抽出する処理に置き換え、より実データに近いパイプラインに拡張
