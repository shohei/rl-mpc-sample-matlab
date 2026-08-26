# Robust Control Toolbox サンプル: 「見た目は安定」と「ロバストに安定」の違い

Robust Control Toolbox を使った、モデル不確かさを考慮した制御設計のサンプルです。`System Identification` フォルダのサンプルと同じマス・バネ・ダンパ系（`m=1, c=0.6, k=4`）を題材に、「ノミナルモデルに対しては完璧に見えるコントローラが、現実にありがちな未モデル化ダイナミクス（アクチュエータの遅れ、無視した時間遅れなど）の下では不安定化しうる」ことを、`robstab`・`wcgain`・モンテカルロシミュレーションで定量的に示します。

## ファイル

- `robust_control_uncertain_mass_spring_damper_demo.m` — 不確かさモデルの構築・素朴な設計と頑健な設計の比較・モンテカルロ検証を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Robust Control Toolbox
- Control System Toolbox（`tf`、`feedback`、`margin`、`pidtune` など）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
robust_control_uncertain_mass_spring_damper_demo
```

数秒で完了します。

## やっていること

1. **ノミナルプラント**（`tf(1,[m c k])`、`System Identification` フォルダと同じ物理系）
   - 実務では、このプラントは同フォルダの `tfest`/`ssest` のようなシステム同定で得られたモデルだと考えることができます。ただしどんなに良く同定しても、実機とモデルの間には必ず何らかの誤差（未モデル化ダイナミクス）が残ります。
2. **乗法的不確かさによる「未モデル化ダイナミクス」のモデル化**（`ultidyn` + 重み関数）
   - `Wunc(s)` を、低周波では小さく（＝そこではモデルを信用できる）、`wc=3 rad/s` 付近から大きくなる（＝それより高い周波数ではプラントの挙動は事実上未知）重みとして定義
   - `Gunc = Gnom*(1 + Wunc*Delta)`（`Delta` はゲイン1以下の任意の安定動的システム）として不確かさ付きプラント（`uss`）を構築
   - `bodemag(Gunc)` で、サンプリングされた不確かさの範囲を含むボード線図を表示
3. **素朴な設計**（`pidtune(Gnom,'PIDF',6)`）
   - ノミナルモデルだけを見て、`wc` より高い6 rad/sの閉ループ帯域を狙った積極的なPIDコントローラを設計
   - ノミナルの安定余裕（ゲイン余裕・位相余裕）は非常に良好に見える
   - しかし `robstab` で不確かさ付きプラントに対する閉ループの構造化特異値ベースのロバスト安定性余裕を計算すると、**1未満**（ロバストに安定ではない）という結果に
4. **頑健な設計**（`mixsyn` による混合感度H∞ループ整形）
   - 性能重み `W1`（低周波での目標感度特性）と、同じ不確かさ重み `Wunc` を「Tに対する重み」として与えることで、`||Wunc*T||∞ < 1` （＝この不確かさに対するロバスト安定条件そのもの）を満たすようにコントローラを直接設計
   - `robstab` で1を大きく上回るロバスト安定余裕が得られることを確認
5. **定量的な比較**（`robstab`・`wcgain`）
   - 両コントローラのロバスト安定余裕、および閉ループ感度関数のワーストケースゲイン（`wcgain`）を比較
   - 素朴な設計はロバストに安定でないため、ワーストケースゲインは無限大（`Inf`）になる
6. **モンテカルロ検証**（`usample`）
   - 不確かさの範囲から30個のプラント実現をサンプリングし、それぞれに両コントローラを適用したときの閉ループ極を確認
   - ステップ応答を重ね描きし、実際に不安定化するサンプル数を集計

## 実行結果の例

```text
Nominal plant: 1 / (m*s^2 + c*s + k), m=1.00, c=0.60, k=4.00

--- Naive controller (aggressive PID, ignores uncertainty) ---
Nominal gain margin: Inf, phase margin: 64.5 deg (looks great on paper)
Robust stability margin (robstab): 0.55 (< 1 means NOT robustly stable)

