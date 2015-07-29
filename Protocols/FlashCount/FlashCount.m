
function FlashCount

% This protocol plays a number of flashes on the left and right and then the subject is rewarded for poking on the side with more flashes.
% Written by Jeffrey Erlich, 7/2015.
%
global DATA
global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CurrentBlock = 1; % Training level % 1 = Direct Delivery at both ports 2 = Poke for delivery
    S.GUI.RewardAmount = 5; %ul
    S.GUI.PortOutRegDelay = 0.5; % How long the mouse must remain out before poking back in
end


CPWR = 100;
FPWR = 150;
flashtime = 0.01;

%% Define trials
nTrials = 10;
rightTrial = rand(nTrials,1)<0.5;
trialDur = rand(nTrials,1)*5+1;
deltaF = nan(nTrials,1);
sumF = deltaF;
hits = deltaF;
viol = deltaF;

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots

%% Main trial loop
currentTrial = 0;
nGood = 0;
while nGood < nTrials
    currentTrial = currentTrial + 1;
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    % Update reward amounts
    leftflashes = [];
    rightflashes = [];
    if rightTrial(currentTrial)
        rProb = 0.6;
        lProb = 0.4;
    else
        rProb = 0.4;
        lProb = 0.6;
    end
    
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    % Turn on the center port and wait for entry. Pokes in other ports are violations.
    sma = AddState(sma, 'Name', 'WaitForPoke1', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'preflash', 'Port3In', 'violationstate','Port1In', 'violationstate',},...
        'OutputActions', {'PWM2',50});
    sma = AddState(sma,'Name','preflash', ...
        'Timer', rand*0.15+0.150, ...
        'StateChangeConditions',{'Tup', 'flash00_on', 'Port2Out' ,'violationstate'},...
        'OutputActions',{'PWM2',CPWR});
    
    dur = 0;
    ind = 0;
    
    
    while dur<trialDur(currentTrial)
        IFI = rand*0.35+0.05;
        thisR = rand<rProb;
        thisL = rand<lProb;
        
        if thisR && thisL
            leftflashes = [leftflashes dur];
            rightflashes = [rightflashes dur];
            output = {'PWM1',FPWR,'PWM3',FPWR,'PWM2',CPWR};
        elseif thisR
            rightflashes = [rightflashes dur];
            output = {'PWM3',FPWR,'PWM2',CPWR};
            
        elseif thisL
            leftflashes = [leftflashes dur];
            output = {'PWM1',FPWR,'PWM2',CPWR};
        else
            output = {'PWM2',CPWR};
        end
        
        sma = AddState(sma,'Name',sprintf('flash%02d_on',ind), ...
            'Timer', flashtime, ...
            'StateChangeConditions',{'Tup', sprintf('flash%02d_off',ind), 'Port2Out' ,'violationstate'},...
            'OutputActions', output);
        sma = AddState(sma,'Name',sprintf('flash%02d_off',ind), ...
            'Timer', IFI, ...
            'StateChangeConditions',{'Tup', sprintf('flash%02d_on',ind+1), 'Port2Out' ,'violationstate'},...
            'OutputActions', {'PWM2',CPWR});
        
        
        ind = ind+1;
        dur = dur + IFI + flashtime;
        
    end
    deltaF(currentTrial) = numel(rightflashes) - numel(leftflashes);
    sumF(currentTrial) = numel(rightflashes) + numel(leftflashes);
    
    
    sma = AddState(sma,'Name',sprintf('flash%02d_on',ind), ...
        'Timer', 0.0001, ...
        'StateChangeConditions',{'Tup', 'wait_for_spoke'},...
        'OutputActions', {});
    
    if deltaF(currentTrial)>0
        hitPoke = 'Port3In';
        missPoke = 'Port1In';
    elseif deltaF(currentTrial)<0
        hitPoke = 'Port1In';
        missPoke = 'Port3In';
    else
        if rand<0.5
            hitPoke = 'Port1In';
            missPoke = 'Port3In';
        else
            hitPoke = 'Port3In';
            missPoke = 'Port1In';
        end
    end
    
    
    sma = AddState(sma,'Name','wait_for_spoke', ...
        'Timer', 0, ...
        'StateChangeConditions',{hitPoke, 'reward_state',missPoke,'error_state'},...
        'OutputActions', {'PWM1',100,'PWM3',100});
    
    sma = AddState(sma, 'Name', 'reward_state', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'PWM5',255});
    
    
    sma = AddState(sma, 'Name', 'error_state', ...
        'Timer', 1.5,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'PWM4',255});
    
    sma = AddState(sma, 'Name', 'violationstate', ...
        'Timer', 0.25,...
        'StateChangeConditions', {'Tup', 'v1'},...
        'OutputActions', {'PWM4',188});
    
    for vx=2:12
        sma = AddState(sma, 'Name', sprintf('v%d',vx-1), ...
            'Timer', 0.25,...
            'StateChangeConditions', {'Tup', sprintf('v%do',vx-1)},...
            'OutputActions', {});
        
        sma = AddState(sma, 'Name', sprintf('v%do',vx-1), ...
            'Timer', 0.25,...
            'StateChangeConditions', {'Tup', sprintf('v%d',vx)},...
            'OutputActions', {'PWM4',188});
    end
    
    sma = AddState(sma, 'Name', 'v12', ...
        'Timer', 0.01,...
        'StateChangeConditions', {'Tup','ITI'},...
        'OutputActions', {});
    
    
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', rand*4,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        %        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        %        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        peh(currentTrial).states = BpodSystem.Data.RawEvents.Trial{1}.States;
        peh(currentTrial).events = BpodSystem.Data.RawEvents.Trial{1}.Events;
        
        tS = peh(currentTrial).states;
        
        if ~isnan(tS.violationstate)
            viol(currentTrial) = true;
        else
            viol(currentTrial) = false;
            nGood = nGood + 1;
            if ~isnan(tS.reward_state)
                hits(currentTrial) = true;
            else
                hits(currentTrial) = false;
            end
            
            if deltaF(currentTrial)
            end
            
        end
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
end

DATA.hits = hits;
DATA.deltaF = deltaF;
DATA.sumF = sumF;

wr = 

[bx,by,be] = binned(deltaF, 


% keyboard
%
% function y=HitSound
%
%     tx = 0:
%
% function y=MissSound
%
% function y=ViolationSound
%
% function y=GoSound







