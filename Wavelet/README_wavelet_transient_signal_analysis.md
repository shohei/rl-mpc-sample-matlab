# Wavelet Toolbox サンプル: 過渡信号の時間-周波数解析とノイズ除去

Wavelet Toolbox を使った、時間とともに性質が変わる（非定常な）信号の解析サンプルです。「ゆっくりした背景トレンド」「短時間だけ現れる高周波バースト」「急激なステップ変化」の3つがノイズに埋もれた合成信号を題材に、FFTだけでは分からない"いつ起きたか"をウェーブレットでどう可視化・分離・除去できるかを一通り確認します。

## ファイル

- `wavelet_transient_signal_analysis_demo.m` — 信号生成・FFT比較・CWTスカログラム・多重解像度分解・ノイズ除去比較を行う単体スクリプト

## 必要環境

- MATLAB R2025b（動作確認済み）
- Wavelet Toolbox
- Signal Processing Toolbox は不要（FFTは素の `fft` 関数のみ使用）

## 実行方法

MATLAB のカレントフォルダをこのディレクトリに設定し、以下を実行します。

```matlab
wavelet_transient_signal_analysis_demo
```

数秒で完了します。

## やっていること

1. **合成テスト信号の生成**
   - 1 Hzのゆっくりした背景トレンド
   - `t=1.0` s での急激なステップ変化（+0.8）
   - `t=0.4〜0.5` s だけ現れる60 Hzの短時間バースト
   - 上記の合計にノイズ（標準偏差0.25）を加えたものを「観測信号」とする
2. **FFTによる周波数スペクトル**（素の `fft`）
   - 60 Hzのピークは見えるが、それが「いつ」起きたかはスペクトルから分からないことを確認
3. **CWTスカログラム**（`cwt(noisy, fs)`）
   - 連続ウェーブレット変換により、60 Hzバーストが `t=0.4〜0.5` s に局在していること、ステップ変化が広帯域的な特徴として時刻1s付近に現れることを、時間・周波数の両方で同時に可視化
4. **多重解像度分解**（`wavedec` + `wrcoef`）
   - `sym4` ウェーブレットで6レベルに分解し、近似成分（A6）と各詳細成分（D1〜D6）を時系列で並べて表示
   - バースト窓内外での各詳細レベルのエネルギー比を計算し、どのレベルが60 Hzバーストを最もよく「捉えている」かを定量的に確認（本サンプルの設定ではD3が突出）
5. **ノイズ除去の比較**（`wdenoise` vs. 単純な移動平均 `movmean`）
   - クリーン信号に対するSNR（信号対雑音比）を、ノイズ除去前後・手法間で比較
   - バースト付近・ステップ付近それぞれのRMSEを比較し、どちらの手法がどの特徴を保存しやすいかを確認

## 実行結果の例

```text
--- Which detail level concentrates the 60 Hz burst? ---
D1: mean energy inside burst window is 0.8x the energy outside it
D2: mean energy inside burst window is 0.9x the energy outside it
D3: mean energy inside burst window is 15.2x the energy outside it
D4: mean energy inside burst window is 8.1x the energy outside it
D5: mean energy inside burst window is 0.6x the energy outside it
D6: mean energy inside burst window is 0.0x the energy outside it
=> Detail level D3 isolates the burst most cleanly.

--- Denoising: overall SNR vs. clean signal ---
                               SNR (dB)
Noisy (no denoising)               8.63
wdenoise (wavelet)                18.99
movmean (window=21)               14.46

--- RMSE around the 60 Hz burst (t = 0.38-0.52 s) ---
wdenoise (wavelet)               0.2098
movmean                          0.4134

--- RMSE around the step (t = 0.95-1.05 s) ---
wdenoise (wavelet)               0.1442
movmean                          0.1180
```

実行すると以下のウィンドウが開きます。

- `Test Signal`（合成したクリーン信号とノイズ付き信号）
- `FFT Magnitude Spectrum`（クリーン・ノイズ付き信号の周波数スペクトル比較）
- `CWT Scalogram`（Wavelet Toolbox純正のスカログラム表示）
- `Multiresolution Decomposition`（近似成分A6と詳細成分D1〜D6の積み上げ表示）
- `Denoising Comparison`（バースト付近・ステップ付近をズームした、クリーン信号・wdenoise・movmeanの重ね描き）

## 補足・詰まりやすい点

- **全体のSNRでは `wdenoise` が `movmean` に明確に勝ちますが（18.99 dB vs 14.46 dB）、ステップ付近だけを見ると `movmean` の方がわずかに誤差が小さくなります（RMSE 0.118 vs 0.144）。** これは移動平均が単調なステップ変化自体の平均化には強い一方、60 Hzバーストのような「短時間だけ存在する高周波成分」を無条件に平滑化してしまうためです。ウェーブレット閾値処理は周波数だけでなく「その周波数成分がどれだけ局在しているか」も考慮して残すかどうかを判断できるため、バースト付近のRMSEは大きく改善します（0.410 → 0.210）。ノイズ除去手法を選ぶ際は、単一の指標（全体SNR）だけでなく、保存したい信号特徴に応じて評価することが重要です。
- `cwt(noisy, fs)` は出力引数なしで呼び出すと、Wavelet Toolbox純正のスカログラム（コーン・オブ・インフルエンス、カラーバー、対数周波数軸つき）を自動的にプロットします。数値データが必要な場合は `[wt, f, coi] = cwt(noisy, fs)` のように出力引数を受け取ってください。
- `wavedec`/`wrcoef` で得られる各詳細成分 `D1`〜`D6` は、サンプル周波数1000 Hzに対して大まかに `D1: 250-500 Hz`、`D2: 125-250 Hz`、`D3: 62.5-125 Hz`、`D4: 31.25-62.5 Hz` ...という周波数帯に対応します。60 Hzのバーストが主にD3・D4にまたがって現れるのはこのためです。
- `wdenoise` は既定でBayes型のしきい値処理（`sym4` ウェーブレット、レベル自動選択）を使用します。ノイズの性質や信号によっては `DenoisingMethod`（`"BlockJS"`、`"Minimax"`、`"SURE"` など）を変えると結果が変わります。
- 乱数シードは `rng(0)` で固定していますが、結果はMATLAB・Wavelet Toolboxのバージョンにより多少変動する場合があります。

## アレンジ例

- `noiseStd` を変えてノイズレベルごとの `wdenoise` と `movmean` の差を確認
- `wname`（ウェーブレットの種類、例: `"db4"`、`"coif3"`）や分解レベル `level` を変えて、バーストが最もよく分離されるレベルがどう変わるかを観察
- `wdenoise` の `DenoisingMethod` を変更し、しきい値処理方式によるノイズ除去性能の違いを比較
- バースト周波数（60 Hz）やバースト時間窓を変え、CWTスカログラム上での見え方や、最適な検出レベルがどう変化するかを確認
- 実データ（振動データ、心電図、音声など）に対して同じワークフロー（FFT → CWT → 多重解像度分解 → ノイズ除去）を適用してみる
