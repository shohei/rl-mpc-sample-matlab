# CIFAR-10 + Deep Network Designer: Transformer（ViT風）をGUIで試す

`deep_learning_cifar10_architectures_demo.m`（Plain CNN vs Residual CNNの2モデル比較）を複製・簡略化したサンプルです。モデル比較は行わず、**単一のスターターモデル（Vision Transformer風のネットワーク）を構築してDeep Network Designerアプリで開く**ことに絞っています。GUIで編集したモデルは、もう1つのスクリプトで学習・評価できます。

## ファイル

- `deep_learning_cifar10_transformer_designer_demo.m` — CIFAR-10の読み込み・スターターネットワークの構築・Deep Network Designerの起動を行うスクリプト（学習は含まない）
- `deep_learning_cifar10_transformer_train_exported.m` — Deep Network Designerで「Export」したネットワークを学習させ、テスト精度・混同行列・予測結果を表示するスクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Deep Learning Toolbox（`selfAttentionLayer`、`sinusoidalPositionEncodingLayer`、`functionLayer`を使用）
- インターネット接続（初回のみ、CIFAR-10ダウンロードに必要）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
deep_learning_cifar10_transformer_designer_demo
```

`deep_learning_cifar10_architectures_demo.m`を先に実行済みであれば`data/`のキャッシュを再利用するため、すぐに立ち上がります。

## スターターネットワークの構成（Vision Transformer風）

`deep_learning_transformer_waveform_demo.m`のTransformerエンコーダを、画像（CIFAR-10、32×32×3）向けに拡張したものです。

```text
imageInputLayer(32x32x3)
  -> convolution2dLayer(4, dModel, Stride=4)   % パッチ埋め込み: 4x4パッチをdModel次元に変換 (8x8xdModel)
  -> functionLayer（画像形式→系列形式に変形）    % (H,W,C,B) -> (C, H*W, B)、64個のパッチトークンの系列に
  -> + sinusoidalPositionEncodingLayer
  -> [ selfAttentionLayer -> +残差接続 -> layerNorm
        -> フィードフォワード -> +残差接続 -> layerNorm ] x numBlocks
  -> globalAveragePooling1dLayer -> fullyConnectedLayer(10) -> softmax
```

画像をTransformerに入力するには、まず画像を「パッチのトークン列」に変換する必要があります（Vision Transformer, ViTの標準的な手法）。MATLABの`selfAttentionLayer`は画像形式（H×W×C×B）のデータを直接は受け取れないため、`convolution2dLayer`（カーネルサイズ＝ストライド＝パッチサイズ）でパッチ埋め込みを行った後、自作の`functionLayer`で系列形式（C×T×B、T=パッチ数）に変形しています。この`functionLayer`による変形も含めて、学習時に正しく勾配が流れることを確認済みです。

## やっていること

1. **CIFAR-10のダウンロード・読み込み・サブセット抽出**（`deep_learning_cifar10_architectures_demo.m`と同じ）
2. **サンプル画像の表示**
3. **スターターネットワークの構築**（`buildVitStarterNet`ローカル関数）
4. **モデル構造の表示**（`plot(net)`で静的な接続グラフを表示）
5. **Deep Network Designerの起動**（`deepNetworkDesigner(net)`）— ここがこのスクリプトの主目的です

学習・評価コードはこのスクリプトには含まれていません。`XTrain`/`YTrain`/`XTest`/`YTest`はベースワークスペースに残しているので、GUIで編集したモデルをエクスポートした後は`deep_learning_cifar10_transformer_train_exported.m`（次のセクション）で学習・評価できます。

## Deep Network Designerでできること

- レイヤーライブラリから新しい層をドラッグして追加（例: エンコーダブロックをもう1つ増やす）
- `b1_attn`・`b2_attn`などの`selfAttentionLayer`を選択し、プロパティパネルで`NumHeads`（アテンションヘッド数）を変更する
- 接続線をつなぎ直して、スキップ接続の位置を変える、ブロックの順序を変えるなど
- 「Export」でワークスペースに`dlnetwork`としてエクスポート、または「Generate Code」で編集後のアーキテクチャを再現するMATLABコードを生成

## 実行結果の例（デザイナー起動スクリプト）

```text
Classes: airplane, automobile, bird, cat, deer, dog, frog, horse, ship, truck
Train: 15000 images (1500/class), Test: 3000 images (300/class)

Starter network: patchSize=4, dModel=32, numHeads=4, dFF=64, numBlocks=2

