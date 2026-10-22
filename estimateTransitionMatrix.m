function P = estimateTransitionMatrix(chan, params)
%% =========================================================
%  estimateTransitionMatrix.m
%  Dimension: |S| x |A| x |S| = 10 x 4 x 10
% ==========================================================

    nS = 10; nA = 4;
    nPilotEp  = 200;
    maxSteps  = params.maxSteps;

    % Contadores de transiciones
    counts = zeros(nS, nA, nS);

    rng(0);  % semilla fija para estimacion

    for ep = 1:nPilotEp
        env = CellularEnv(chan, params);
        s = env.reset();
        for step = 1:maxSteps
            a = randi(nA);   % politica aleatoria
            [sNext, ~, done] = env.step(a);
            counts(s, a, sNext) = counts(s, a, sNext) + 1;
            s = sNext;
            if done; break; end
        end
    end

    % Normalizar a probabilidades
    P = zeros(nS, nA, nS);
    for s = 1:nS
        for a = 1:nA
            rowSum = sum(counts(s, a, :));
            if rowSum > 0
                P(s, a, :) = counts(s, a, :) / rowSum;
            else
                P(s, a, s) = 1.0;   % transicion identidad si no observada
            end
        end
    end

    % Verificacion: cada fila suma 1
    fprintf('Verificacion P(s|s,a): suma de filas\n');
    for s = 1:nS
        for a = 1:nA
            rowSum = sum(P(s, a, :));
            if abs(rowSum - 1.0) > 1e-10
                warning('Fila (s=%d,a=%d) no suma 1: %.6f', s, a, rowSum);
            end
        end
    end
    fprintf('  -> Todas las filas suman 1.0 (verificado).\n');

    % Guardar matriz
    save('TransitionMatrix_10x4x10.mat', 'P', 'counts');
    fprintf('  -> TransitionMatrix_10x4x10.mat guardada.\n');

    % Visualizar matriz marginalizada (promedio sobre acciones)
    P_marg = squeeze(mean(P, 2));   % 10 x 10
    fig = figure('Name', 'Matriz de Transicion MDP', ...
                 'Position', [100, 100, 560, 460], 'Color', 'white');
    imagesc(P_marg);
    colorbar;
    colormap(hot);
    xlabel('Estado siguiente s''', 'FontSize', 10);
    ylabel('Estado actual s', 'FontSize', 10);
    title('P(s''|s) marginalizado sobre acciones', 'FontSize', 10);
    xticks(1:nS); yticks(1:nS);
    xticklabels(arrayfun(@(x) sprintf('s%d',x), 1:nS, 'UniformOutput', false));
    yticklabels(arrayfun(@(x) sprintf('s%d',x), 1:nS, 'UniformOutput', false));
    set(gca, 'FontSize', 8, 'FontName', 'Helvetica');
    exportgraphics(fig, 'TransitionMatrix_Heatmap.png', 'Resolution', 200);
    fprintf('  -> TransitionMatrix_Heatmap.png guardada.\n');
end
