function bestParams = gridSearchHyperparams(chan)
%% =========================================================
%  gridSearchHyperparams.m
%  Retorna la combinacion con mayor recompensa promedio.
% ==========================================================

    alphaVals = [0.01, 0.05, 0.1];
    gammaVals = [0.90, 0.95, 0.99];
    nPilot    = 10;

    results = struct();
    results.alpha  = [];
    results.gamma  = [];
    results.reward = [];

    fprintf('Grid search de hiperparametros (%d x %d x %d pilotos)...\n', ...
            length(alphaVals), length(gammaVals), nPilot);
    fprintf('  alpha | gamma | Recompensa promedio\n');
    fprintf('  %s\n', repmat('-', 1, 40));

    bestReward = -Inf;
    bestAlpha  = 0.05;
    bestGamma  = 0.95;

    for ai = 1:length(alphaVals)
        for gi = 1:length(gammaVals)
            params.alpha        = alphaVals(ai);
            params.gamma        = gammaVals(gi);
            params.epsilon0     = 0.10;
            params.epsilonMin   = 0.01;
            params.epsilonDecay = 0.001;
            params.maxEpisodes  = 200;   % reducido para piloto
            params.maxSteps     = 100;
            params.stopWindow   = 20;
            params.stopReward   = 85;
            params.w1 = 1.2; params.w2 = 2.5;
            params.w3 = 50.0; params.w4 = 0.1;

            pilotRewards = zeros(1, nPilot);
            for k = 1:nPilot
                rng(100 + k);
                env = CellularEnv(chan, params);
                [~, episodeRewards, ~] = trainQAgent(env, params);
                pilotRewards(k) = mean(episodeRewards(max(1,end-19):end));
            end

            avgRew = mean(pilotRewards);
            fprintf('  %.2f  | %.2f  | %.2f +/- %.2f\n', ...
                    alphaVals(ai), gammaVals(gi), avgRew, std(pilotRewards));

            results.alpha(end+1)  = alphaVals(ai);
            results.gamma(end+1)  = gammaVals(gi);
            results.reward(end+1) = avgRew;

            if avgRew > bestReward
                bestReward = avgRew;
                bestAlpha  = alphaVals(ai);
                bestGamma  = gammaVals(gi);
            end
        end
    end

    fprintf('\n  >> Mejores hiperparametros: alpha=%.2f, gamma=%.2f (Recompensa=%.2f)\n', ...
            bestAlpha, bestGamma, bestReward);

    bestParams.alpha = bestAlpha;
    bestParams.gamma = bestGamma;
    bestParams.gridResults = results;

    % Figura de heat-map
    R = reshape(results.reward, length(alphaVals), length(gammaVals));
    fig = figure('Name', 'Grid Search', 'Position', [100, 100, 500, 380], ...
                 'Color', 'white');
    heatmap(string(gammaVals), string(alphaVals), R, ...
            'Title', 'Grid Search: Recompensa promedio (alpha x gamma)', ...
            'XLabel', 'Gamma (\gamma)', ...
            'YLabel', 'Alpha (\alpha)', ...
            'Colormap', parula, ...
            'FontSize', 10);
    exportgraphics(fig, 'GridSearch_Heatmap.png', 'Resolution', 200);
    fprintf('  -> GridSearch_Heatmap.png guardada.\n');
end