Opening Deep Network Designer...
```

実行すると以下が開きます。

- `CIFAR-10 Sample Images`（サンプル画像）
- `Starter Network Architecture Graph`（スターターモデルの接続グラフ）
- Deep Network Designerアプリ（GUI編集用）

## GUIで編集したモデルを学習・評価する（`deep_learning_cifar10_transformer_train_exported.m`）

Deep Network Designerの「Export」を押すと、変数名を提案する編集可能なダイアログが出ます（既定の提案名は**`net`**。ただしワークスペースに既に`net`がある場合は`net_1`のように自動的にユニーク化されます）。名前を確認・変更して「OK」を押すと、その名前の`dlnetwork`としてワークスペースにエクスポートされます。

```matlab
deep_learning_cifar10_transformer_train_exported
```

を実行すると、このスクリプトは以下を行います。

1. ベースワークスペースから`dlnetwork`型の変数を自動検出（`net`という名前があれば優先、複数見つかった場合は一覧を表示して最後のものを使用）
2. `deep_learning_cifar10_transformer_designer_demo.m`実行時に残った`XTrain`/`YTrain`/`XTest`/`YTest`があればそのまま再利用（無ければCIFAR-10データを読み込み直す）
3. `trainnet`で学習（12エポック、`Plots="training-progress"`でライブ学習曲線を表示）
4. テスト精度・学習時間をコンソールに出力
5. 学習曲線・混同行列・予測結果サンプル（正解=緑、不正解=赤）をプロット

Deep Network Designerを開かずに`deep_learning_cifar10_transformer_designer_demo.m`を実行しただけの状態（未編集のスターターモデルがワークスペースの`net`に残っている状態）でこのスクリプトを実行しても、そのまま学習が始まります。

### 実行結果の例（未編集のスターターモデル、12エポック）

```text
Training dlnetwork variable "net" (24 layers, 36 learnable parameter arrays)
Train: 15000 images, Test: 3000 images

--- Test set evaluation ---
Training time: 100.4 s
Test accuracy: 47.80% (1434 / 3000 correct)
```

`deep_learning_cifar10_architectures_demo.m`のCNN（12エポックで64%前後）にはまだ及びませんが、ランダム（10%）や3エポックのみの動作確認（28.5%）よりは明確に向上しています。Deep Network Designerでブロック数やヘッド数を変更してエクスポートし、精度がどう変わるか比べてみてください。

## 補足

- 動作確認として、このスターターネットワークをCIFAR-10のサブセット（各クラス300枚、3エポック）で実際に学習させたところ、テスト精度28.5%まで到達しました（ランダム10%より明確に高く、勾配が正しく流れていることを確認済み）。Vision Transformer系のモデルは一般に、CNNより多くのデータ・学習量が必要になる傾向があるため、`deep_learning_cifar10_architectures_demo.m`のCNN（12エポックで64%前後）と同等以上の精度を出すには、より多くのエポック数・データ量が必要になる可能性があります。
- `functionLayer`による画像→系列の変形は、`Formattable=true`を指定することで、書式付き（`dlarray`のフォーマットラベル付き）のデータをそのまま扱えるようにしています。
- **並列学習（`ExecutionEnvironment="parallel-cpu"`）は試した上で無効にしています**: GPUが無い環境でもローカルの並列プール（このマシンでは10ワーカー）を使ってミニバッチを分散できますが、このネットワーク・データ規模では並列プールの起動・ワーカー間通信のオーバーヘッドが計算量を上回り、**逐次実行より遅くなりました**（逐次100.4秒 → 並列188.2秒）。ワーカー間でのバッチ分割により収束の挙動も変わり、同じ12エポックでのテスト精度も低下しました（47.80%→35.33%）。並列学習はモデル・バッチサイズが大きく、1ステップあたりの計算量が通信コストを上回る場合に有効です。本サンプルの規模では逐次実行のままにしています。

## アレンジ例

- Deep Network Designerでパッチサイズの異なる別の`convolution2dLayer`に差し替え、パッチ数（系列長）を変えて比較する
- `numBlocks`・`dModel`・`numHeads`をGUI上で変更し、エクスポート→学習を繰り返してパラメータ数と精度のトレードオフを探る
- `deep_learning_cifar10_architectures_demo.m`の`architectures`リストに、GUIでエクスポートしたネットワークをビルドする関数として追加し、CNN勢と直接比較する
