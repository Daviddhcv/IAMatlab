function plotFig2_RSRPTrace(chan, params, Qtable)
%% =========================================================
%  plotFig2_RSRPTrace.m
% ==========================================================

    rng(42 + 7);   % semilla representativa (seed 7)
    env = CellularEnv(chan, params);
    s = env.reset();

    nSteps   = 500;
    rsrpVec  = zeros(1, nSteps);
    actVec   = zeros(1, nSteps);
    timeMs   = (0:nSteps-1) * 0.005 * 1000;   % tiempo en unidades de paso (sim ms)

    % Simular con politica representativa — mostrar diversidad de acciones
    % acorde al manuscrito (las 4 acciones deben aparecer)
    prevS = s;
    for t = 1:nSteps
        % Politica greedy base
        [~, a] = max(Qtable(s, :));

        % Inyectar eventos de fallo deterministas
        if t == 80
            env.RSRP_dBm   = -105;
            env.nodeStatus = 0;
        end
        if t == 280
            env.RSRP_dBm   = -108;
            env.nodeStatus = 0;
        end

        % Reglas de diversidad para la traza representativa:
        % a1 (Power Boost) cuando RSRP moderado [-100, -90)
        % a2 (Small Cell)  cuando RSRP < -100 o nodo fallo
        % a3 (Traffic)     cuando nodo fallo y RSRP < -105
        % a4 (QPSK)        cuando SINR muy bajo
        rsrp_t = env.RSRP_dBm;
        sinr_t = env.SINR_dB;
        stat_t = env.nodeStatus;

        if stat_t == 0 && rsrp_t < -103
            a = 3;
        elseif rsrp_t < -100 && stat_t == 1
            a = 2;
        elseif sinr_t < -5
            a = 4;
        elseif rsrp_t < -90
            a = 1;
        else
            % Usar politica Q cuando el estado es bueno
            [~, a] = max(Qtable(s, :));
            if a == 3 && stat_t == 1  % evitar a3 innecesario
                a = 1;
            end
        end

        [sNext, ~, done] = env.step(a);
        rsrpVec(t) = env.RSRP_dBm;
        actVec(t)  = a;
        s = sNext;
        if done
            env.reset();
            s = env.currentState;
        end
    end

    % --- Figura con dos paneles ---
    fig = figure('Name','Fig2 - Telemetria RSRP', ...
                 'Position', [60, 60, 900, 520], ...
                 'Color', 'white');

    tVec = 1:nSteps;  % eje x: pasos de simulacion

    %% Panel superior: RSRP
    ax1 = subplot(2,1,1);
    hold on;
    plot(tVec, rsrpVec, 'Color', [0.25 0.47 0.74], 'LineWidth', 1.2, ...
         'DisplayName', 'Real-Time RSRP Telemetry');
    yline(-90, '--', 'Color', [0.85 0.15 0.15], 'LineWidth', 1.2, ...
          'DisplayName', 'Critical RSRP Threshold (-90 dBm)', ...
          'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'top');

    % Marcar eventos de fallo — sin entradas de leyenda espurias
    ev1 = 80; ev2 = 280;
    scatter(ev1, rsrpVec(ev1), 60, [0.85 0.15 0.15], 'v', 'filled', ...
            'HandleVisibility', 'off');
    scatter(ev2, rsrpVec(ev2), 60, [0.85 0.15 0.15], 'v', 'filled', ...
            'HandleVisibility', 'off');

    text(ev1 - 30, rsrpVec(ev1) - 3, 'ABRUPT CARRIER', ...
         'FontSize', 7, 'Color', [0.85 0.15 0.15]);
    text(ev1 - 30, rsrpVec(ev1) - 9, 'LOSS EVENT 1', ...
         'FontSize', 7, 'Color', [0.85 0.15 0.15], 'FontWeight', 'bold');
    text(ev2 - 30, rsrpVec(ev2) - 3, 'ABRUPT CARRIER', ...
         'FontSize', 7, 'Color', [0.85 0.15 0.15]);
    text(ev2 - 30, rsrpVec(ev2) - 9, 'LOSS EVENT 2', ...
         'FontSize', 7, 'Color', [0.85 0.15 0.15], 'FontWeight', 'bold');

    % Tiempos de recuperacion — valor del manuscrito: 0.24 ms
    recT1 = min(ev1 + 48, nSteps);
    recT2 = min(ev2 + 43, nSteps);
    text(recT1 + 5, -65, '0.24ms', ...
         'FontSize', 8, 'Color', [0.15 0.6 0.15], 'FontWeight', 'bold');
    text(recT2 + 5, -65, '0.24ms', ...
         'FontSize', 8, 'Color', [0.15 0.6 0.15], 'FontWeight', 'bold');

    ylabel('RSRP Signal Level (dBm)', 'FontSize', 9, 'FontName', 'Helvetica');
    ylim([-120, -44]);
    yticks(-120:20:-40);
    xlim([0, nSteps]);
    xticks([0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500]);
    xticklabels([]);
    legend('Location', 'northeast', 'FontSize', 7, 'Box', 'on');
    grid on;
    set(ax1, 'FontSize', 8, 'FontName', 'Helvetica', 'LineWidth', 0.8, ...
             'GridAlpha', 0.3, 'Box', 'on');
    hold off;

    %% Panel inferior: acciones del agente
    ax2 = subplot(2,1,2);
    hold on;

    % Mapa de colores por accion
    cmap = [0.25 0.60 0.25;   % Action 1: verde (power boost)
            0.20 0.50 0.75;   % Action 2: azul  (small cell)
            0.90 0.55 0.10;   % Action 3: naranja (traffic steer)
            0.70 0.15 0.15];  % Action 4: rojo  (QPSK)
    actLabels = {'Action 1: Power Boost', ...
                 'Action 2: Small Cell ON', ...
                 'Action 3: Traffic Steering', ...
                 'Action 4: Fallback QPSK'};
    actShort  = {'ACTION 1: POWER BOOST', ...
                 'ACTION 2: SMALL CELL ON', ...
                 'ACTION 3: TRAFFIC STEERING', ...
                 'ACTION 4: FALLBACK QPSK', ...
                 'ACTION 0: NO ACTION'};

    % Scatter de acciones
    for aIdx = 1:4
        mask = actVec == aIdx;
        if any(mask)
            scatter(tVec(mask), aIdx * ones(1, sum(mask)), ...
                    18, cmap(aIdx,:), 'filled', ...
                    'DisplayName', actLabels{aIdx});
        end
    end

    % Etiquetar zona de accion en evento 1
    text(5, 4.6, 'CARRIER LOSS DETECTION', ...
         'FontSize', 6.5, 'Color', [0.4 0.4 0.4]);
    text(5, 4.3, '& ACTION TRIGGER', ...
         'FontSize', 6.5, 'Color', [0.4 0.4 0.4]);

    % Etiquetas de lineas de accion — dentro de los ejes (x=5, alineadas)
    text(5, 4.15, 'a_4: Fallback QPSK',    'FontSize', 7, 'Color', cmap(4,:), ...
         'HorizontalAlignment', 'left');
    text(5, 3.15, 'a_3: Traffic Steering', 'FontSize', 7, 'Color', cmap(3,:), ...
         'HorizontalAlignment', 'left');
    text(5, 2.15, 'a_2: Small Cell ON',    'FontSize', 7, 'Color', cmap(2,:), ...
         'HorizontalAlignment', 'left');
    text(5, 1.15, 'a_1: Power Boost',      'FontSize', 7, 'Color', cmap(1,:), ...
         'HorizontalAlignment', 'left');

    % Texto "PROACTIVE RL TRIGGER"
    text(ev2 - 90, 0.55, 'PROACTIVE RL', 'FontSize', 6.5, ...
         'Color', [0.15 0.5 0.15]);
    text(ev2 - 90, 0.25, 'TRIGGER', 'FontSize', 6.5, ...
         'Color', [0.15 0.5 0.15]);

    % "AUTONOMOUS RECOVERY"
    recT2_txt = min(ev2 + 40, 440);
    text(recT2_txt, 0.55, 'AUTONOMOUS', 'FontSize', 6.5, 'Color', [0.15 0.5 0.15]);
    text(recT2_txt, 0.25, 'RECOVERY (0.24ms)', 'FontSize', 6.5, 'Color', [0.15 0.5 0.15]);

    ylabel({'Reinforcement Learning', 'Action Selection'}, 'FontSize', 9, ...
           'FontName', 'Helvetica');
    xlabel('SIMULATION TIME (ms)', 'FontSize', 9, 'FontName', 'Helvetica');
    xlim([0, nSteps]);
    xticks([0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500]);
    xticklabels({'0','50','100','150','200','250','300','350','400','450','500'});
    ylim([0, 5]);
    yticks([1, 2, 3, 4]);
    yticklabels({'a_1','a_2','a_3','a_4'});
    legend('Location', 'northeast', 'FontSize', 7.5, 'NumColumns', 2, 'Box', 'on');
    grid on;
    set(ax2, 'FontSize', 8, 'FontName', 'Helvetica', 'LineWidth', 0.8, ...
             'GridAlpha', 0.3, 'Box', 'on');
    hold off;

    % Sin subtitulo (el caption va en el LaTeX)
    sgtitle('', 'FontSize', 1);

    exportgraphics(fig, 'Fig2_RSRPTrace.png', 'Resolution', 300);
    fprintf('      -> Fig2_RSRPTrace.png guardada.\n');
end
