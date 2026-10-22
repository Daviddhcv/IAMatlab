%% =========================================================
%  main_cellular_recovery.m
%  Autonomous Cellular Service Recovery via Tabular Q-Learning
%  =========================================================
%  Ejecutar este script para reproducir todos los resultados
%  y figuras del manuscrito.
% ==========================================================

clear; clc; close all;
rng(42);  % semilla principal reproducible

fprintf('=================================================\n');
fprintf(' Cellular Recovery via Q-Learning (IEEE TNSM)\n');
fprintf('=================================================\n\n');

%% --- Hiperparametros (Tabla V del manuscrito) ---
params.alpha        = 0.05;       % tasa de aprendizaje
params.gamma        = 0.95;       % factor de descuento
params.epsilon0     = 0.10;       % exploracion inicial
params.epsilonMin   = 0.01;       % exploracion minima
params.epsilonDecay = 0.001;      % decaimiento por episodio
params.maxEpisodes  = 500;        % episodios maximos
params.maxSteps     = 100;        % pasos maximos por episodio
params.stopWindow   = 20;         % ventana moving average
params.stopReward   = 85;         % criterio de parada
params.nSeeds       = 50;         % semillas Monte Carlo
params.valSteps     = 50;         % pasos de validacion por semilla

%% --- Pesos de recompensa (Tabla III del manuscrito) ---
params.w1 = 1.2;    % ganancia de throughput
params.w2 = 2.5;    % penalizacion DCR
params.w3 = 50.0;   % penalizacion fallo no recuperado
params.w4 = 0.1;    % costo por paso

%% --- Parametros del canal (Tabla IV del manuscrito) ---
chan.eta        = 3.5;    % exponente de perdida de trayecto
chan.sigma_dB   = 8.0;    % desviacion estandar shadowing (dB)
chan.lambdaFault = 0.05;  % tasa de fallos Poisson (eventos/paso)
chan.cellRadius  = 500;   % radio celda macro (m)
chan.fc_GHz      = 3.5;   % frecuencia portadora (GHz)
chan.vMax_kmh    = 30;    % velocidad maxima UE (km/h)

%% ---- FASE 1: Entrenamiento principal (semilla base) ----
fprintf('[1/4] Entrenando agente Q-learning (semilla base)...\n');
env = CellularEnv(chan, params);
[Qtable, trainRewards, convEpisode] = trainQAgent(env, params);

fprintf('      Convergencia en episodio: %d\n', convEpisode);
fprintf('      Recompensa final promedio (ep 400-500): %.2f\n', ...
        mean(trainRewards(400:end)));

%% ---- FASE 2: Validacion Monte Carlo (50 semillas) -------
fprintf('[2/4] Validacion Monte Carlo (%d semillas)...\n', params.nSeeds);
[allTrainRewards, mcResults] = runMonteCarlo(chan, params);

%% ---- FASE 3: Baseline rule-based ----------------------
fprintf('[3/4] Evaluando baseline rule-based...\n');
baselineResults = runRuleBasedBaseline(chan, params);

%% ---- FASE 4: Generacion de figuras --------------------
fprintf('[4/4] Generando figuras del manuscrito...\n');
plotFig1_Convergence(allTrainRewards, params);
plotFig2_RSRPTrace(chan, params, Qtable);
plotFig3_LatencyHistogram(mcResults, baselineResults);

%% ---- Reporte de resultados (Tablas VI y VII) -----------
printResultsReport(mcResults, baselineResults, convEpisode, ...
                   trainRewards, Qtable, params);

fprintf('\n[DONE] Todos los resultados generados.\n');
fprintf('       Figuras guardadas en: Fig1_Convergence.png,\n');
fprintf('                             Fig2_RSRPTrace.png,\n');
fprintf('                             Fig3_Latency.png\n');
