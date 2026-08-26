# Predictive Maintenance Toolbox サンプル: 軸受（ベアリング）故障の異常検知

Predictive Maintenance Toolbox を使った、振動信号からのベアリング故障検知サンプルです。[`predictive_maintenance_exponential_rul_demo.m`](README_predictive_maintenance_exponential_rul.md) が「あとどれくらい使えるか（RUL）」を扱うのに対し、本サンプルは「今、異常・故障が起きているかどうか」を振動データから検知する、より診断寄りのワークフローを扱います。

外輪（アウターレース）に局所的な欠陥がある軸受は、欠陥に転動体が当たるたびに衝撃振動を発生し、それが軸受固有の「特徴故障周波数（BPFO）」の周期で構造共振を励起します。この衝撃振動は生の時間波形ではノイズに埋もれて目視では分かりませんが、共振帯域のエンベロープスペクトルには明確なピークとして現れます。

## ファイル

- `predictive_maintenance_bearing_fault_detection_demo.m` — 特徴故障周波数の算出・健全時と故障時の比較・検知しきい値の較正と検証を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Predictive Maintenance Toolbox（`bearingFaultBands`、`faultBandMetrics`）
- Signal Processing Toolbox（`envspectrum`）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
predictive_maintenance_bearing_fault_detection_demo
```

数秒で完了します。

## やっていること

1. **軸受の物理諸元から特徴故障周波数帯を算出**（`bearingFaultBands`）
   - 転動体数・転動体径・ピッチ径・接触角と軸回転数から、外輪傷（BPFO）・内輪傷（BPFI）・転動体傷（BSF）・保持器傷（FTF）の4つの特徴周波数と、その周辺の周波数帯を算出
2. **健全時・外輪傷故障時の振動信号を模擬生成**
   - 健全信号: 軸回転の1次成分 + 広帯域ノイズ
   - 故障信号: 健全信号 + BPFO周期で発生する（構造共振を励起する）減衰振動のインパルス列（転動体と傷が当たるたびに衝撃が発生し、共振がリング・ダウンする様子を模擬）
   - 生の時間波形を比較すると、故障による衝撃はノイズに埋もれて目視では分かりにくいことを確認
3. **エンベロープスペクトルとフォールトバンドメトリクスによる比較**（`envspectrum` + `faultBandMetrics`）
   - 共振帯域（2-4 kHz）でエンベロープスペクトルを計算し、健全時・故障時を重ねて表示 → 故障時はBPFO付近に明確なピークが出現
   - 4つの故障周波数帯それぞれのバンドパワーを比較し、**外輪傷帯（1Fo）だけ**が大きく増加し、他の帯（内輪・転動体・保持器）はほぼ変化しないことを確認 → 単なる「異常」ではなく「外輪傷」という具体的な故障箇所まで特定できていることを示す
4. **検知しきい値の較正**（健全データのみから）
   - 健全データ20本分のBPFOバンドパワーの平均・標準偏差から、しきい値（平均+4σ）を設定
5. **検証**
   - 新たに生成した健全データ20本での誤報率（false-alarm rate）
   - 故障の重大度（インパルス振幅）を0〜1.2まで振った各水準で15本ずつ試行し、検知率がどう変化するかを確認

## 実行結果の例

```text
Characteristic fault frequencies (shaft speed = 25 Hz):
  1Fo      84.60 Hz  (band 83.35 - 85.85 Hz)
  1Fi     140.40 Hz  (band 139.15 - 141.65 Hz)
  1Fb      47.30 Hz  (band 46.05 - 48.55 Hz)
  1Fc       9.40 Hz  (band 8.15 - 10.65 Hz)
(1Fo = outer race, 1Fi = inner race, 1Fb = ball/roller, 1Fc = cage)

--- Fault-band power: healthy vs. faulty (which band lights up?) ---
Band      Healthy power   Faulty power      Ratio
1Fo              0.0169         0.2035      12.0x
1Fi              0.0105         0.0170       1.6x
1Fb              0.0128         0.0215       1.7x
1Fc              0.0160         0.0150       0.9x
=> Only the outer-race band (1Fo = BPFO) grows sharply; the fault is correctly localized.

