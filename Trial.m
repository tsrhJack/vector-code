classdef Trial < handle

    properties

        fileName
        Folder
        trial_type
        sides
        cycle_info

        RCycles
        LCycles
        LNumCycles
        RNumCycles
        CycleNorm

        LFootStrikeEvents
        LToeOffEvents
        LGeneralEvents
        RFootStrikeEvents
        RToeOffEvents
        RGeneralEvents

        DataArray
        GaitCycle


        flag = 0;
        reasonForFlag

        variablePullResults = []
        variablePullTiming = []
        vectorCodeResults = []


    end

    methods

        function validateProperties(trial)
            if isempty(trial.fileName)
                trial.flag = true;
                trial.reasonForFlag = 'file name was empty';
            end
            if isempty(trial.trial_type)
                trial.flag = true;
                trial.reasonForFlag = 'trial type column was empty';
            end
            if isempty(trial.sides)
                trial.flag = true;
                trial.reasonForFlag = 'side column was empty';
            end
            if isempty(trial.cycle_info)
                trial.flag = true;
                trial.reasonForFlag = 'cycle info column was empty';
            end
        end

        function getEvents(trial, C3DCom, Variables)

            global OutputLabels;
            global numSteps;
            global Normalization;

            trial.RFootStrikeEvents=0;
            trial.RToeOffEvents=0;
            trial.RGeneralEvents=0;
            trial.LFootStrikeEvents=0;
            trial.LToeOffEvents=0;
            trial.LGeneralEvents=0;

            Num_Variables = numel(Variables);
             

            fprintf('Importing events from C3D file...\n')
            Startframe = C3DCom.GetVideoFrame(0);
            Endframe = C3DCom.GetVideoFrame(1);
            SampleRate = C3DCom.GetVideoFrameRate;

            EvIndex = C3DCom.GetParameterIndex('EVENT','LABELS'); %sets call type
            EvItems = double(C3DCom.GetParameterLength(EvIndex)); %gets total# events
            signalname = upper('AH1309_RepR.c3d');
            signal_index = -1;

            bIndex = C3DCom.GetParameterIndex('EVENT', 'CONTEXTS'); %sets call type
            cIndex = C3DCom.GetParameterIndex('EVENT', 'LABELS');
            dIndex = C3DCom.GetParameterIndex('EVENT', 'TIMES');
            eIndex = C3DCom.GetParameterIndex('EVENT', 'ICON_IDS');
            gIndex = C3DCom.GetParameterIndex('EVENT','USED');
            fIndex = C3DCom.GetParameterIndex('EVENT','SUBJECTS');
            hIndex = C3DCom.GetParameterIndex('EVENT','DESCRIPTIONS');
            iIndex = C3DCom.GetParameterIndex('EVENT','GENERIC_FLAGS');

            icountLFS = 1;
            icountLTO = 1;
            icountLGE = 1;
            icountRFS = 1; 
            icountRTO = 1;
            icountRGE = 1;
                
            for i=1:EvItems
                target_name = C3DCom.GetParameterValue(EvItems, i-1);
                newstring = target_name(1:min(findstr(target_name, ' '))-1);
                if strmatch(newstring, [], 'exact'),
                    newstring = target_name;
                end
                if strmatch(upper(newstring), signalname, 'exact') == 1,
                    signal_index = i-1;
                end
                
                bIndex = C3DCom.GetParameterIndex('EVENT', 'CONTEXTS'); %set call type
                cIndex = C3DCom.GetParameterIndex('EVENT', 'LABELS'); %set call type
                dIndex = C3DCom.GetParameterIndex('EVENT', 'TIMES'); %set call type

                %gets the context and type of event (Label)
                txtRawtmp = [C3DCom.GetParameterValue(bIndex, i-1),C3DCom.GetParameterValue(cIndex, i-1)];
                %gets the event time for that event (note, events are stored in even
                %numbered holders only
                timeRaw = double(C3DCom.GetParameterValue(dIndex, i*2-1));
                
                if strmatch(upper(txtRawtmp),'RIGHTFOOT OFF') 
                   trial.RToeOffEvents(icountRTO) = timeRaw; % gets time for event
                   trial.RToeOffEvents(icountRTO) = trial.RToeOffEvents(icountRTO)*SampleRate+1; % converts to frames
                   icountRTO = icountRTO + 1;
                elseif strmatch(upper(txtRawtmp),'LEFTFOOT OFF')
                   trial.LToeOffEvents(icountLTO) = timeRaw;
                   trial.LToeOffEvents(icountLTO) = trial.LToeOffEvents(icountLTO)*SampleRate+1;
                   icountLTO = icountLTO + 1;
                elseif strmatch(upper(txtRawtmp),'RIGHTFOOT STRIKE') 
                   trial.RFootStrikeEvents(icountRFS) = timeRaw;
                   trial.RFootStrikeEvents(icountRFS) = trial.RFootStrikeEvents(icountRFS)*SampleRate+1;
                   icountRFS = icountRFS+1;
                elseif strmatch(upper(txtRawtmp),'LEFTFOOT STRIKE')
                   trial.LFootStrikeEvents(icountLFS) = timeRaw;
                   trial.LFootStrikeEvents(icountLFS) = trial.LFootStrikeEvents(icountLFS)*SampleRate+1;
                   icountLFS = icountLFS+1;
                elseif strmatch(upper(txtRawtmp),'RIGHTEVENT') 
                   trial.RGeneralEvents(icountRGE) = timeRaw;
                   trial.RGeneralEvents(icountRGE) =trial.RGeneralEvents(icountRGE)*SampleRate+1;
                   icountRGE = icountRGE + 1;
                elseif strmatch(upper(txtRawtmp),'LEFTEVENT')   
                   trial.LGeneralEvents(icountLGE) = timeRaw;
                   trial.LGeneralEvents(icountLGE) = trial.LGeneralEvents(icountLGE)*SampleRate+1;
                   icountLGE = icountLGE + 1;
                elseif strmatch(upper(txtRawtmp),'GENERALEVENT')    
                end
               
            end


            % sorts the events into appropriate order
            trial.RFootStrikeEvents = sort(trial.RFootStrikeEvents);
            trial.RToeOffEvents = sort(trial.RToeOffEvents);
            trial.RGeneralEvents = sort(trial.RGeneralEvents);
            trial.LFootStrikeEvents = sort(trial.LFootStrikeEvents);
            trial.LToeOffEvents = sort(trial.LToeOffEvents);
            trial.LGeneralEvents = sort(trial.LGeneralEvents);

            %% Calculate #cycles for normalization Schemes that begin and end with FS ...
            % with 5 events.

            if Normalization == 1 || Normalization ==2 
                
                if trial.LFootStrikeEvents > 1 % determines the number of cycles
                    trial.LNumCycles = length(trial.LFootStrikeEvents)-1;
                    trial.LCycles = zeros(1,5);
                else
                    trial.LNumCycles = 0; % if only 1 FS, than no cycles exist
                end

                if trial.RFootStrikeEvents > 1
                    trial.RNumCycles = length(trial.RFootStrikeEvents)-1;
                    trial.RCycles = zeros(1,5);
                else
                    trial.RNumCycles = 0;
                end
            end
             
            %% Calculatae#cycles for normalization scheme that begin/end with FS with
            % only 4 events
             
            if Normalization == 3 || Normalization == 4 
                
                if trial.LFootStrikeEvents > 1 % determines the number of cycles
                    trial.LNumCycles = length(trial.LFootStrikeEvents)-1;
                    trial.LCycles = zeros(1,4);
                else
                    trial.LNumCycles = 0; % if only 1 FS, than no cycles exist
                end

                if trial.RFootStrikeEvents > 1
                    trial.RNumCycles = length(trial.RFootStrikeEvents)-1;
                    trial.RCycles = zeros(1,4);
                else
                    trial.RNumCycles = 0;
                end
            end
             
             
            %% Calcuate #cycles for those that start with FS and end with GE
            % Also determines cycle events

            if Normalization == 5
                % CYCLES LEFT
                if length(trial.LFootStrikeEvents) > length(trial.LGeneralEvents)
                   trial.LNumCycles = length(trial.LGeneralEvents);
                   trial.LCycles = zeros(1,3);
                elseif length(trial.LFootStrikeEvents) < length(trial.LGeneralEvents)
                    trial.LNumCycles = length(trial.LFootStrikeEvents);
                    trial.LCycles = zeros(1,3);
                elseif length(trial.LFootStrikeEvents)== length(trial.LGeneralEvents) && length(trial.LFootStrikeEvents) > 0
                    trial.LNumCycles = length(trial.LFootStrikeEvents);
                    trial.LCycles = zeros(1,3);
                else
                    trial.LNumCycles = 0;
                end
                % #CYCLES RIGHT
                if length(trial.RFootStrikeEvents) > length(trial.RGeneralEvents)
                    trial.RNumCycles = length(trial.RGeneralEvents);
                    trial.RCycles = zeros(1,3);
                elseif length(trial.RFootStrikeEvents) < length(trial.RGeneralEvents)
                    trial.RNumCycles = length(trial.RFootStrikeEvents);
                    trial.RCycles = zeros(1,3);
                elseif length(trial.RFootStrikeEvents)== length(trial.RGeneralEvents) && length(trial.RFootStrikeEvents)>0
                    trial.RNumCycles = length(trial.RFootStrikeEvents);
                    trial.RCycles = zeros(1,3);
                else
                    trial.RNumCycles = 0;
                end
            

                % Create cycles L
                for i=1:trial.LNumCycles %Sets events for Left Side
                    trial.LCycles(i,1) = trial.LFootStrikeEvents(i); %  FS starts cycle
                    if i<trial.LNumCycles
                        NextFS = trial.LFootStrikeEvents(i+1);
                        for k=1:length(trial.LGeneralEvents)
                            if  trial.LGeneralEvents(k) > trial.LCycles(i,1) && trial.LGeneralEvents(k)<NextFS
                                trial.LCycles(i,3) = trial.LGeneralEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.LGeneralEvents)
                            if trial.LGeneralEvents(k) > trial.LCycles(i,1)
                                trial.LCycles(i,3) = trial.LGeneralEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.LToeOffEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.LToeOffEvents(j) > trial.LCycles(i,1) && trial.LToeOffEvents(j) < trial.LCycles(i,3)
                            trial.LCycles(i,2) = trial.LToeOffEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,3,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,3)-trial.LCycles(i,1))*100;
                end
                % Create cycles R
                for i=1:trial.RNumCycles %Sets events for Left Side
                    trial.RCycles(i,1) = trial.RFootStrikeEvents(i); %  FS starts cycle
                    if i<trial.RNumCycles
                        NextFS = trial.RFootStrikeEvents(i+1);
                        for k=1:length(trial.RGeneralEvents)
                            if  trial.RGeneralEvents(k) > trial.RCycles(i,1) && trial.RGeneralEvents(k)<NextFS
                                trial.RCycles(i,3) = trial.RGeneralEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.RGeneralEvents)
                            if trial.RGeneralEvents(k) > trial.RCycles(i,1)
                                trial.RCycles(i,3) = trial.RGeneralEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.RToeOffEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.RToeOffEvents(j) > trial.RCycles(i,1) && trial.RToeOffEvents(j) < trial.RCycles(i,3)
                            trial.RCycles(i,2) = trial.RToeOffEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,3,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,3)-trial.RCycles(i,1))*100;
                end
            end

            %%  Calculate #cycles for normalization Schemes that begin TO & end GE.
            if Normalization == 6
            %Cycles L
                if length(trial.LToeOffEvents) > length(trial.LGeneralEvents)
                   trial.LNumCycles = length(trial.LGeneralEvents);
                   trial.LCycles = zeros(1,3);
               else if length(trial.LToeOffEvents) < length(trial.LGeneralEvents)
                       trial.LNumCycles = length(trial.LToeOffEvents);
                       trial.LCycles = zeros(1,3);
                   else if length(trial.LToeOffEvents)== length(trial.LGeneralEvents) && trial.LToeOffEvents>0
                           trial.LNumCycles = length(trial.LToeOffEvents);
                           trial.LCycles = zeros(1,3);
                       else
                           trial.LNumCycles = 0;
                       end
                   end
               end   
            %Cycle R    
               if length(trial.RToeOffEvents) > length(trial.RGeneralEvents)
                   trial.RNumCycles = length(trial.RGeneralEvents);
                   trial.RCycles = zeros(1,3);
               else if length(trial.RToeOffEvents) < length(trial.RGeneralEvents)
                       trial.RNumCycles = length(trial.RToeOffEvents);
                       trial.RCycles = zeros(1,3);
                   else if length(trial.RToeOffEvents)== length(trial.RGeneralEvents) && trial.RToeOffEvents>0
                           trial.RNumCycles = length(trial.RToeOffEvents);
                           trial.RCycles = zeros(1,3);
                       else
                           trial.RNumCycles = 0;
                       end
                   end
               end
            % Create cycles L
                  for i=1:trial.LNumCycles %Sets events for Left Side
                    trial.LCycles(i,1) = trial.LToeOffEvents(i); %  FS starts cycle
                    if i<trial.LNumCycles
                        NextFS = trial.LToeOffEvents(i+1);
                        for k=1:length(trial.LGeneralEvents)
                            if  trial.LGeneralEvents(k) > trial.LCycles(i,1) && trial.LGeneralEvents(k)<NextFS
                                trial.LCycles(i,3) = trial.LGeneralEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.LGeneralEvents)
                            if trial.LGeneralEvents(k) > trial.LCycles(i,1)
                                trial.LCycles(i,3) = trial.LGeneralEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.LFootStrikeEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.LFootStrikeEvents(j) > trial.LCycles(i,1) && trial.LFootStrikeEvents(j) < trial.LCycles(i,3)
                            trial.LCycles(i,2) = trial.LFootStrikeEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,3,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,3)-trial.LCycles(i,1))*100;
                  end
            % Create cycles R
                  for i=1:trial.RNumCycles %Sets events for Left Side
                    trial.RCycles(i,1) = trial.RToeOffEvents(i); %  FS starts cycle
                    if i<trial.RNumCycles
                        NextFS = trial.RToeOffEvents(i+1);
                        for k=1:length(trial.RGeneralEvents)
                            if  trial.RGeneralEvents(k) > trial.RCycles(i,1) && trial.RGeneralEvents(k)<NextFS
                                trial.RCycles(i,3) = trial.RGeneralEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.RGeneralEvents)
                            if trial.RGeneralEvents(k) > trial.RCycles(i,1)
                                trial.RCycles(i,3) = trial.RGeneralEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.RFootStrikeEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.RFootStrikeEvents(j) > trial.RCycles(i,1) && trial.RFootStrikeEvents(j) < trial.RCycles(i,3)
                            trial.RCycles(i,2) = trial.RFootStrikeEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,3,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,3)-trial.RCycles(i,1))*100;
                   end
            end
            %% Calculatae #cycles for normalization schemes that being/end with GE
            if Normalization == 7
            % # Cycles L
                if trial.LGeneralEvents > 1
                    trial.LNumCycles = length(trial.LGeneralEvents)-1;
                    if length(trial.LToeOffEvents) < trial.LNumCycles;
                        trial.LNumCycles = length(trial.LToeOffEvents);
                        trial.LCycles = zeros(1,4);
                    else
                        trial.LCycles = zeros(1,4);
                    end
                else
                    trial.LNumCycles = 0;
                end
            % # Cycle R
                if trial.RGeneralEvents > 1
                    trial.RNumCycles = length(trial.RGeneralEvents)-1;
                    if length(trial.RToeOffEvents) < trial.RNumCycles;
                        trial.RNumCycles = length(trial.RToeOffEvents);
                        trial.RCycles = zeros(1,4);
                    else
                        trial.RCycles = zeros(1,4);
                    end
                else
                    trial.RNumCycles = 0;
                end    
            % Create Cycles L
                for i=1:trial.LNumCycles %Sets events for Left Side
                    trial.LCycles(i,1) = trial.LGeneralEvents(i); %  FS starts cycle
                    trial.LCycles(i,4) = trial.LGeneralEvents(i+1); % subsequent FS ends cycle
                    for j=1:length(trial.LToeOffEvents)
                        % if TO exists between two FS, then set to this cycle
                        if trial.LToeOffEvents(j) > trial.LCycles(i,1) && trial.LToeOffEvents(j) < trial.LCycles(i,4)
                            trial.LCycles(i,2) = trial.LToeOffEvents(j);
                        end
                    end
                    for j=1:length(trial.LFootStrikeEvents)
                        % if OFS exists between two FS, then set to this cycle
                        if trial.LFootStrikeEvents(j) > trial.LCycles(i,1) && trial.LFootStrikeEvents(j) < trial.LCycles(i,4)
                            trial.LCycles(i,3) = trial.LFootStrikeEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,4,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                    trial.CycleNorm(i,3,1)=(trial.LCycles(i,3)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                end
            % Create Cycles R
                for i=1:trial.RNumCycles %Sets events for Left Side
                    trial.RCycles(i,1) = trial.RGeneralEvents(i); %  FS starts cycle
                    trial.RCycles(i,4) = trial.RGeneralEvents(i+1); % subsequent FS ends cycle
                    for j=1:length(trial.RToeOffEvents)
                        % if TO exists between two FS, then set to this cycle
                        if trial.RToeOffEvents(j) > trial.RCycles(i,1) && trial.RToeOffEvents(j)< trial.RCycles(i,4)
                            trial.RCycles(i,2) = trial.RToeOffEvents(j);
                        end
                    end
                    for j=1:length(trial.RFootStrikeEvents)
                        % if OFS exists between two FS, then set to this cycle
                        if trial.RFootStrikeEvents(j) > trial.RCycles(i,1) && trial.RFootStrikeEvents(j) < trial.RCycles(i,4)
                            trial.RCycles(i,3) = trial.RFootStrikeEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,4,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,4)-trial.RCycles(i,1))*100;
                    trial.CycleNorm(i,3,2)=(trial.RCycles(i,3)-trial.RCycles(i,1))/(trial.RCycles(i,4)-trial.RCycles(i,1))*100;
                end
            end

            %%  Calculate #cycles for normalization Schemes that begin FS & end TO.
            if Normalization == 8
            % # Cycles L
               if length(trial.LFootStrikeEvents) > length(trial.LToeOffEvents)
                   trial.LNumCycles = length(trial.LToeOffEvents);
                   trial.LCycles = zeros(1,3);
               else if length(trial.LFootStrikeEvents) < length(trial.LToeOffEvents)
                       trial.LNumCycles = length(trial.LFootStrikeEvents);
                       trial.LCycles = zeros(1,3);
                   else if length(trial.LFootStrikeEvents)== length(trial.LToeOffEvents) && trial.LFootStrikeEvents>0
                           trial.LNumCycles = length(trial.LFootStrikeEvents);
                           trial.LCycles = zeros(1,3);
                       else
                           trial.LNumCycles = 0;
                       end
                   end
               end
            % # Cycles R 
               if length(trial.RFootStrikeEvents) > length(trial.RToeOffEvents)
                   trial.RNumCycles = length(trial.RToeOffEvents);
                   trial.RCycles = zeros(1,3);
               else if length(trial.RFootStrikeEvents) < length(trial.RToeOffEvents)
                       trial.RNumCycles = length(trial.RFootStrikeEvents);
                       trial.RCycles = zeros(1,3);
                   else if length(trial.RFootStrikeEvents)== length(trial.RToeOffEvents) && trial.RFootStrikeEvents>0
                           trial.RNumCycles = length(trial.RFootStrikeEvents);
                           trial.RCycles = zeros(1,3);
                       else
                           trial.RNumCycles = 0;
                       end
                   end
               end
            % Create Cycles L
                  for i=1:trial.LNumCycles %Sets events for Left Side
                    trial.LCycles(i,1) = trial.LFootStrikeEvents(i); %  FS starts cycle
                    if i<trial.LNumCycles
                        NextFS = trial.LFootStrikeEvents(i+1);
                        for k=1:length(trial.LToeOffEvents)
                            if  trial.LToeOffEvents(k) > trial.LCycles(i,1) && trial.LToeOffEvents(k)<NextFS
                                trial.LCycles(i,3) = trial.LToeOffEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.LToeOffEvents)
                            if trial.LToeOffEvents(k) > trial.LCycles(i,1)
                                trial.LCycles(i,3) = trial.LToeOffEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.LGeneralEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.LGeneralEvents(j) > trial.LCycles(i,1) && trial.LGeneralEvents(j) < trial.LCycles(i,3)
                            trial.LCycles(i,2) = trial.LGeneralEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,3,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,3)-trial.LCycles(i,1))*100;
            % Create Cycles R
                  for i=1:trial.RNumCycles %Sets events for Left Side
                    trial.RCycles(i,1) = trial.RFootStrikeEvents(i); %  FS starts cycle
                    if i<trial.RNumCycles
                        NextFS = trial.RFootStrikeEvents(i+1);
                        for k=1:length(trial.RToeOffEvents)
                            if  trial.RToeOffEvents(k) > trial.RCycles(i,1) && trial.RToeOffEvents(k)<NextFS
                                trial.RCycles(i,3) = trial.RToeOffEvents(k);
                            end
                        end 
                    else % last FS
                        for k=1:length(trial.RToeOffEvents)
                            if trial.RToeOffEvents(k) > trial.RCycles(i,1)
                                trial.RCycles(i,3) = trial.RToeOffEvents(k);
                            end
                        end
                    end
                    for j=1:length(trial.RGeneralEvents)
                        % if TO exists between start.end, then set to this cycle
                        if trial.RGeneralEvents(j) > trial.RCycles(i,1) && trial.RGeneralEvents(j) < trial.RCycles(i,3)
                            trial.RCycles(i,2) = trial.RGeneralEvents(j);
                        end
                    end
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,3,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,3)-trial.RCycles(i,1))*100;
                   end
                  end
            end
            %% Uses interface from start to determine the correct cycle type

            if Normalization == 1 || Normalization == 2
                
                % FS-XX-XX-XX-FS cycles, no duplicate events
                % Required: FS=1 & FS=5 & TO=4. Optional Events: OFO=2 OFC=3
                % # Create Cycles L
                Lcount = 1;
                for i=1:trial.LNumCycles %Sets events for Left Side

                    for j=1:length(trial.LToeOffEvents)
                        % if TO exists between two FS, then set to this cycle
                        if trial.LToeOffEvents(j) > trial.LFootStrikeEvents(i) && trial.LToeOffEvents(j) < trial.LFootStrikeEvents(i+1)
                           trial.LCycles(Lcount,1) = trial.LFootStrikeEvents(i); %  FS starts cycle
                           trial.LCycles(Lcount,5) = trial.LFootStrikeEvents(i+1); % subsequent FS ends cycle
                           trial.LCycles(Lcount,4) = trial.LToeOffEvents(j);
                           for j=1:length(trial.RToeOffEvents)
                                % if OFO exists between two FS, then set to this cycle
                                if trial.RToeOffEvents(j) > trial.LFootStrikeEvents(i) && trial.RToeOffEvents(j) < trial.LFootStrikeEvents(i+1)
                                    trial.LCycles(Lcount,2) = trial.RToeOffEvents(j);
                                end
                           end
                           for j=1:length(trial.RFootStrikeEvents)
                                % if OFS exists between two FS, then set to this cycle
                                if trial.RFootStrikeEvents(j) > trial.LFootStrikeEvents(i) && trial.RFootStrikeEvents(j) < trial.LFootStrikeEvents(i+1)
                                    trial.LCycles(Lcount,3) = trial.RFootStrikeEvents(j);
                                end
                           end
                           Lcount=Lcount+1;
                        end
                               
                    end

             
                end
                
                for i=1:size(trial.LCycles,1)        
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,5,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,5)-trial.LCycles(i,1))*100;
                    trial.CycleNorm(i,3,1)=(trial.LCycles(i,3)-trial.LCycles(i,1))/(trial.LCycles(i,5)-trial.LCycles(i,1))*100;
                    trial.CycleNorm(i,4,1)=(trial.LCycles(i,4)-trial.LCycles(i,1))/(trial.LCycles(i,5)-trial.LCycles(i,1))*100;
                    if trial.CycleNorm(i,2,1)<0 || (int16(trial.CycleNorm(i,2,1))==int16(trial.CycleNorm(i,4,1)))
                        % if event is zero or if it is equal to toe-off (L/R side
                        % events) set to zero
                        trial.CycleNorm(i,2,1)=0;
                    end
                    if trial.CycleNorm(i,3,1)<0 || (int16(trial.CycleNorm(i,3,1))==int16(trial.CycleNorm(i,5,1)))
                        trial.CycleNorm(i,3,1)=0;
                    end
                end
            % Create Cycles R
                Rcount =1;
                for i=1:trial.RNumCycles
                    for j=1:length(trial.RToeOffEvents)
                        if trial.RToeOffEvents(j) > trial.RFootStrikeEvents(i) && trial.RToeOffEvents(j) < trial.RFootStrikeEvents(i+1)
                            trial.RCycles(Rcount,1) = trial.RFootStrikeEvents(i);
                            trial.RCycles(Rcount,5) = trial.RFootStrikeEvents(i+1);
                            trial.RCycles(Rcount,4) = trial.RToeOffEvents(j);
                            for j=1:length(trial.LToeOffEvents)
                                if trial.LToeOffEvents(j) > trial.RFootStrikeEvents(i) && trial.LToeOffEvents(j) < trial.RFootStrikeEvents(i+1)
                                trial.RCycles(Rcount,2) = trial.LToeOffEvents(j);
                                end
                            end
                            for j=1:length(trial.LFootStrikeEvents)
                                if trial.LFootStrikeEvents(j) > trial.RFootStrikeEvents(i) && trial.LFootStrikeEvents(j) < trial.RFootStrikeEvents(i+1)
                                trial.RCycles(Rcount,3) = trial.LFootStrikeEvents(j);
                                end
                            end
                            Rcount=Rcount+1;
                        end
                    end
                end
                
                for i=1:size(trial.RCycles,1)   
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,5,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,5)-trial.RCycles(i,1))*100;
                    trial.CycleNorm(i,3,2)=(trial.RCycles(i,3)-trial.RCycles(i,1))/(trial.RCycles(i,5)-trial.RCycles(i,1))*100;
                    trial.CycleNorm(i,4,2)=(trial.RCycles(i,4)-trial.RCycles(i,1))/(trial.RCycles(i,5)-trial.RCycles(i,1))*100;
                    if trial.CycleNorm(i,2,2)<0 || (int16(trial.CycleNorm(i,2,2))== int16(trial.CycleNorm(i,4,2)))
                        trial.CycleNorm(i,2,2)=0;
                    end
                    if trial.CycleNorm(i,3,2)<0 || (int16(trial.CycleNorm(i,3,2))== int16(trial.CycleNorm(i,5,2)))
                        trial.CycleNorm(i,3,2)=0;
                    end

                end
            end



            %% Uses interface from start to determine the correct cycle type for
            % define events for normalization type3
            if Normalization == 3 
                % Create Cycles L
                for i=1:trial.LNumCycles %Sets events for Left Side
                    trial.LCycles(i,1) = trial.LFootStrikeEvents(i); %  FS starts cycle
                    trial.LCycles(i,4) = trial.LFootStrikeEvents(i+1); % subsequent FS ends cycle
                    for j=1:length(trial.LToeOffEvents)
                        % if TO exists between two FS, then set to this cycle
                        if trial.LCycles(i,2) == 0
                            if trial.LToeOffEvents(j) > trial.LCycles(i,1) && trial.LToeOffEvents(j) < trial.LCycles(i,4)
                                trial.LCycles(i,2) = trial.LToeOffEvents(j);
                            end
                        else
                            if trial.LToeOffEvents(j) > trial.LCycles(i,2) && trial.LToeOffEvents(j) < trial.LCycles(i,4)
                                trial.LCycles(i,3) = trial.LToeOffEvents(j);
                            end
                        end
                    end
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,4,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                    trial.CycleNorm(i,3,1)=(trial.LCycles(i,3)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                end
               % Creates Cycles R
                for i=1:trial.RNumCycles %Sets events for Left Side
                    trial.RCycles(i,1) = trial.RFootStrikeEvents(i); %  FS starts cycle
                    trial.RCycles(i,4) = trial.RFootStrikeEvents(i+1); % subsequent FS ends cycle
                    for j=1:length(trial.RToeOffEvents)
                        % if TO exists between two FS, then set to this cycle
                        if trial.RCycles(i,2) == 0
                            if trial.RToeOffEvents(j) > trial.RCycles(i,1) && trial.RToeOffEvents(j) < trial.RCycles(i,4)
                                trial.RCycles(i,2) = trial.RToeOffEvents(j);
                            end
                        else
                            if trial.RToeOffEvents(j) > trial.RCycles(i,2) && trial.RToeOffEvents(j) < trial.RCycles(i,4)
                                trial.RCycles(i,3) = trial.RToeOffEvents(j);
                            end
                        end
                    end
                    trial.CycleNorm(i,1,2)= 0;
                    trial.CycleNorm(i,4,2)=100;
                    trial.CycleNorm(i,2,2)=(trial.RCycles(i,2)-trial.RCycles(i,1))/(trial.RCycles(i,4)-trial.RCycles(i,1))*100;
                    trial.CycleNorm(i,3,2)=(trial.RCycles(i,3)-trial.RCycles(i,1))/(trial.RCycles(i,4)-trial.RCycles(i,1))*100;
                end
            end

            %% Define events for normalization type4 FS-GE-TO-FS

            if Normalization ==4
                % Create Cycles L
                Lcount=1;
                Rcount=1;
                
                for i=1:trial.LNumCycles %Sets events for Left Side
                  
                    for j=1:length(trial.LGeneralEvents)
                        % if GE exists between two FS, then set to this cycle
                        if trial.LGeneralEvents(j) > trial.LFootStrikeEvents(i) && trial.LGeneralEvents(j) < trial.LFootStrikeEvents(i+1)
                           for k=1:length(trial.LToeOffEvents)
                                % if TO exists between two FS, then set to this cycle
                                if trial.LToeOffEvents(k) > trial.LFootStrikeEvents(i) && trial.LToeOffEvents(k) < trial.LFootStrikeEvents(i+1)
                                    trial.LCycles(Lcount,3) = trial.LToeOffEvents(k);
                                    trial.LCycles(Lcount,2) = trial.LGeneralEvents(j);
                                    trial.LCycles(Lcount,1) = trial.LFootStrikeEvents(i); %  FS starts cycle
                                    trial.LCycles(Lcount,4) = trial.LFootStrikeEvents(i+1); % subsequent FS ends cycle
                                    Lcount=Lcount+1;
                                end
                            end
                            
                        end
                        
                    end
                end
                
                for i=1:size(trial.LCycles,1)
                    trial.CycleNorm(i,1,1)= 0;
                    trial.CycleNorm(i,4,1)=100;
                    trial.CycleNorm(i,2,1)=(trial.LCycles(i,2)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                    trial.CycleNorm(i,3,1)=(trial.LCycles(i,3)-trial.LCycles(i,1))/(trial.LCycles(i,4)-trial.LCycles(i,1))*100;
                end
               
            % Creates R Cycles
                 for i=1:trial.RNumCycles %Sets events for Left Side

                    for j=1:length(trial.RGeneralEvents)
                        % if OFS exists between two FS, then set to this cycle
                        if trial.RGeneralEvents(j) > trial.RFootStrikeEvents(i) && trial.RGeneralEvents(j) < trial.RFootStrikeEvents(i+1)
                            for k=1:length(trial.RToeOffEvents)
                                % if TO exists between two FS, then set to this cycle
                                if trial.RToeOffEvents(k) > trial.RFootStrikeEvents(i) && trial.RToeOffEvents(k) < trial.RFootStrikeEvents(i+1)
                                    trial.RCycles(Rcount,3) = trial.RToeOffEvents(k);
                                    trial.RCycles(Rcount,2) = trial.RGeneralEvents(j);
                                    trial.RCycles(Rcount,1) = trial.RFootStrikeEvents(i); %  FS starts cycle
                                    trial.RCycles(Rcount,4) = trial.RFootStrikeEvents(i+1); % subsequent FS ends cycle
                                    Rcount=Rcount+1;
                                end
                            end
                        end      
                    end
                 end
                 
                 for r=1:size(trial.RCycles,1)
                    trial.CycleNorm(r,1,2)= 0;
                    trial.CycleNorm(r,4,2)=100;
                    trial.CycleNorm(r,2,2)=(trial.RCycles(r,2)-trial.RCycles(r,1))/(trial.RCycles(r,4)-trial.RCycles(r,1))*100;
                    trial.CycleNorm(r,3,2)=(trial.RCycles(r,3)-trial.RCycles(r,1))/(trial.RCycles(r,4)-trial.RCycles(r,1))*100;
                 end
            end

            %% For cycles of TO-FS-TO

            if Normalization == 9
               if trial.LToeOffEvents >1 % there exist more than 1 TO
                   trial.LNumCycles = length(trial.LToeOffEvents)-1;
                   trial.LCycles = zeros(1,3);
               else
                   trial.LNumCycles =0;
               end
               
               if trial.RToeOffEvents >1 % there exist more than 1 TO
                   trial.RNumCycles = length(trial.RToeOffEvents)-1;
                   trial.RCycles = zeros(1,3);
               else
                   trial.RNumCycles =0;
               end
                
             Lcount = 1;
             for i=1:trial.LNumCycles
                 for j=1:length(trial.LFootStrikeEvents)
                     %if FS exists between 2 TOs
                     if trial.LFootStrikeEvents(j) > trial.LToeOffEvents(i) && trial.LFootStrikeEvents(j)<trial.LToeOffEvents(i+1)
                         trial.LCycles(Lcount,1)=trial.LToeOffEvents(i);
                         trial.LCycles(Lcount,3)=trial.LToeOffEvents(i+1);
                         trial.LCycles(Lcount,2)=trial.LFootStrikeEvents(j);
                         Lcount=Lcount+1;
                     end
                 end
             end
             
            for l=1:size(trial.LCycles,1)
                trial.CycleNorm(l,1,1)=0;
                trial.CycleNorm(l,3,1)=100;
                trial.CycleNorm(l,2,1)=(trial.LCycles(l,2)-trial.LCycles(l,1))/(trial.LCycles(l,3)-trial.LCycles(l,1))*100;
            end

             Rcount = 1;
             for i=1:trial.RNumCycles
                 for j=1:length(trial.RFootStrikeEvents)
                     %if FS exists between 2 TOs
                     if trial.RFootStrikeEvents(j) > trial.RToeOffEvents(i) && trial.RFootStrikeEvents(j)<trial.RToeOffEvents(i+1)
                         trial.RCycles(Rcount,1)=trial.RToeOffEvents(i);
                         trial.RCycles(Rcount,3)=trial.RToeOffEvents(i+1);
                         trial.RCycles(Rcount,2)=trial.RFootStrikeEvents(j);
                         Rcount=Rcount+1;
                     end
                 end
             end
             
            for r=1:size(trial.RCycles,1)
                trial.CycleNorm(r,1,2)=0;
                trial.CycleNorm(r,3,2)=100;
                trial.CycleNorm(r,2,2)=(trial.RCycles(r,2)-trial.RCycles(r,1))/(trial.RCycles(r,3)-trial.RCycles(r,1))*100;
            end

                     
            end
            %% For Normalization 10 - FS-FS

            if Normalization == 10
                if trial.LFootStrikeEvents >2 % There exists more than 1 FS
                    trial.LNumCycles = length(trial.LFootStrikeEvents)-1;
                    trial.LCycles=zeros(1,3);
                    Lcount =1;
                    for n=1:length(trial.LFootStrikeEvents)-1
                        trial.LCycles(Lcount,1)=trial.LFootStrikeEvents(n);
                        trial.LCycles(Lcount,3)=trial.LFootStrikeEvents(n+1);
                        Lcount=Lcount+1;
                    end
                else
                        trial.LNumCycles =0;
                end
                if trial.RFootStrikeEvents >2 % There exists more than 1 FS
                    trial.RNumCycles = length(trial.RFootStrikeEvents)-1;
                    trial.RCycles=zeros(1,3);
                    Rcount =1;
                    for p=1:length(trial.RFootStrikeEvents)-1
                        trial.RCycles(Rcount,1)=trial.RFootStrikeEvents(n);
                        trial.RCycles(Rcount,3)=trial.RFootStrikeEvents(n+1);
                        Rcount=Rcount+1;
                    end
                else
                        trial.RNumCycles =0;
                end

                for l=1:size(trial.LCycles,1)
                    trial.CycleNorm(l,1,1)=0;
                    trial.CycleNorm(l,3,1)=100;
                    trial.CycleNorm(l,2,1)=50;
                end
                
                for r=1:size(trial.RCycles,1)
                    trial.CycleNorm(r,1,2)=0;
                    trial.CycleNorm(r,3,2)=100;
                    trial.CycleNorm(r,2,2)=50;
                end
            end


            %% For Normalization 11 - FS-FS

            if Normalization == 11
                if trial.LFootStrikeEvents >1 % There exists more than 1 FS
                    if trial.LGeneralEvents >0
                        trial.LNumCycles = length(trial.LFootStrikeEvents);
                        trial.LCycles=zeros(1,3);
                        Lcount =1;
                        for n=1:length(trial.LFootStrikeEvents)
                            trial.LCycles(Lcount,1)=trial.LFootStrikeEvents(n);
                            trial.LCycles(Lcount,3)=trial.LGeneralEvents(n);
                            Lcount=Lcount+1;
                        end
                    end
                else
                        trial.LNumCycles =0;
                end
                if trial.RFootStrikeEvents >1 % There exists more than 1 FS
                    if trial.RGeneralEvents >0
                        trial.RNumCycles = length(trial.RFootStrikeEvents);
                        trial.RCycles=zeros(1,3);
                        Rcount =1;
                        for p=1:length(trial.RFootStrikeEvents)
                            trial.RCycles(Rcount,1)=trial.RFootStrikeEvents(n);
                            trial.RCycles(Rcount,3)=trial.RGeneralEvents(n);
                            Rcount=Rcount+1;
                        end
                    end
                else
                        trial.RNumCycles =0;
                end

                for l=1:size(trial.LCycles,1)
                    trial.CycleNorm(l,1,1)=0;
                    trial.CycleNorm(l,3,1)=100;
                    trial.CycleNorm(l,2,1)=50;
                end
                
                for r=1:size(trial.RCycles,1)
                    trial.CycleNorm(r,1,2)=0;
                    trial.CycleNorm(r,3,2)=100;
                    trial.CycleNorm(r,2,2)=50;
                end
            end
            fprintf('Time normalizing data...\n')

            trial.TimeNormalizeData(Variables, Startframe);
            %FileStruct = GetSubjectGDIData(trial.GaitCycle,Variables, FILECOUNT,FileStruct); % For gait cycle
            %FileStruct = GetSubjectGDIData_AKDDH_BMI(trial.GaitCycle,Variables, FILECOUNT,FileStruct); % For DDH BMI 
            %FileStruct = GetSubjectGDIData_FandAError(trial.GaitCycle,Variables, FILECOUNT,FileStruct); % For FANDA
            %%      
            %[LOutputVariables,ROutputVariables,OutputLabel] = Readvarblist(trial.DataArray,trial.LCycles,trial.RCycles,Startframe,trial.GaitCycle,trial.CycleNorm);

                
            %FileStruct(FILECOUNT,1).LOutputVar = LOutputVariables;
            %FileStruct(FILECOUNT,1).ROutputVar = ROutputVariables;
            %FileStruct(FILECOUNT,1).OutputLab = OutputLabel;
            %FileStruct(FILECOUNT,1).LeftHSGDIVector = trial.LNumCycles;
            %FileStruct(FILECOUNT,1).RightHSGDIVector = trial.RNumCycles;

            %   clearvars -except FileStringArray FileStruct Target1 Num_Variables Variables C3DCom NumberFiles thiswait pf ProblemFiles

        end

        function TimeNormalizeData(trial, Variables, Startframe)
 
            Num_Variables = numel(Variables);
            
            if size(trial.LCycles,1) >1 % more than one cycle noted
                trial.flag = 1;
                trial.reasonForFlag = 'More than one left cycle on c3d File. Fix Nexus file!';
                return
                %trial.Lcycleselect = FileStruct(FILECOUNT,1).Cycle;    % used the cycle from the filelist
                %LThisCycle = trial.Lcycleselect(end);
                %LThisCycle = str2double(LThisCycle);
            else
                LThisCycle=1;
            end
             
            if size(trial.RCycles,1) >1 % more than one cycle noted
                %trial.Rcycleselect = FileStruct(FILECOUNT,1).Cycle; % used the cycle from the filelist
                %RThisCycle = trial.Rcycleselect(end);
                %RThisCycle = str2double(RThisCycle);'
                trial.flag = 1;
                trial.reasonForFlag = 'More than one right cycle on c3d file. Fix Nexus File!';
                return
            else
                RThisCycle=1;
            end

            LStart = int16(trial.LCycles(LThisCycle,1))-Startframe; %start of Left gait cycle
            RStart = int16(trial.RCycles(RThisCycle,1))-Startframe; %Start of Right gait cycle
          
            if size(trial.LCycles,2)==4  % If cycle has 4 events
            
                REnd = int16(trial.RCycles(RThisCycle,4))-Startframe;
                LEnd = int16(trial.LCycles(LThisCycle,4))-Startframe; %end of Left gait cycle
          

            elseif size(trial.LCycles,2)==5 % If cycle has 5 events
                    
                REnd = int16(trial.RCycles(RThisCycle,5))-Startframe;
                LEnd = int16(trial.LCycles(LThisCycle,5))-Startframe; 
              
            elseif size(trial.LCycles,2) ==3 % If cycle has 3 events
            
                REnd = int16(trial.RCycles(RThisCycle,3))-Startframe;
                LEnd = int16(trial.LCycles(LThisCycle,3))-Startframe; 
            
            end

            for ii = 1:length(trial.sides)
               
                if strcmp(trial.sides(ii), 'L')
                    
                    try 
                        LDataCycle = trial.DataArray([LStart:LEnd],:,:,ii);
                    catch ME

                        trial.flag = 1;
                        switch ME.identifier
                            case 'MATLAB:badsubscript'
                                msg = sprintf(['Attempted to access %d:%d,:,:,1 of DataArray, but DataArray has a size of %dx%dx%dx%d'], LStart,LEnd, ...
                                                size(trial.DataArray,1),size(trial.DataArray,2),size(trial.DataArray,3),size(trial.DataArray,4));
                                trial.reasonForFlag = strcat(ME.message, msg);
                            otherwise
                                trial.reasonForFlag = ME.message;
                        end
                        return
                    end

                    sz = length(LDataCycle);
                    x=0:1:(sz-1);
                    x = (x/(sz-1))*100;

                    for h = 1:Num_Variables
                        checkNaN(LDataCycle)
                    end

                    for h= 1 :Num_Variables

                        if trial.flag == 1
                            return
                        end

                        for i=1:3
                            y=LDataCycle(:,i,h);
                            for xx=0:100
                                trial.GaitCycle(xx+1,i,h,ii)=spline(x,y,xx);
                            end
                        end

                    end
                    
                end
                
                if strcmp(trial.sides(ii), 'R')
                    
                    try
                        RDataCycle = trial.DataArray([RStart:REnd],:,:,ii);
                    catch ME
                        trial.flag = 1;
                        switch ME.identifier
                            case 'MATLAB:badsubscript'
                                msg = sprintf(['Attempted to access %d:%d,:,:,2 of DataArray, but DataArray has a size of %dx%dx%dx%d'], RStart, REnd, ...
                                                size(trial.DataArray,1),size(trial.DataArray,2),size(trial.DataArray,3),size(trial.DataArray,4));
                                trial.reasonForFlag = strcat(ME.message, msg);
                            otherwise
                                trial.reasonForFlag = ME.message;
                        end
                        return
                    end

                    sz = length(RDataCycle);
                    x=0:1:(sz-1);
                    x = (x/(sz-1))*100;

                    for h = 1:Num_Variables
                        checkNaN(RDataCycle)
                    end

                    for h = 1:Num_Variables
                        if trial.flag == 1
                            return
                        end
                        for i=1:3
                            y=RDataCycle(:,i,h);
                            for xx=0:100
                                trial.GaitCycle(xx+1,i,h,ii)=spline(x,y,xx);
                            end
                        end
                    end
                    
                end
                
            
            end
        
            function checkNaN(xDataCycle)
                if(sum(isnan(xDataCycle(:,1,h))) == sz || sum(isnan(xDataCycle(:,2,h))) == sz || sum(isnan(xDataCycle(:,3,h))) == sz)
                    msg = sprintf(['xDataCycle %s column consists only of NaNs. It is possible the model outputs are incomplete.'...
                                    'This side was requested by the file list, so the file is being skipped.'], Variables{h});
                    trial.flag = 1;
                    trial.reasonForFlag = msg;
                end
            end

        end

    end

end