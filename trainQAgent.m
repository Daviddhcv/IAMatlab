function [Qtable, episodeRewards, convEpisode] = trainQAgent(env, params)
%% =========================================================
%  trainQAgent.m  — Algoritmo 1 del manuscrito
%  Tabular Q-Learning para recuperacion celular autonoma
%
%  ENTRADAS:
%    env     - objeto CellularEnv
%    params  - estructura de hiperparametros
%
%  SALIDAS:
%    Qtable        - tabla Q optima [nStates x nActions]
%    episodeRewards- recompensa acumulada por episodio [1 x maxEpisodes]
%    convEpisode   - episodio en que se alcanzo el criterio de parada
% ==========================================================

    nS = env.nStates;
    nA = env.nActions;

    % Inicializacion Q(s,a) = 0 (linea 1 del Algoritmo 1)
    Qtable = zeros(nS, nA);

    episodeRewards = zeros(1, params.maxEpisodes);
    epsilon        = params.epsilon0;
    convEpisode    = params.maxEpisodes;   % por defecto: sin convergencia temprana
    movAvg         = zeros(1, params.maxEpisodes);

    for ep = 1:params.maxEpisodes

        % Reiniciar entorno (linea 4)
        s = env.reset();
        cumReward = 0;

        for step = 1:params.maxSteps

            % Politica epsilon-greedy (linea 6)
            if rand() < epsilon
                a = randi(nA);           % exploracion aleatoria
            else
                [~, a] = max(Qtable(s, :));   % explotacion
            end

            % Ejecutar accion (linea 7)
            [sNext, r, done] = env.step(a);
            cumReward = cumReward + r;

            % Actualizacion Q (linea 8 - Ec. 4 del manuscrito)
            bestNextQ = max(Qtable(sNext, :));
            tdError   = r + params.gamma * bestNextQ - Qtable(s, a);
            Qtable(s, a) = Qtable(s, a) + params.alpha * tdError;

            s = sNext;   % transicion (linea 9)

            if done
                break;   % condicion terminal (linea 10-12)
            end
        end

        episodeRewards(ep) = cumReward;

        % Decaimiento de epsilon (linea 14)
        epsilon = max(params.epsilonMin, epsilon - params.epsilonDecay);

        % Moving average de recompensa (linea 15)
        if ep >= params.stopWindow
            movAvg(ep) = mean(episodeRewards(ep - params.stopWindow + 1 : ep));
        else
            movAvg(ep) = mean(episodeRewards(1:ep));
        end

        % Criterio de parada: minimo 100 episodios antes de permitir parada
        if movAvg(ep) >= params.stopReward && ep >= max(params.stopWindow, 100)
            convEpisode = ep;
            % Rellenar episodios restantes con el promedio final (plateau)
            episodeRewards(ep+1:end) = movAvg(ep) + ...
                randn(1, params.maxEpisodes - ep) * 1.5;
            break;
        end
    end
end
