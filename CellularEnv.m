classdef CellularEnv < handle
%% =========================================================
%  CellularEnv.m  — Entorno MDP de recuperacion celular
%  ==========================================================

    properties
        % Parametros de canal
        eta         % exponente path loss
        sigma_dB    % shadowing std (dB)
        lambdaFault % tasa de fallo Poisson
        cellRadius  % radio celda (m)
        fc_GHz      % frecuencia portadora
        vMax_kmh    % velocidad max UE

        % Hiperparametros de recompensa
        w1; w2; w3; w4;

        % Estado interno del entorno
        currentState    % indice de estado discreto [1..10]
        RSRP_dBm        % RSRP continua actual
        DCR             % call drop rate actual
        SINR_dB         % SINR actual (diagnostico)
        nodeStatus      % 0=fallo, 1=activo

        % Mapeo estado discreto -> espacio continuo
        nStates   % 10
        nActions  % 4

        % Log de telemetria (para Fig2)
        rsrpLog
        actionLog
        stepCount
    end

    properties (Constant)
        % Limites de discretizacion RSRP (Tabla II)
        RSRP_BINS = [-Inf, -100, -90, -70, Inf];   % 4 bins
        % DCR bins
        DCR_THRESH = 0.05;
        % Nombres de acciones
        ACTION_NAMES = {'Power +3dB', 'SmallCell ON', ...
                        'Traffic Steer', 'Fallback QPSK'};
    end

    methods
        %% Constructor
        function obj = CellularEnv(chan, params)
            obj.eta         = chan.eta;
            obj.sigma_dB    = chan.sigma_dB;
            obj.lambdaFault = chan.lambdaFault;
            obj.cellRadius  = chan.cellRadius;
            obj.fc_GHz      = chan.fc_GHz;
            obj.vMax_kmh    = chan.vMax_kmh;
            obj.w1 = params.w1;
            obj.w2 = params.w2;
            obj.w3 = params.w3;
            obj.w4 = params.w4;
            obj.nStates  = 10;
            obj.nActions = 4;
            obj.rsrpLog  = [];
            obj.actionLog = [];
            obj.stepCount = 0;
        end

        %% reset: reinicia el entorno al inicio de un episodio
        function s = reset(obj)
            obj.RSRP_dBm   = -70 + randn() * 5;   % condicion inicial moderada
            obj.DCR        = 0.01 * abs(randn());
            obj.nodeStatus = 1;
            obj.SINR_dB    = obj.computeSINR(obj.RSRP_dBm);
            obj.currentState = obj.discretize(obj.RSRP_dBm, obj.DCR, obj.nodeStatus);
            obj.rsrpLog   = obj.RSRP_dBm;
            obj.actionLog = 0;
            obj.stepCount = 0;
            s = obj.currentState;
        end

        %% step: ejecuta accion, retorna (nextState, reward, done)
        function [sNext, r, done] = step(obj, action)
            obj.stepCount = obj.stepCount + 1;

            % 1) Aplicar accion correctiva
            obj.applyAction(action);

            % 2) Evolucion estocastica del canal
            obj.updateChannel();

            % 3) Inyeccion de fallos Poisson
            faultOccurred = rand() < obj.lambdaFault;
            if faultOccurred && obj.nodeStatus == 1
                obj.nodeStatus = 0;   % fallo de nodo
            end

            % 4) Recuperacion automatica si accion lo permite
            if obj.nodeStatus == 0
                if action == 2 || action == 3  % SmallCell o Traffic Steering
                    if rand() < 0.85   % prob de recuperacion exitosa
                        obj.nodeStatus = 1;
                    end
                end
            end

            % 5) Calcular throughput delta (Mbps simulado)
            dThroughput = obj.computeThroughput(action);

            % 6) Indicador de fallo no recuperado
            failureIndicator = double(obj.nodeStatus == 0);

            % 7) Funcion de recompensa (Ec. 3 del manuscrito)
            r = obj.w1 * dThroughput ...
              - obj.w2 * obj.DCR ...
              - obj.w3 * failureIndicator ...
              - obj.w4;

            % 8) Discretizar nuevo estado
            obj.currentState = obj.discretize(obj.RSRP_dBm, obj.DCR, obj.nodeStatus);
            sNext = obj.currentState;

            % 9) Condicion terminal
            done = (obj.RSRP_dBm < -115) && (obj.nodeStatus == 0);

            % 10) Log telemetria
            obj.rsrpLog   = [obj.rsrpLog,   obj.RSRP_dBm];
            obj.actionLog = [obj.actionLog, action];
        end

        %% Getters para metricas de validacion
        function lat = getRestorationLatency(obj)
            % Tiempo de simulacion hasta primer action correctiva (ms)
            % Se define como primer paso donde action ~= ninguna
            firstAction = find(obj.actionLog > 0, 1, 'first');
            if isempty(firstAction)
                lat = NaN;
            else
                lat = firstAction * 0.005;  % 5 us por paso -> ms
            end
        end

        function sinr = getSINR(obj)
            sinr = obj.SINR_dB;
        end

        function rsrp = getRSRP(obj)
            rsrp = obj.RSRP_dBm;
        end

        function dcr = getDCR(obj)
            dcr = obj.DCR;
        end
    end

    %% ---- Metodos privados ---------------------------------
    methods (Access = private)

        %% Discretizacion del estado continuo (Tabla II)
        function s = discretize(obj, rsrp, dcr, status)
            % RSRP bin: 1..4
            rsrpBin = sum(rsrp >= obj.RSRP_BINS(2:end-1)) + 1;
            % DCR bin: 1..2
            dcrBin  = double(dcr >= obj.DCR_THRESH) + 1;
            % Status bin: 1..2
            statBin = status + 1;   % 0->1, 1->2

            % Cartesian product 4x2x2 = 16 combinaciones
            % Colapsadas a 10 estados (combinaciones de baja frecuencia fusionadas)
            rawIdx = (rsrpBin - 1) * 4 + (dcrBin - 1) * 2 + statBin;

            % Tabla de mapeo: 16 raw -> 10 estados
            mergeTable = [1,2,3,4,5,6,7,8,9,10,9,10,9,10,10,10];
            s = mergeTable(min(rawIdx, 16));
        end

        %% Modelo de canal: actualizacion por paso
        function updateChannel(obj)
            % Rayleigh fading (ganancia dB)
            rayFading_dB = 10 * log10(exprnd(1));

            % Shadowing log-normal: variacion lenta
            shadowDelta = randn() * 0.5;   % variacion incremental suave

            % Movilidad UE: cambio de distancia
            vMs = obj.vMax_kmh / 3.6 * rand();
            dt  = 0.001;   % 1 ms por paso
            dDist = vMs * dt;

            % Path loss (COST-231 simplificado a 3.5 GHz)
            dist = obj.cellRadius * (0.1 + 0.9 * rand());
            PL_dB = 30 + 37.6 * log10(max(dist, 1)) + ...
                    10 * log10((obj.fc_GHz / 1.8)^2);

            % RSRP resultante
            Ptx_dBm = 46;  % potencia de transmision macro (dBm)
            shadow   = randn() * obj.sigma_dB;
            obj.RSRP_dBm = Ptx_dBm - PL_dB + shadow + rayFading_dB;

            % Limites fisicos plausibles
            obj.RSRP_dBm = max(min(obj.RSRP_dBm, -44), -120);

            % DCR: correlacionado con degradacion RSRP
            if obj.RSRP_dBm < -100
                obj.DCR = min(0.15, obj.DCR + 0.01 * abs(randn()));
            else
                obj.DCR = max(0, obj.DCR - 0.005 + 0.003 * rand());
            end

            obj.SINR_dB = obj.computeSINR(obj.RSRP_dBm);
        end

        %% Modelo de SINR (dB)
        function sinr = computeSINR(~, rsrp_dBm)
            noise_dBm  = -104;  % ruido termico a 10 MHz
            interf_dBm = -95;   % interferencia media
            signal_mW  = 10^((rsrp_dBm) / 10);
            noise_mW   = 10^((noise_dBm + interf_dBm) / 10);
            sinr = 10 * log10(signal_mW / noise_mW);
        end

        %% Efecto de cada accion sobre el entorno
        function applyAction(obj, action)
            % Efectividad condicional al estado: acciones incorrectas
            % para el contexto actual tienen efecto reducido o nulo,
            % forzando al agente a aprender la politica correcta.
            switch action
                case 1  % Power boost +3 dB — util solo si RSRP moderado
                    if obj.RSRP_dBm >= -100
                        obj.RSRP_dBm = obj.RSRP_dBm + 3.0;
                        obj.DCR = max(0, obj.DCR * 0.88);
                    else
                        % Ineficaz en degradacion severa
                        obj.RSRP_dBm = obj.RSRP_dBm + 0.5;
                    end

                case 2  % Small Cell ON — util en cobertura insuficiente
                    if obj.RSRP_dBm < -90
                        obj.RSRP_dBm = obj.RSRP_dBm + 7.0;
                        obj.DCR = max(0, obj.DCR * 0.72);
                    else
                        % Innecesario si cobertura es buena
                        obj.DCR = max(0, obj.DCR * 0.95);
                    end

                case 3  % Traffic Steering — util en fallo de nodo
                    if obj.nodeStatus == 0
                        obj.DCR = max(0, obj.DCR * 0.55);
                        obj.RSRP_dBm = obj.RSRP_dBm + 3.0;
                    else
                        obj.DCR = max(0, obj.DCR * 0.80);
                    end

                case 4  % Fallback QPSK — util en interferencia severa
                    if obj.SINR_dB < 0
                        obj.DCR = max(0, obj.DCR * 0.70);
                    else
                        obj.DCR = max(0, obj.DCR * 0.92);
                    end
            end
            obj.RSRP_dBm = max(min(obj.RSRP_dBm, -44), -120);
        end

        %% Throughput delta simulado (Mbps) segun estado y accion
        function dT = computeThroughput(obj, action)
            % SINR acotado para evitar explosion de throughput
            sinr_clip = max(min(obj.SINR_dB, 30), -10);
            sinrLin   = 10^(sinr_clip / 10);
            BW_MHz    = 20;
            % Eficiencia espectral maxima practica: 8 bps/Hz (64-QAM 3/4)
            spectEff  = min(log2(1 + sinrLin), 8.0);
            maxTh     = BW_MHz * spectEff;   % Mbps, max ~160

            if obj.nodeStatus == 1
                actionBoost = [1.0, 1.5, 1.2, 0.8];
                % Factor de utilizacion 0.05 -> max ~6 Mbps de delta
                dT = min(maxTh * actionBoost(action) * 0.05, 8.0);
            else
                dT = 0.1 * double(action == 2 || action == 3);
            end
            dT = max(dT, 0);
        end
    end
end
