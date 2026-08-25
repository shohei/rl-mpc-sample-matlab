# System Identification Toolbox サンプル: マス・バネ・ダンパ系のモデル推定

System Identification Toolbox を使った最小構成のサンプルです。2次のマス・バネ・ダンパ系（既知の物理パラメータを持つ「正解」システム）にランダム2値入力を加えてシミュレーションし、出力に測定ノイズを加えたデータだけから、物理パラメータを知らないふりをしてモデルを推定します。4つの異なるモデル構造を検証データで比較し、ノイズの入り方とモデル構造の対応がフィットの良し悪しに直結することを確認します。

## ファイル

- `system_identification_mass_spring_damper_demo.m` — データ生成・4種類のモデル推定・検証・比較を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- System Identification Toolbox
- Control System Toolbox（`tf`、`c2d`、`lsim`、`bode`、`damp`）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
system_identification_mass_spring_damper_demo
```

数秒で完了します。

## やっていること

1. **正解システムの定義**（`tf(1, [m c k])` → `c2d`）
   - `m=1, c=0.6, k=4` の2次系（固有振動数 2 rad/s、減衰比 0.15 の減衰振動系）
   - サンプル時間 `Ts=0.05` s でゼロ次ホールド離散化し、シミュレーション用の「真のプラント」とする
2. **推定用・検証用データの生成**（`idinput` + `lsim` + 測定ノイズ）
   - ランダム2値信号（`idinput(N)`、既定の `'rbs'`）を入力として、独立な乱数系列で推定用・検証用の2セットを生成
   - 出力に標準偏差0.01の白色ノイズを加算（= 純粋な測定ノイズ。動特性そのものにはノイズが入らない設定）
   - `iddata` オブジェクトにまとめる
3. **4種類のモデル構造で推定**
   - `tfest(dataEst, 2, 0)` — 2極0零点の連続時間伝達関数（物理モデルに対応する構造）
   - `ssest(dataEst, 2)` — 2次のブラックボックス状態空間モデル
   - `arx(dataEst, [2 2 1])` — 離散多項式モデル（"equation-error" ノイズモデル）
   - `oe(dataEst, [2 2 1])` — 離散多項式モデル（"output-error" ノイズモデル）
4. **検証データでの評価**（`compare`）
   - 4モデルの当てはまり（NRMSEフィット%）を表とバーグラフで比較
   - 検証データの実測出力と各モデルのシミュレーション出力を時系列で重ねて表示
5. **物理パラメータの復元確認**（`damp`）
   - `tfest`・`ssest` から推定した固有振動数・減衰比を、真の値（`damp(Gc)`）と比較
   - `bode` で真のシステムと `tfest`・`ssest` モデルの周波数応答を重ねて表示

## 実行結果の例

```text
True system: 1 / (m*s^2 + c*s + k), m=1.00, c=0.60, k=4.00
  natural frequency = 2.000 rad/s, damping ratio = 0.150

--- Validation fit (NRMSE %, higher is better) ---
tfest (TF, 2 poles)                91.2%
ssest (state-space, order 2)       90.0%
arx([2 2 1])                        5.7%
oe([2 2 1])                        91.2%

--- Identified vs. true natural frequency / damping ratio ---
                         wn (rad/s)       zeta
True system                   2.000      0.150
tfest estimate                1.999      0.147
ssest estimate                1.989      0.145
```

実行すると以下のウィンドウが開きます。

- `Estimation Data`（推定用の入力・出力データ、System ID Toolbox純正の `plot(iddata)` 表示）
- `Validation Fit Comparison`（4モデルの検証フィット%を比較する棒グラフ）
- `Measured vs. Simulated Output`（検証データの実測値と各モデルのシミュレーション結果の重ね描き）
- `Bode Comparison`（真のシステムと `tfest`・`ssest` モデルのボード線図）

## 補足・詰まりやすい点

- **`arx` のフィットが極端に低い（5.7%）のは次数の選び方の問題ではなく、ノイズモデルの前提が合っていないためです。** `arx([2 2 1])` は「ノイズが入力と同じ動特性を通って出力に加わる（equation-error）」という前提のモデルで、真のノイズ（出力に直接加わる測定ノイズ）とは構造が異なります。一方 `oe([2 2 1])` は「ノイズは動特性の後段で出力に直接加わる（output-error）」という前提で、今回のデータ生成過程と一致するため、`tfest`・`ssest` と同等の高いフィットが得られます。実データでモデル構造を選ぶ際は、モデルの次数だけでなくノイズがどこに入るかも重要な検討事項です。
- `compare` の戻り値 `fit`（NRMSEフィット%）は、複数モデルを渡すとモデルごとの値を持つセル配列で返ります。本スクリプトでは `cellfun` で数値配列に変換しています。
- `damp` は複素共役極を持つ系に対して、共役の各極に対応する行を返す（同じ値が2行）ため、最初の行 `(1)` だけを使っています。
- 乱数シードは `rng(0)` で固定していますが、推定結果（特にフィット%の細かい値）はMATLABバージョンやToolboxのバージョンにより多少変動する場合があります。

## アレンジ例

- `noiseStd` を大きくして測定ノイズを増やし、モデル構造ごとのロバスト性の違いを確認
- 入力信号を `idinput(N, 'prbs', ...)`（周期的擬似ランダム2値信号）や `'sine'`（正弦波掃引）に変更し、励振信号の種類が推定精度に与える影響を比較
- `tfest`/`ssest` の次数（極の数）をわざと過小・過大に設定し、`compare` のフィットや推定されたボード線図がどう変化するかを観察
- 推定したモデル（`sysTF` や `sysSS`）を `MPC` フォルダの設計フローに渡し、実測データから得たプラントモデルでMPCコントローラを設計する流れに拡張
