# Deep Learning Toolbox サンプル: Transformer（自己注意機構）による波形分類

Deep Learning Toolboxに組み込まれているTransformer構成要素（`selfAttentionLayer`、`sinusoidalPositionEncodingLayer`など）を使い、再帰（RNN/LSTM）を使わずに時系列を分類するTransformerエンコーダを一から構築するサンプルです。合成データセットを使うため外部データのダウンロードは不要です。

## ファイル

- `deep_learning_transformer_waveform_demo.m` — 合成波形データセットの生成・Transformerエンコーダの構築・学習・評価・可視化を行う単体スクリプト
- `deep_learning_transformer_network_designer.m` — 同じアーキテクチャ（未学習）をDeep Network Designerアプリで開き、GUI上でノードをつないでモデルを編集できるようにするスクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Deep Learning Toolbox（`selfAttentionLayer`、`sinusoidalPositionEncodingLayer`等はR2023a/R2023b以降で導入）
- Signal Processing Toolbox（データ生成に`square`/`sawtooth`関数を使用）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
deep_learning_transformer_waveform_demo
```

データ生成込みで数十秒程度で完了します（25エポック、手元の実行では学習のみ約10秒）。

## タスクとデータセット

4種類の波形（正弦波・矩形波・のこぎり波・ノイズ）を、ランダムな周波数・位相・振幅・ノイズで生成し、どの波形タイプかを分類する4クラス分類問題です。1系列あたり64ステップ、各クラス200系列（計800系列）を生成し、80%を学習用、20%をテスト用に分割します。

## Transformerエンコーダの構成

再帰層（LSTM等）を使わず、Transformerの標準的な「エンコーダブロック」だけで時系列を処理します。

```text
sequenceInputLayer(1)
  -> fullyConnectedLayer(dModel)              % 各時刻ごとに1次元→dModel次元へ埋め込み
  -> + sinusoidalPositionEncodingLayer         % 位置情報を加算（Attentionは順序を知らないため）
  -> [ selfAttentionLayer                      % 自己注意（系列内の全時刻同士の関係を計算）
        -> +残差接続 -> layerNormalizationLayer
        -> フィードフォワード（fc→ReLU→fc）
        -> +残差接続 -> layerNormalizationLayer ] を numBlocks 回繰り返す
  -> globalAveragePooling1dLayer               % 時間方向を平均して固定長ベクトルに
  -> fullyConnectedLayer(numClasses) -> softmax
```

既定では`dModel=32`（埋め込み次元）、`numHeads=4`（注意ヘッド数）、`dFF=64`（フィードフォワード層の中間次元）、`numBlocks=2`（エンコーダブロック数）です。

自己注意層や残差接続を挟む都合上、層が枝分かれ・合流する非線形なネットワークになるため、`layerGraph`＋`connectLayers`で明示的に接続を組み立てています（`Sequential`な配列では表現できません）。

## やっていること

1. **データ生成**（`generateWaveforms`ローカル関数）— 4クラスの合成波形を生成
2. **サンプル波形の表示** — クラスごとに1本ずつ波形を表示
3. **Transformerエンコーダの構築**（`buildTransformerEncoder`ローカル関数）
4. **モデル構造の可視化** — `plot(net)`で層の接続グラフを表示し、`analyzeNetwork(net)`で各層の出力サイズ・学習可能パラメータ数を含む詳細なインタラクティブビューを開く（下記「モデルの可視化」参照）
5. **学習**（`trainnet`、損失関数`crossentropy`、Adam、25エポック、`Plots="training-progress"`）
6. **評価** — テスト精度と混同行列（`confusionchart`）
7. **予測結果の可視化** — テスト系列のサンプルを波形として表示し、予測と正解を色分け表示（緑=正解、赤=不正解）

## モデルの可視化

自己注意層・残差接続を含むこのネットワークは`Sequential`な一直線の構造ではなく、枝分かれ・合流のあるグラフ構造です。2通りの方法で可視化しています。

- **`plot(net)`** — 静的な層接続グラフをFigureとして表示します（スクリプト実行のみで自動生成）。各Transformerブロック内の「Attention→残差加算」「フィードフォワード→残差加算」というループ状の接続（スキップコネクション）が視覚的に確認できます。
- **`analyzeNetwork(net)`** — Deep Learning ToolboxのNetwork Analyzerアプリを開き、層ごとの出力サイズ・学習可能パラメータ数・活性化関数などを一覧できる、よりインタラクティブなビューです（GUIウィンドウが開きます）。

`plot`はグラフの形（接続の仕方）を見るのに向いており、`analyzeNetwork`は各層の詳細な諸元を調べるのに向いています。

## モデルをGUIで編集する（Deep Network Designer）

`plot`と`analyzeNetwork`はどちらも「見るだけ」ですが、Deep Learning Toolboxには**GUI上でノードをドラッグ＆ドロップして接続を組み替えられる**Deep Network Designerアプリもあります。

```matlab
deep_learning_transformer_network_designer
```

を実行すると、`deep_learning_transformer_waveform_demo.m`と同じ（未学習の）Transformerアーキテクチャを読み込んだ状態でアプリが開きます。アプリでは以下のようなことができます。

- 左側のレイヤーライブラリから新しい層をキャンバスにドラッグして追加する
- 既存の層を削除する、接続線をつなぎ直す（例: エンコーダブロックをもう1つ追加する、Attentionのヘッド数を変えた層に差し替える、別の場所にスキップ接続を追加する）
- 各層をクリックしてプロパティ（フィルタ数・ヘッド数など）をパネルから編集する
- 編集後、「Export」でワークスペースに`dlnetwork`としてエクスポートする、または「Generate Code」で編集後のアーキテクチャを再現するMATLABコードを生成する

`mpcDesigner`のExportボタンと同様、GUIで組み立てた（またはワークスペースから読み込んだ）ネットワークをエクスポートすれば、`deep_learning_transformer_waveform_demo.m`の`trainnet`呼び出しにそのまま渡して学習させられます。

## 実行結果の例

```text
Generated 800 sequences (200 per class, length 64)
Train: 640, Test: 160

