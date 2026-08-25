# Deep Learning Toolbox サンプル: CIFAR-10でアーキテクチャを比較する

`deep_learning_digit_classification_demo.m`（手書き数字、28×28グレースケール）より難しいベンチマーク課題として、CIFAR-10（32×32カラーの実写物体画像、10クラス）を使います。単一のモデルを学習させるだけでなく、**層の接続を変えた複数のアーキテクチャを同じデータ・同じ条件で学習させて比較する**ことを主目的にしたサンプルです。

## ファイル

- `deep_learning_cifar10_architectures_demo.m` — CIFAR-10のダウンロード・読み込み・複数アーキテクチャの学習と比較・可視化を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Deep Learning Toolbox
- インターネット接続（初回実行時のみ、CIFAR-10データセットのダウンロードに必要。約183MB）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
deep_learning_cifar10_architectures_demo
```

初回はデータセットのダウンロード（回線速度に依存、数分かかる場合があります）＋展開が入ります。2回目以降は`data/`フォルダにキャッシュされたデータを再利用するため、すぐに学習が始まります。学習自体は2アーキテクチャ合計で1〜2分程度（CPU実行、手元の実行では約50〜100秒/アーキテクチャ）です。

`data/`フォルダは`.gitignore`済みで、リポジトリには含まれません。

## データセット

[CIFAR-10](https://www.cs.toronto.edu/~kriz/cifar.html)（Krizhevsky, 2009）。32×32のカラー画像、10クラス（airplane, automobile, bird, cat, deer, dog, frog, horse, ship, truck）、本来は学習5万枚・テスト1万枚ですが、本サンプルはCPUでも現実的な時間で回るよう、**各クラス1500枚（学習1.5万枚）・各クラス300枚（テスト3000枚）のサブセット**を使用します（`numTrainPerClass`/`numTestPerClass`を増やせばフルデータセットに近づけられます）。

手書き数字と異なり、背景・照明・向きなどが多様な実写画像なので、モデルが実際に意味のある視覚特徴を学習する必要があり、素朴なCNNでは数字認識ほど簡単には高精度が出ません。

## 比較する2つのアーキテクチャ

同程度のパラメータ規模で、「層のつなぎ方」だけを変えた2つのCNNを用意しています。

- **Plain CNN**（`buildPlainNet`）— 畳み込み→バッチ正規化→ReLU→プーリングを3回繰り返す、枝分かれのない一直線の構成
- **Residual CNN**（`buildResidualNet`）— 同程度の深さ・フィルタ数だが、中間ブロックに**残差接続**（ショートカット＋加算）を追加した構成。入力とブロック出力を`additionLayer`で足し合わせるため、`layerGraph`＋`connectLayers`で非line的な接続を明示的に組み立てています。

新しいアーキテクチャを試したい場合は、`build___Net(numClasses)`という形式のローカル関数を追加し、スクリプト中盤の`architectures`セル配列に1行追加するだけで比較対象に加えられます。

```matlab
architectures = {
    "Plain CNN",    @() buildPlainNet(numClasses)
    "Residual CNN", @() buildResidualNet(numClasses)
    % "My Net",     @() buildMyNet(numClasses)   % ここに追加
    };
```

## やっていること

1. **CIFAR-10のダウンロード・展開・読み込み** — 初回のみ`websave`でダウンロードし、`.mat`バッチファイルを画像配列に変換
2. **クラスあたりのサブセット抽出** — 学習・テストとも各クラス同数になるように抽出
3. **サンプル画像の表示**
4. **各アーキテクチャを順番に学習**（`trainnet`、`crossentropy`損失、Adam、12エポック、`Metrics="accuracy"`で検証精度も記録）し、学習時間・パラメータ数・テスト精度を記録
5. **学習曲線の比較プロット** — 各アーキテクチャの検証精度の推移を1つのグラフに重ねて表示
6. **最終結果の比較** — テスト精度・学習時間の棒グラフ

## 実行結果の例

```text
Classes: airplane, automobile, bird, cat, deer, dog, frog, horse, ship, truck
Train: 15000 images (1500/class), Test: 3000 images (300/class)

=== Training "Plain CNN" (34058 learnable parameters) ===
"Plain CNN": test accuracy = 64.13%, training time = 50.0 s

=== Training "Residual CNN" (43914 learnable parameters) ===
"Residual CNN": test accuracy = 64.73%, training time = 99.6 s

--- Summary ---
Plain CNN      test accuracy = 64.13%   training time =   50.0 s
Residual CNN   test accuracy = 64.73%   training time =   99.6 s
```

実行すると以下のウィンドウが開きます。

- `CIFAR-10 Sample Images`（サンプル画像）
- `Architecture Comparison: Learning Curves`（検証精度の推移比較）
- `Architecture Comparison: Summary`（最終テスト精度・学習時間の棒グラフ）

この規模のサブセット・エポック数では、残差接続によるテスト精度の改善はわずかです（本来CIFAR-10で残差接続の効果がはっきり出るのは、もっと深いネットワーク・多いエポック数・フルデータセットでの学習です）。`numTrainPerClass`・`MaxEpochs`・ネットワークの深さを増やすと差が出やすくなります。

## 詰まった点

- **`for c = classNames`で全要素をループできていなかった**: `batches.meta.mat`から読み込んだクラス名を`string()`変換すると列ベクトルになり、`for c = classNames`と書くと（MATLABの`for`は行列を列ごとに反復するため）ループ全体が1回しか実行されず、`c`に全クラス名がまとめて代入されてしまいました。`classNames = reshape(string(...), 1, [])`で明示的に行ベクトルに変換して解決しました。
- **添字アクセスの結果の向きは「添字」ではなく「元の配列」に従う**: `Y(idx)`のような添字アクセスで返る配列の向き（行/列）は、添字`idx`の向きではなく、**元の配列`Y`自身の向き**を引き継ぐという仕様でした。`Y`が行ベクトルになっていたことに気づかず、`trainnet`に渡すラベルの形状がおかしくなり、「観測数が1」という分かりにくいエラーになりました。ラベルを作る箇所で明示的に`Y = Y(:);`として列ベクトルに矯正しています。
- **`categorical`は文字列のセル配列を期待する**: `categorical({results.Name})`のように、string型の値が入ったセル配列を渡すとエラーになりました（`categorical`は`char`のセル配列を期待するため）。`categorical([results.Name])`のように、string配列として直接渡すことで解決しています。
- **`ValidationHistory`にAccuracy列がない**: `trainingOptions`で`Metrics="accuracy"`を指定しないと、検証履歴には`Loss`列しか記録されません。検証精度の学習曲線を描くために`Metrics="accuracy"`を明示的に指定しています。

## アレンジ例

- `numTrainPerClass`・`MaxEpochs`を増やし、（時間はかかりますが）フルデータセットに近い精度を確認する
- Deep Network Designer（`deep_learning_transformer_network_designer.m`と同様の使い方）でCNNのアーキテクチャをGUIで組み、`architectures`リストに追加して比較する
- 独自の`build___Net`関数を追加し、層の数・フィルタ数・残差接続の位置を変えて精度と学習時間のトレードオフを調べる
