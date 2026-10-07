% =========================================================================
% Autonomous Cellular Service Recovery and Link Reconnection via Q-Learning
% Author: David H. C\'ardenas Villacr\'es
% GISTEL Research Group, Universidad Polit\'ecnica Salesiana
% =========================================================================

clear; clc; close all;
rng(42); % Semilla determinista para reproducibilidad

% 1. Definición de las dimensiones del espacio de estados y acciones
numStates = 10;   % Estados discretos de degradación de la red (1 al 10)
numActions = 4;   % Acciones de reconexión

% 2. Especificación formal de Observación y Acción en formato discreto/finito
obsInfo = rlFiniteSetSpec(1:numStates);
obsInfo.Name = 'Cellular Degradation States';

actInfo = rlFiniteSetSpec([1, 2, 3, 4]);
actInfo.Name = 'Reconnection Control Actions';

% 3. Creación del entorno personalizado mediante funciones MATLAB
env = rlFunctionEnv(obsInfo, actInfo, @localStepFcn, @localResetFcn);

% 4. Configuración de la tabla Q y creación del Critic Q-Value
qTable = rlTable(obsInfo, actInfo);
critic = rlQValueFunction(qTable, obsInfo, actInfo);

% 5. Configuración de las opciones del agente y el objeto rlQAgent
agentOpts = rlQAgentOptions(...
    'DiscountFactor', 0.95);

% Configuración de los parámetros de exploración mediante dot notation
agentOpts.EpsilonGreedyExploration.Epsilon = 0.1;
agentOpts.EpsilonGreedyExploration.EpsilonDecay = 0.001;

agent = rlQAgent(critic, agentOpts);

% 6. Opciones de entrenamiento del modelo
maxEpisodes = 500;
maxSteps = 1000;
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', maxEpisodes, ...
    'MaxStepsPerEpisode', maxSteps, ...
    'ScoreAveragingWindowLength', 20, ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 85);

% 7. Ejecución del proceso de entrenamiento en MATLAB
disp('Iniciando el entrenamiento del agente de autorreparación celular...');
trainingStats = train(agent, env, trainOpts);
disp('Entrenamiento finalizado con éxito.');

% 8. Validación de la política aprendida mediante simulación
simOptions = rlSimulationOptions('MaxSteps', 50);
experience = sim(env, agent, simOptions);
disp('Validación y despliegue completados.');


% =========================================================================
% Funciones auxiliares de Entorno (Reset y Step)
% =========================================================================
function [InitialObservation, InitialState] = localResetFcn()
    InitialState = randi([1, 3]); 
    InitialObservation = InitialState;
end

function [NextObs, Reward, IsDone, NextState] = localStepFcn(Action, State)
    transitionNoise = randi([-1, 1]);
    NextState = min(max(State + transitionNoise + (Action > 2), 1), 10);
    NextObs = NextState;
    
    if NextState <= 3
        Reward = 10; % Red estable o restaurada
    elseif NextState >= 8
        Reward = -10; % Falla crítica de servicio
    else
        Reward = 1; % Degradación moderada
    end
    
    IsDone = (NextState == 10); 
end