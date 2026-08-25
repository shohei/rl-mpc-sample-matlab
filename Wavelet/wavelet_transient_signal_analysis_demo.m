%% Wavelet Toolbox Demo: Time-Frequency Analysis and Denoising of a Transient Signal
% A synthetic test signal combines three features that are hard to
% analyze all at once with classical tools: a slow background trend, a
% short high-frequency burst, and a sharp step discontinuity - all
% buried in noise. The demo shows:
%   1. Why a plain FFT cannot tell you *when* something happens, only
%      *what* frequencies are present.
%   2. How the continuous wavelet transform (CWT) scalogram localizes
%      the burst and the step in both time and frequency at once.
%   3. How multiresolution decomposition (wavedec/wrcoef) isolates the
%      burst into a single detail level.
%   4. How wavelet-based denoising (wdenoise) preserves the transient
%      burst far better than a simple moving-average filter, because it
%      can distinguish "genuine but brief" high-frequency content from
%      noise, while a moving average can only distinguish frequencies.

clear;
close all;
rng(0);

%% Step 1: Build a synthetic non-stationary test signal
fs = 1000;                       % sample rate (Hz)
T = 2;                           % duration (s)
t = (0:1/fs:T - 1/fs)';

trend = 0.5 * sin(2*pi*1*t);                       % slow 1 Hz background
stepComponent = 0.8 * (t >= 1.0);                  % sharp step at t = 1 s
burstMask = (t >= 0.4 & t < 0.5);                  % 100 ms window
burst = 0.6 * sin(2*pi*60*t) .* burstMask;         % brief 60 Hz burst

clean = trend + stepComponent + burst;

noiseStd = 0.25;
noisy = clean + noiseStd * randn(size(t));

figure('Name', 'Test Signal');
plot(t, clean, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Clean (trend + step + burst)');
hold on;
plot(t, noisy, 'Color', [0.6 0.6 0.6], 'DisplayName', 'Noisy (measured)');
xlabel('Time (s)');
ylabel('Amplitude');
title('Synthetic transient signal: 1 Hz trend + step at t=1s + 60 Hz burst at t=0.4-0.5s');
legend('Location', 'best');
grid on;
hold off;

%% Step 2: FFT - shows *what* frequencies are present, not *when*
N = numel(t);
f = fs * (0:N/2) / N;

fftMag = @(x) computeSingleSidedSpectrum(x, N);
P1clean = fftMag(clean);
P1noisy = fftMag(noisy);

figure('Name', 'FFT Magnitude Spectrum');
plot(f, P1clean, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Clean');
hold on;
plot(f, P1noisy, 'Color', [0.6 0.6 0.6], 'DisplayName', 'Noisy');
xlim([0 100]);
xlabel('Frequency (Hz)');
ylabel('|Amplitude|');
title('FFT: the 60 Hz burst shows up as a peak, but not *when* it occurred');
legend('Location', 'best');
grid on;
hold off;

%% Step 3: CWT scalogram - localizes the burst and step in time AND frequency
figure('Name', 'CWT Scalogram');
cwt(noisy, fs);
title('Scalogram: the 60 Hz burst and the step are both localized in time');

%% Step 4: Multiresolution decomposition - which detail level "sees" the burst?
wname = "sym4";
level = 6;
[C, L] = wavedec(noisy, level, wname);

approx = wrcoef('a', C, L, wname, level);
details = zeros(N, level);
for i = 1:level
    details(:, i) = wrcoef('d', C, L, wname, i);
end

figure('Name', 'Multiresolution Decomposition');
tiledlayout(level + 1, 1, 'TileSpacing', 'compact');
nexttile;
plot(t, approx, 'k-');
ylabel(sprintf('A%d', level));
title('Multiresolution decomposition (wavedec/wrcoef): approximation + detail levels');
for i = level:-1:1
    nexttile;
    plot(t, details(:, i));
    ylabel(sprintf('D%d', i));
    if i == 1
        xlabel('Time (s)');
    end
end

burstEnergyRatio = zeros(1, level);
outsideMask = ~burstMask;
for i = 1:level
    energyInside = mean(details(burstMask, i).^2);
    energyOutside = mean(details(outsideMask, i).^2);
    burstEnergyRatio(i) = energyInside / energyOutside;
end
[~, burstLevel] = max(burstEnergyRatio);
fprintf('--- Which detail level concentrates the 60 Hz burst? ---\n');
for i = 1:level
    fprintf('D%d: mean energy inside burst window is %.1fx the energy outside it\n', i, burstEnergyRatio(i));
end
fprintf('=> Detail level D%d isolates the burst most cleanly.\n', burstLevel);

%% Step 5: Denoising - wavelet thresholding vs. a simple moving-average filter
xWavelet = wdenoise(noisy);
maWindow = 21;
xMovAvg = movmean(noisy, maWindow);

snrDb = @(ref, est) 10*log10(sum(ref.^2) / sum((ref - est).^2));

stepWindow = t >= 0.95 & t <= 1.05;
burstWindow = t >= 0.38 & t <= 0.52;
rmse = @(ref, est, mask) sqrt(mean((ref(mask) - est(mask)).^2));

fprintf('\n--- Denoising: overall SNR vs. clean signal ---\n');
fprintf('%-28s %10s\n', '', 'SNR (dB)');
fprintf('%-28s %10.2f\n', 'Noisy (no denoising)', snrDb(clean, noisy));
fprintf('%-28s %10.2f\n', 'wdenoise (wavelet)', snrDb(clean, xWavelet));
fprintf('%-28s %10.2f\n', sprintf('movmean (window=%d)', maWindow), snrDb(clean, xMovAvg));

fprintf('\n--- RMSE around the 60 Hz burst (t = 0.38-0.52 s) ---\n');
fprintf('%-28s %10.4f\n', 'wdenoise (wavelet)', rmse(clean, xWavelet, burstWindow));
fprintf('%-28s %10.4f\n', 'movmean', rmse(clean, xMovAvg, burstWindow));

fprintf('\n--- RMSE around the step (t = 0.95-1.05 s) ---\n');
fprintf('%-28s %10.4f\n', 'wdenoise (wavelet)', rmse(clean, xWavelet, stepWindow));
fprintf('%-28s %10.4f\n', 'movmean', rmse(clean, xMovAvg, stepWindow));

figure('Name', 'Denoising Comparison');
tiledlayout(2, 1);
nexttile;
plot(t, clean, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Clean (ground truth)');
hold on;
plot(t, xWavelet, 'b-', 'DisplayName', 'wdenoise (wavelet)');
plot(t, xMovAvg, 'r-', 'DisplayName', sprintf('movmean (window=%d)', maWindow));
xlim([0.3 0.6]);
title('Zoom on the 60 Hz burst: wavelet denoising preserves it, moving-average smears it');
legend('Location', 'best');
grid on;
hold off;

nexttile;
plot(t, clean, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Clean (ground truth)');
hold on;
plot(t, xWavelet, 'b-', 'DisplayName', 'wdenoise (wavelet)');
plot(t, xMovAvg, 'r-', 'DisplayName', sprintf('movmean (window=%d)', maWindow));
xlim([0.9 1.1]);
xlabel('Time (s)');
title('Zoom on the step: both methods track it reasonably well');
legend('Location', 'best');
grid on;
hold off;

%% Local functions

function P1 = computeSingleSidedSpectrum(x, N)
    Y = fft(x);
    P2 = abs(Y / N);
    P1 = P2(1:floor(N/2) + 1);
    P1(2:end-1) = 2 * P1(2:end-1);
end
