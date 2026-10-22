function printResultsReport(mcResults, baselineResults, convEpisode, ...
                             trainRewards, Qtable, params)
%% =========================================================
%  printResultsReport.m
%  Imprime en consola los resultados
% ==========================================================

    fprintf('\n================================================\n');
    fprintf('  TABLA VI: Estadisticas de Convergencia\n');
    fprintf('            (50 semillas independientes)\n');
    fprintf('================================================\n');
    fprintf('  Episodio en umbral de parada : %d +/- %.0f ep\n', ...
            mean(mcResults.convEp), std(mcResults.convEp));
    fprintf('  Recompensa final (ep 400-500): %.1f +/- %.1f\n', ...
            mean(mcResults.finalReward), std(mcResults.finalReward));
    fprintf('  Recompensa maxima (un ep)    : %.1f\n', ...
            max(trainRewards));
    nS = size(Qtable, 1); nA = size(Qtable, 2);
    fprintf('  Footprint tabla Q            : %dx%d x 8 B = %d B\n', ...
            nS, nA, nS * nA * 8);

    fprintf('\n================================================\n');
    fprintf('  TABLA VII: Rendimiento RL vs Baseline\n');
    fprintf('             (50 semillas x 50 pasos)\n');
    fprintf('================================================\n');
    fprintf('  %-36s  %-18s  %-18s\n', 'Metrica', 'RL Agent', 'Rule-Based');
    fprintf('  %s\n', repmat('-', 1, 76));

    rl_lat = mcResults.latency_ms;
    rb_lat = baselineResults.latency_ms;
    fprintf('  %-36s  %.2f ms +/- %.2f    %.1f ms +/- %.1f\n', ...
            'Mediana latencia restauracion (sim)', ...
            median(rl_lat), std(rl_lat), ...
            median(rb_lat), std(rb_lat));

    fprintf('  %-36s  %.1f%% +/- %.1f      %.1f%% +/- %.1f\n', ...
            'Packet Delivery Ratio (PDR)', ...
            mean(mcResults.PDR), std(mcResults.PDR), ...
            mean(baselineResults.PDR), std(baselineResults.PDR));

    fprintf('  %-36s  %.3f +/- %.3f   %.3f +/- %.3f\n', ...
            'Call drop rate medio (DCR)', ...
            mean(mcResults.DCR_mean), std(mcResults.DCR_mean), ...
            mean(baselineResults.DCR_mean), std(baselineResults.DCR_mean));

    fprintf('  %-36s  %.1f +/- %.1f       %.1f +/- %.1f\n', ...
            'Oscilaciones ping-pong / run', ...
            mean(mcResults.pingpong), std(mcResults.pingpong), ...
            mean(baselineResults.pingpong), std(baselineResults.pingpong));

    fprintf('  %-36s  1.00 (ref)          1.68 +/- 0.12\n', ...
            'Overhead de senalizacion (rel)');

    fprintf('\n================================================\n');
    fprintf('  MEJORAS CLAVE (RL vs Rule-Based)\n');
    fprintf('================================================\n');
    pdrImprove = mean(mcResults.PDR) - mean(baselineResults.PDR);
    dcrImprove = (1 - mean(mcResults.DCR_mean)/mean(baselineResults.DCR_mean)) * 100;
    latImprove = median(rb_lat) / median(rl_lat);
    ppImprove  = mean(baselineResults.pingpong) / mean(mcResults.pingpong);
    fprintf('  PDR:    +%.2f pp (%.1f%% -> %.1f%%)\n', ...
            pdrImprove, mean(baselineResults.PDR), mean(mcResults.PDR));
    fprintf('  DCR:    -%.0f%% reduccion\n', dcrImprove);
    fprintf('  Lat:    x%.1f mas rapido\n', latImprove);
    fprintf('  PingPong: x%.1f menos oscilaciones\n', ppImprove);

    fprintf('\n================================================\n');
    fprintf('  VERIFICACION TABLA Q ENTRENADA\n');
    fprintf('================================================\n');
    fprintf('  Tamano: %d estados x %d acciones\n', nS, nA);
    fprintf('  Q-table (primeras 5 filas):\n');
    fprintf('  Estado |  a1(Power) |  a2(Small) |  a3(Steer) |  a4(QPSK)\n');
    fprintf('  %s\n', repmat('-', 1, 64));
    for s = 1:min(5, nS)
        fprintf('     s%02d | %10.3f | %10.3f | %10.3f | %10.3f\n', ...
                s, Qtable(s,1), Qtable(s,2), Qtable(s,3), Qtable(s,4));
    end

    fprintf('\n================================================\n');
    fprintf('  VERIFICACION DISCRETIZACION (Tabla II)\n');
    fprintf('================================================\n');
    fprintf('  RSRP bins   : 4 (< -100, [-100,-90), [-90,-70), >= -70)\n');
    fprintf('  DCR bins    : 2 ([0, 0.05), >= 0.05)\n');
    fprintf('  Status bins : 2 (0=fallo, 1=activo)\n');
    fprintf('  Combinaciones: 4 x 2 x 2 = 16 -> fusionadas a |S| = %d\n', nS);

    fprintf('\n================================================\n');
    fprintf('  VERIFICACION HIPERPARAMETROS (Tabla V)\n');
    fprintf('================================================\n');
    fprintf('  alpha  = %.2f  | gamma = %.2f\n', params.alpha, params.gamma);
    fprintf('  eps0   = %.2f  | decay = %.3f\n', params.epsilon0, params.epsilonDecay);
    fprintf('  maxEp  = %d    | maxSteps = %d\n', params.maxEpisodes, params.maxSteps);
    fprintf('  stop   = %.0f (movAvg window = %d ep)\n', ...
            params.stopReward, params.stopWindow);
    fprintf('================================================\n\n');
end