--- Detection threshold (calibrated on 20 healthy-only signals) ---
BPFO band power: mean = 0.0117, std = 0.0033 -> threshold = 0.0248

False-alarm rate on 20 fresh healthy signals: 0% (0 of 20)

--- Detection rate vs. fault severity (15 trials each) ---
  Severity Detection rate
      0.00             0%
      0.10             0%
      0.20             0%
      0.30           100%
      0.50           100%
      0.80           100%
      1.20           100%
```

実行すると以下のウィンドウが開きます。

- `Raw Vibration Signals`（健全時・故障時の生の時間波形。目視では故障が分かりにくいことを確認）
- `Envelope Spectrum`（健全時・故障時のエンベロープスペクトル。4つの特徴周波数に破線を表示）
- `Detection Rate vs. Fault Severity`（故障の重大度に対する検知率のカーブ）

## 補足・詰まりやすい点

- **検知率は重大度0.2から0.3の間で0%→100%へ急激に切り替わっており、「なめらかに劣化を検知できる」わけではありません。** これは、しきい値ベースの異常検知が本質的に持つ性質です。故障による衝撃がノイズフロアを十分に超えるまでは（重大度0.1〜0.2）ほぼ検知不能で、超えた瞬間（重大度0.3以上）にはほぼ確実に検知できるようになります。実運用では、しきい値をどこに置くか（誤報率と早期検知のトレードオフ）、あるいは複数の特徴量・複数時刻のデータを組み合わせたトレンド監視によって、この「急激な切り替わり」の手前をどう捉えるかが重要な設計判断になります。
- **4つの故障周波数帯のうち外輪傷帯（1Fo）だけが顕著に増加した**（12.0倍）のに対し、他の帯（1Fi・1Fb・1Fc）はほぼ変化しませんでした（0.9〜1.7倍）。これは、本サンプルが外輪傷のみをシミュレートしているためで、`faultBandMetrics` が単なる「何かおかしい」ではなく「どこが壊れているか」まで切り分けられることを示しています。もし複数の帯が同時に増加していたら、複合的な故障や、傷ではなく別の要因（アンバランス、軸のミスアライメントなど）を疑う必要があります。
- `envspectrum` の `Band` 名前-値引数は、衝撃が励起する構造共振の周波数帯に合わせて指定する必要があります（既定値は `[fs/4, fs*3/8]` で、本サンプルの共振周波数3000 Hzには合わないため `[2000 4000]` を明示的に指定しています）。実データでは、健全時のスペクトルやスペクトログラム（あるいは `kurtogram`）を見て、衝撃成分が最も強く現れる帯域を事前に特定するのが一般的です。
- しきい値は「平均+4σ」という単純な統計的較正ですが、健全データの母数（本サンプルでは20本）が少ないと標準偏差の推定自体が不安定になりえます。実運用ではより多くの健全運転データ、季節や負荷条件による変動も考慮した較正が必要です。
- 乱数シードは `rng(0)` で固定していますが、結果はMATLAB・Predictive Maintenance/Signal Processing Toolboxのバージョンにより多少変動する場合があります。

## アレンジ例

- `simulateBearingVibration` の故障モードを内輪傷（BPFI）や転動体傷（BSF）に変更し、`faultBandMetrics` が正しくその帯だけを検知できるか確認
- `gearMeshFaultBands` を使い、歯車のかみ合い周波数に基づく故障検知に拡張
- しきい値較正を「平均+kσ」ではなく、健全データのパーセンタイル（例: 99パーセンタイル）や、`Statistics and Machine Learning Toolbox` の外れ値検出手法（`isanomaly`、`ocsvm` など）に置き換えて比較
- 検知率だけでなく、重大度ごとのバンドパワーの分布を箱ひげ図で可視化し、しきい値との関係を視覚的に確認
- 本サンプルで検知した「故障あり」のデータを、`predictive_maintenance_exponential_rul_demo.m` のように時系列で追跡し、検知後にRUL推定へ引き継ぐ一連のパイプラインに拡張