--- Robust controller (mixsyn H-infinity, shaped against Wunc) ---
mixsyn achieved closed-loop norm gamma = 0.639 (<1 => robust stability guaranteed)
Robust stability margin (robstab): 2.35

--- Comparison ---
                                  Naive PID Robust (mixsyn)
robstab margin (>1 = robust)           0.55           2.35
Worst-case |S| gain (wcgain)            Inf           1.65
(worst-case gain is Inf for the naive controller because it is not robustly stable at all)

--- Monte Carlo check over 30 sampled plants from the uncertainty set ---
Naive PID:        5 / 30 samples unstable
Robust (mixsyn):  0 / 30 samples unstable
```

実行すると以下のウィンドウが開きます。

- `Uncertainty Weight and Sampled Plants`（不確かさ重み `Wunc` のボード線図と、サンプリングされた不確かさ付きプラントの帯）
- `Monte Carlo Step Response Comparison`（素朴な設計・頑健な設計それぞれについて、30通りのプラント実現に対するステップ応答の重ね描き。素朴な設計では発散する応答が混ざることを確認できます）

## 補足・詰まりやすい点

- **ここが本サンプルの核心です。** 素朴なPIDコントローラは、ノミナルモデルに対する古典的な安定余裕（ゲイン余裕 `Inf`、位相余裕 `64.5°`）だけを見ると非常に優秀に見えます。しかし、`wc=3 rad/s` 付近から先のプラントの振る舞いは（未モデル化ダイナミクスのため）実際には分からないという前提を踏まえると、`robstab` はこの設計が**ロバストに安定ではない**（余裕が1未満）ことを明らかにします。実際、モンテカルロ検証では30個の妥当なプラント実現のうち5個で閉ループが不安定になりました。ノミナル余裕だけを見て「安定余裕は十分」と判断するのは、モデル化されていない不確かさがある実システムでは危険であることを示しています。
- `mixsyn(G, W1, W2, W3)` の3つの重みは、それぞれ感度関数S・制御入力KS・相補感度関数Tに対応します（`W1`→S、`W2`→KS、`W3`→T）。本サンプルでは制御入力の重み `W2` は使わず（`[]`）、不確かさ重みをそのまま `W3` の位置（Tへの重み）に渡すことで、「H∞混合感度設計 = 明示的なロバスト安定制約付きループ整形」という対応関係を直接利用しています。
- 素朴なコントローラの `wcgain` が `Inf` になるのは計算上の不具合ではなく、「ロバストに安定でない系にはワーストケースゲインという概念自体が意味をなさない（不確かさの範囲内に閉ループを不安定にする実現が存在する）」ことを表す、正しい結果です。
- `pidtune` は既定では純微分（`Tf=0`）のPIDを返すことがあり、`wcgain` はプロパーでない（`s→∞` でゲインが有限でない）モデルを扱えません。本サンプルでは `'PIDF'`（微分にローパスフィルタ付き）を指定し、この問題を避けています。
- 乱数シードは `rng(0)` で固定していますが（`usample` のサンプリングに影響）、結果はMATLAB・Robust Control Toolboxのバージョンにより多少変動する場合があります。

## アレンジ例

- `wc`（不確かさが効き始める周波数）を変え、素朴な設計の狙う帯域とどれだけ近づくとロバスト安定性が破綻するかを確認
- `musyn`（構造化特異値に基づくμ synthesis、`[K,~,info] = musyn(...)`）を使い、`mixsyn` よりも不確かさの構造をより厳密に扱った設計と比較
- `System Identification` フォルダのサンプルで実際にデータから推定した `sysTF`/`sysSS` をノミナルプラントとして使い、「同定誤差そのもの」を不確かさとして扱う、より実践的なワークフローに拡張
- 乗法的不確かさに加えて、加法的不確かさ（`Gnom + Wadd*Delta`）や出力側の不確かさなど、異なる不確かさ構造で同様の比較を行う
- `Crobust` を実際のロバストなアクチュエータ飽和・センサノイズを加えたSimulinkモデルでシミュレーションし、時間領域でも頑健性を確認