Transformer encoder: dModel=32, numHeads=4, dFF=64, numBlocks=2

--- Test set evaluation ---
Test accuracy: 90.62% (145 / 160 correct)
```

実行すると以下のウィンドウが開きます。

- `Sample Waveforms`（クラスごとのサンプル波形）
- `Training Progress`（Deep Learning Toolbox純正の学習進捗ウィンドウ）
- `Confusion Matrix`（テストセットの混同行列）
- `Sample Predictions`（テスト系列への予測結果、正解/不正解を色分け）

## 詰まった点

- **`trainnet`のセル配列系列データは「時刻×チャンネル」（T×C）の向き**: 系列分類でよく知られる従来の`trainNetwork`の慣習（チャンネル×時刻、C×T）とは異なり、`trainnet`にセル配列で系列データを渡す場合は各セルを`T×numFeatures`（今回は`64×1`）の行列にする必要がありました。逆向き（`1×64`）で渡すと、`sequenceInputLayer`が「チャンネル次元のサイズが64である」と誤認識し、正規化統計量の計算やチャンネル数の検証でエラーになります。

## `deep_learning_digit_classification_demo.m` / `deep_learning_cifar10_architectures_demo.m`との違い

| | 数字認識 | CIFAR-10（複数アーキテクチャ比較） | 本サンプル（Transformer） |
| --- | --- | --- | --- |
| データ | 画像（28×28グレースケール） | 画像（32×32カラー） | 時系列（64ステップ、1特徴量） |
| 主な層 | 畳み込み層 | 畳み込み層＋残差接続 | 自己注意層＋残差接続 |
| ネットワーク定義 | レイヤー配列（Sequential） | `layerGraph`（残差接続あり） | `layerGraph`（Attention＋残差接続） |
| データ由来 | MATLAB付属 | 外部ダウンロード（CIFAR-10） | その場で合成生成（ダウンロード不要） |

## アレンジ例

- `numBlocks`・`dModel`・`numHeads`・`dFF`を変えて精度と学習時間のトレードオフを確認する
- `selfAttentionLayer`の`HasScoresOutput=true`を有効にし、`predict`の追加出力からアテンションの重みを取り出して、どの時刻に注目しているか可視化する
- LSTM（`lstmLayer`）ベースの分類器を同じデータセットで学習させ、Transformer版と精度・学習時間を比較する
- ノイズレベルやクラス数を増やしてタスクを難しくし、モデルの頑健性を確認する
- Deep Network Designerでエンコーダブロックを3つ以上に増やす、または層構成をまったく変えたモデルを組み、Exportしたネットワークで学習させて精度を比較する
