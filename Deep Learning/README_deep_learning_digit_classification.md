# Deep Learning Toolbox サンプル: 手書き数字認識（CNN）

Deep Learning Toolboxに付属する手書き数字画像データセットを使い、簡単な畳み込みニューラルネットワーク（CNN）で0〜9の数字を分類します。深層学習の「Hello World」的な定番サンプルです。

## ファイル

- `deep_learning_digit_classification_demo.m` — データ読み込み・CNN定義・学習・評価・可視化を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Deep Learning Toolbox

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
deep_learning_digit_classification_demo
```

学習には数十秒程度かかります（8エポック、手元の実行では十数秒〜1分程度）。

## データセット

MATLABに同梱されている`DigitDataset`（`toolbox/nnet/nndemos/nndatasets/DigitDataset`）を使用します。

- 28×28グレースケール画像、10クラス（数字0〜9）
- 各クラス1000枚、計10,000枚
- 80%を学習用（8,000枚）、20%をテスト用（2,000枚）に分割

外部からのダウンロードが不要で、Deep Learning Toolboxをインストールしていればすぐに使えます。

## やっていること

1. **データ読み込み**（`imageDatastore`）— フォルダ名（`0`〜`9`）からラベルを自動取得し、`splitEachLabel`で学習・テストに分割
2. **サンプル画像の表示** — 学習データからランダムに20枚を抜き出し、ラベル付きで表示
3. **CNNの定義**（`dlnetwork` + レイヤ配列）
   - 入力: 28×28×1（zスコア正規化）
   - 畳み込み層(8フィルタ) → バッチ正規化 → ReLU → 最大プーリング
   - 畳み込み層(16フィルタ) → バッチ正規化 → ReLU → 最大プーリング
   - 全結合層(10クラス) → ソフトマックス
4. **学習**（`trainnet`、損失関数`crossentropy`、Adamオプティマイザ、8エポック、`Plots="training-progress"`でライブ学習曲線を表示）
5. **評価** — テストセットに対する精度を算出し、混同行列（`confusionchart`）を表示
6. **予測結果の可視化** — テスト画像20枚をランダムに抜き出し、予測ラベルと正解ラベルを表示（正解は緑、誤りは赤のタイトルで表示）

## 実行結果の例

```text
Dataset: 10000 images, 10 classes
    Label    Count
    _____    _____
      0      1000
      1      1000
      ...
      9      1000
Train: 8000 images, Test: 2000 images

--- Test set evaluation ---
Test accuracy: 97.75% (1955 / 2000 correct)
```

実行すると以下のウィンドウが開きます。

- `Sample Training Images`（学習データのサンプル）
- `Training Progress`（Deep Learning Toolbox純正の学習進捗ウィンドウ）
- `Confusion Matrix`（テストセットの混同行列）
- `Sample Predictions`（テストデータへの予測結果、正解/不正解を色分け）

## 補足

- 8エポックのみの軽量な学習でも97%を超える精度に達します。より高い精度を狙う場合は`MaxEpochs`を増やすか、畳み込み層のフィルタ数・層数を増やしてください。
- `trainnet`はR2023b以降で推奨されている学習関数です（従来の`trainNetwork`の後継）。ネットワークは`layerGraph`ではなく`dlnetwork`オブジェクトとして構築しています。
- ミニバッチのシャッフルに乱数を使うため、`rng(0)`で初期状態を固定していても、実行のたびに最終精度が多少（1%未満程度）変動する場合があります。

## アレンジ例

- 畳み込み層・全結合層を増やして精度がどう変わるか比較する
- `MaxEpochs`や`InitialLearnRate`を変えて学習曲線（過学習の有無）を観察する
- 誤分類された画像だけを抽出して表示し、どんな数字が混同されやすいか調べる
- 独自の手書き数字画像（`imread`で読み込み、28×28にリサイズ）を学習済みネットワークで分類してみる
