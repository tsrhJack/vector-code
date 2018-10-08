%Performs a coupling analysis on two joint/segment angles for a gait cycle. 

function [mainFigure, figureName, bincounts] = OneToOneVectorCode(jointOrSegment1, plane1, norm1, ...
                                                            jointOrSegment2, plane2, norm2, event1, event2, currentSubject)

    center = figure('visible', 'off');
    movegui(center,'center')
    close

    % From main()
    global Variables;
    global ValidationResponse;
    global PreviewResponse;
  
    jointOrSegment1 = strcat(currentSubject.side,jointOrSegment1);     
    jointOrSegment2 = strcat(currentSubject.side,jointOrSegment2);
    planesMap = {'Sagittal', 'Coronal', 'Transverse'};
    bincounts = zeros(6,1);
    
    %% Checks inputs for mistakes
    if isempty(strmatch(jointOrSegment1, Variables))
        
        error(['%s not found in variables list. Ensure that it is spelled correctly and that it is included in the list of ' ...
                 'variables to pull from the dataset.'], jointOrSegment1{:})
        
    elseif isempty(strmatch(jointOrSegment2,Variables))
        
        error(['%s not found in variables list. Ensure that it is spelled correctly and that it is included in the list of ' ...
                'variables to pull from the dataset.'], jointOrSegment2{:})
        
    elseif isempty(strmatch(event1,currentSubject.eventsMap))

        error(['%s not found in events map. Ensure that it is spelled correctly and that it is included in the list of ' ...
            'events occuring in this cycle.'], event1{:})

    elseif isempty(strmatch(event2,currentSubject.eventsMap))

        error(['%s not found in events map. Ensure that it is spelled correctly and that it is included in the list of ' ...
            'events occuring in this cycle.'], event2{:})

    elseif isempty(strmatch(plane1, planesMap))

        error(['%s not found in planes list. Ensure that it is spelled correctly and that it is included in the list of ' ...
            'acceptable planes.'], plane1{:})

    elseif isempty(strmatch(plane2, planesMap))

        error(['%s not found in planes list. Ensure that it is spelled correctly and that it is included in the list of ' ...
            'acceptable planes.'], plane2{:})

    else

        try

            warning('off','MATLAB:colon:nonIntegerIndex')

            if strcmp(currentSubject.side, 'L')

                array1 = currentSubject.LeftGaitCycle(currentSubject.LCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1:currentSubject.LCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, ...
                            strmatch(plane1, planesMap), ...
                            strmatch(jointOrSegment1, Variables));
                array2 = currentSubject.LeftGaitCycle(currentSubject.LCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1:currentSubject.LCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, ...
                            strmatch(plane2, planesMap), ...
                            strmatch(jointOrSegment2, Variables));
                CycleNorm = currentSubject.LCycleNorm;

            else

                array1 = currentSubject.RightGaitCycle(currentSubject.RCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1:currentSubject.RCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, ...
                            strmatch(plane1, planesMap), ...
                            strmatch(jointOrSegment1, Variables));
                array2 = currentSubject.RightGaitCycle(currentSubject.RCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1:currentSubject.RCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, ...
                            strmatch(plane2, planesMap), ...
                            strmatch(jointOrSegment2, Variables));
                CycleNorm = currentSubject.RCycleNorm;

            end

            warning('on','MATLAB:colon:nonIntegerIndex')

        catch ME

            switch ME.identifier

            case 'MATLAB:badsubscript'

                if strcmp(currentSubject.side, 'L')

                    msg = sprintf('LeftGaitCycle array is %dx%dx%d, and you attempted to access %d:%d,%d,%d', size(currentSubject.LeftGaitCycle,1), ...
                            size(currentSubject.LeftGaitCycle,2), size(currentSubject.LeftGaitCycle,3), currentSubject.LCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1, ...
                            currentSubject.LCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, strmatch(plane1, planesMap), ...
                            strmatch(jointOrSegment1, Variables));
                    causeException = MException('MATLAB:err_static_workspace_violation',msg);
                    ME = addCause(ME,causeException);
                    rethrow(ME)

                else

                    msg = sprintf('RightGaitCycle array is %dx%dx%d, and you attempted to access %d:%d,%d,%d', size(currentSubject.RightGaitCycle,1), ...
                            size(currentSubject.RightGaitCycle,2), size(currentSubject.RightGaitCycle,3), currentSubject.RCycleNorm(min(strmatch(event1,currentSubject.eventsMap))) + 1, ...
                            currentSubject.RCycleNorm(max(strmatch(event2,currentSubject.eventsMap))) + 1, strmatch(plane1, planesMap), ...
                            strmatch(jointOrSegment1, Variables));
                    causeException = MException('MATLAB:err_static_workspace_violation',msg);
                    ME = addCause(ME,causeException);
                    rethrow(ME)

                end

            otherwise

                rethrow(ME)

            end
        
    end

    if strcmp(ValidationResponse,'Yes')

        disp('Validating Angle-Angle plot...')
        figure();
        plot(array1,array2);
        title('Angle-Angle Plot', 'FontWeight', 'Bold');
        xlabel(char(strcat(jointOrSegment1, {' '}, plane1)));
        ylabel(char(strcat(jointOrSegment2, {' '}, plane2)));

        isValid = MFquestdlg([0.35, 0.3],'Would you like to procede with vector coding?', ...
            'Plot Validation Prompt', ...
            'Yes','No', 'Yes');     % Options are yes and no, with yes being the default
            drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved

        if strcmp(isValid, 'No')

            close
            figureName = 'Invalid Angle-Angle Plot';
            mainFigure = 99;
            return

        end

        close

    end


    arrayLength = length(array1) - 1;
    % Givens are normalized to range of motion during the coupling analysis.
    OneToOnetheta = zeros(arrayLength,1);
    for k=1:(arrayLength)
        % Theta is a 1D matrix of values. The next line takes the inverse tangent
        % of the change in angle2 over the change in angle1
        OneToOnetheta(k) = 180 * atan2((array2(k+1)-array2(k)),(array1(k+1)-array1(k))) / pi;
        OneToOnenum = array2(k+1)-array2(k);
        OneToOnedenom = array1(k+1)-array1(k);
    end
    

    % atan2d is bound [-180, 180], so add 360 to angles less than 0
    OneToOnetheta = OneToOnetheta + (OneToOnetheta < 0)*360;

    % These are the values used for the bins. You can quickly adjust the size of each bin here
    binAMin1 = 0;        binAMax1 = 22.5;       binAMin2 = 180;        binAMax2 = 202.5;
    binBMin1 = 22.5;     binBMax1 = 67.5;       binBMin2 = 202.5;      binBMax2 = 247.5;
    binCMin1 = 67.5;     binCMax1 = 90;         binCMin2 = 247.5;      binCMax2 = 270;
    binDMin1 = 90;       binDMax1 = 122.5;      binDMin2 = 270;        binDMax2 = 292.5;
    binEMin1 = 122.5;    binEMax1 = 167.5;      binEMin2 = 292.5;      binEMax2 = 337.5;
    %binFMin1 = 167.5;   binFMax1 = 180;        binFMin2 = 337.5;      binFMax2 = 360;      (Handled by else case)

    % Instantiates arrays to preallocate memory (runs more efficiently)
    % These arrays keep track of what bin each couple fell into at each
    % moment in time (but keep in mind if time normalization has been run
    % in the getEvents() function
    OneToOnephase = zeros(1,arrayLength);
    OneToOneproximalDominantInPhase = zeros(1,arrayLength);
    OneToOneinPhase = zeros(1,arrayLength);
    OneToOnedistalDominantInPhase = zeros(1,arrayLength);
    OneToOnedistalDominantAntiPhase = zeros(1,arrayLength);
    OneToOneantiPhase = zeros(1,arrayLength);
    OneToOneproximalDominantAntiPhase = zeros(1,arrayLength);


    % Assigns the coupling angle to a bin at each point in time
    for k=1:(arrayLength)

            % Proximal-Dominant In-Phase
            if (OneToOnetheta(k) > binAMin1 && OneToOnetheta(k) < binAMax1 || OneToOnetheta(k) > binAMin2 && OneToOnetheta(k) < binAMax2)

                OneToOnephase(k) = 1;
                OneToOneproximalDominantInPhase(k) = 1;

            % In-phase
            elseif (OneToOnetheta(k) > binBMin1 && OneToOnetheta(k) < binBMax1 || OneToOnetheta(k) > binBMin2 && OneToOnetheta(k) < binBMax2)

                OneToOnephase(k) = 2;
                OneToOneinPhase(k) = 1;


            % Distal-Dominant In-Phase
            elseif (OneToOnetheta(k) > binCMin1 && OneToOnetheta(k) < binCMax1 || OneToOnetheta(k) > binCMin2 && OneToOnetheta(k) < binCMax2)

                OneToOnephase(k) = 3;
                OneToOnedistalDominantInPhase(k) = 1;

            % Distal-Dominant Anti-Phase
            elseif (OneToOnetheta(k) > binDMin1 && OneToOnetheta(k) < binDMax1 || OneToOnetheta(k) > binDMin2 && OneToOnetheta(k) < binDMax2)

                OneToOnephase(k) = 4;
                OneToOnedistalDominantAntiPhase(k) = 1;

            % Anti-Phase
            elseif (OneToOnetheta(k) > binEMin1 && OneToOnetheta(k) < binEMax1 || OneToOnetheta(k) > binEMin2 && OneToOnetheta(k) < binEMax2)

                OneToOnephase(k) = 5;
                OneToOneantiPhase(k) = 1;

            % Proximal-Dominant Anti-Phase
            else % the case that theta(k) > 167.5 && theta(k) < 180 || theta(k) > 337.5 && theta(k) < 360

                OneToOnephase(k) = 6;
                OneToOneproximalDominantAntiPhase(k) = 1;

            end

    end

    array1 = array1 / norm1;
    array2 = array2 / norm2;

    [R,p_value] = corrcoef(array1,array2); % Determines the correlation coeff 
    % the correlation p-value of two input arrays
    R_var = R(1,2); %takes the x-y correlation
    p_var = p_value(1,2); %takes the x-y p-value


    theta = zeros(arrayLength,1);
    for k=1:(arrayLength)

        %Theta is a 1D matrix of values. The next line takes the inverse tangent
        %of the change in angle2 over the change in angle1
        theta(k) = 180 * atan2((array2(k+1)-array2(k)),(array1(k+1)-array1(k))) / pi;

        num = array2(k+1)-array2(k);
        denom = array1(k+1)-array1(k);

    end
    

    % atan2d is bound [-180, 180], so add 360 to angles less than 0
    theta = theta + (theta < 0)*360;
    t = 0:(arrayLength);    %  Array used for plotting

    % Instantiates arrays to preallocate memory (runs more efficiently)
    % These arrays keep track of what bin each couple fell into at each
    % moment in time (but keep in mind if time normalization has been run
    % in the getEvents() function
    phase = zeros(1,arrayLength);
    proximalDominantInPhase = zeros(1,arrayLength);
    inPhase = zeros(1,arrayLength);
    distalDominantInPhase = zeros(1,arrayLength);
    distalDominantAntiPhase = zeros(1,arrayLength);
    antiPhase = zeros(1,arrayLength);
    proximalDominantAntiPhase = zeros(1,arrayLength);


    % Assigns the coupling angle to a bin at each point in time
    for k=1:(arrayLength)

            % Proximal-Dominant In-Phase
            if (theta(k) > binAMin1 && theta(k) < binAMax1 || theta(k) > binAMin2 && theta(k) < binAMax2)

                phase(k) = 1;
                proximalDominantInPhase(k) = 1;

            % In-phase
            elseif (theta(k) > binBMin1 && theta(k) < binBMax1 || theta(k) > binBMin2 && theta(k) < binBMax2)

                phase(k) = 2;
                inPhase(k) = 1;


            % Distal-Dominant In-Phase
            elseif (theta(k) > binCMin1 && theta(k) < binCMax1 || theta(k) > binCMin2 && theta(k) < binCMax2)

                phase(k) = 3;
                distalDominantInPhase(k) = 1;

            % Distal-Dominant Anti-Phase
            elseif (theta(k) > binDMin1 && theta(k) < binDMax1 || theta(k) > binDMin2 && theta(k) < binDMax2)

                phase(k) = 4;
                distalDominantAntiPhase(k) = 1;

            % Anti-Phase
            elseif (theta(k) > binEMin1 && theta(k) < binEMax1 || theta(k) > binEMin2 && theta(k) < binEMax2)

                phase(k) = 5;
                antiPhase(k) = 1;

            % Proximal-Dominant Anti-Phase
            else % the case that theta(k) > 167.5 && theta(k) < 180 || theta(k) > 337.5 && theta(k) < 360

                phase(k) = 6;
                proximalDominantAntiPhase(k) = 1;

            end

    end

    %% Colors for each section
    proximalDominantInPhaseColor = 1/255*[208,255,0];
    inPhaseColor = 1/255*[0,255,0];
    distalDominantInPhaseColor = 1/255*[0,150,17];
    distalDominantAntiPhaseColor = 1/255*[150,0,0];
    antiPhaseColor = 1/255*[255,0,0];
    proximalDominantAntiPhaseColor = 1/255*[191,101,0];
    colors = {proximalDominantInPhaseColor; inPhaseColor; distalDominantInPhaseColor; distalDominantAntiPhaseColor; ...
                antiPhaseColor; proximalDominantAntiPhaseColor};

    array1 = array1*norm1;
    array2 = array2*norm2;
    yMin = min(min(array1,array2));

    
    if strcmp(PreviewResponse, 'No')

        mainF = figure('units','normalized','outerposition',[0 0 1 1], 'visible', 'off');
    
    else
        
        mainF = figure('units','normalized','outerposition',[0 0 1 1]);
    
    end
    currentTitle = strcat(jointOrSegment1, {' vs '}, jointOrSegment2);
    subplot(2,4,[1,2,3,4])
    plot(t, array1, 'DisplayName', jointOrSegment1{:}); hold on;
    plot(t, array2, 'DisplayName', jointOrSegment2{:})
    title(currentTitle, 'FontWeight', 'Bold');
    xlabel('% Gait Cycle');
    ylabel('Angle (Degrees)');
    xlim([1 arrayLength]);
    y_limit_bottom = min(min(array1,array2)) - 10;
    y_limit_top = max(max(array1,array2))*1.25;
    ylim([y_limit_bottom y_limit_top]);
    legend('show')

    %% Creates the color bar under the x-axis
    changeLocations = zeros(100,1);
    for i = 2:arrayLength()

        if phase(i) ~= phase(i-1)

            changeLocations(i-1) = i-1;

        end

    end
    changeLocations(end) = length(phase);
    changeLocations = changeLocations(changeLocations ~= 0);

    for ii = 1: length(changeLocations)

        if ii == 1

            X = [0 0 changeLocations(ii) changeLocations(ii)];
            Y = [yMin-1 y_limit_bottom y_limit_bottom yMin-1];

        elseif changeLocations(ii) == 0
            
            X = [arrayLength arrayLength changeLocations(ii-1) changeLocations(ii-1)];
            Y = [yMin-1 y_limit_bottom y_limit_bottom yMin-1];

        else
            
            X = [changeLocations(ii) changeLocations(ii) changeLocations(ii-1) changeLocations(ii-1)];
            Y = [yMin-1 y_limit_bottom y_limit_bottom yMin-1];

        end

        switch phase(changeLocations(ii))
            case 1   
                patch(X,Y,colors{1})
            case 2
                patch(X,Y,colors{2})
            case 3
                patch(X,Y,colors{3})
            case 4
                patch(X,Y,colors{4})
            case 5
                patch(X,Y,colors{5})
            case 6
                patch(X,Y,colors{6})
            otherwise
                error('phase vector at %d is %d and should be in the range 1-6!', ii, phase(ii))
        end
    end
    hold off;

    %% Adds angle data to plot
    %calculates the differences between adjacent elements of X (approximates derivative)
    thetaDeriv = diff(theta);

    % Angle-Angle Plot
    subplot(2,4,[5,6])
    plot(array1,array2);
    title('Angle-Angle Plot', 'FontWeight', 'Bold');
    xlabel(char(strcat(jointOrSegment1, {' '}, plane1)));
    ylabel(char(strcat(jointOrSegment2, {' '}, plane2)));

    %% Stacked bar Plot
    subplot(2,4,[7,8])
    % Bin counts over Gait Cycle
    GCbincounts = zeros(1,6);
    GCbincounts(1) = sum(proximalDominantInPhase);
    GCbincounts(2) = sum(inPhase);
    GCbincounts(3) = sum(distalDominantInPhase);
    GCbincounts(4) = sum(distalDominantAntiPhase);
    GCbincounts(5) = sum(antiPhase);
    GCbincounts(6) = sum(proximalDominantAntiPhase);

    a = fix(CycleNorm(min(strmatch('Foot Strike', currentSubject.eventsMap))) + 1);
    b = fix(CycleNorm(strmatch('Opposite Foot Off', currentSubject.eventsMap)) + 1);
    c = fix(CycleNorm(strmatch('Opposite Foot Strike', currentSubject.eventsMap)) + 1);
    d = fix(CycleNorm(max(strmatch('Foot Off', currentSubject.eventsMap))) + 1);

    ESbincounts = zeros(1,6);
    MSbincounts = zeros(1,6);
    LSbincounts = zeros(1,6);

    % Bin counts over Loading Response
    LRbincounts(1) = sum(proximalDominantInPhase(a:b)) / (b-a+1) * 100;
    LRbincounts(2) = sum(inPhase(a:b)) / (b-a+1) * 100;
    LRbincounts(3) = sum(distalDominantInPhase(a:b)) / (b-a+1) * 100;
    LRbincounts(4) = sum(distalDominantAntiPhase(a:b)) / (b-a+1) * 100;
    LRbincounts(5) = sum(antiPhase(a:b)) / (b-a+1) * 100;
    LRbincounts(6) = sum(proximalDominantAntiPhase(a:b)) / (b-a+1) * 100;

    % Bin counts over Mid-Stance and Terminal Stance
    MSbincounts(1) = sum(proximalDominantInPhase(b:c)) / (c-b+1) * 100;
    MSbincounts(2) = sum(inPhase(b:c)) / (c-b+1) * 100;
    MSbincounts(3) = sum(distalDominantInPhase(b:c)) / (c-b+1) * 100;
    MSbincounts(4) = sum(distalDominantAntiPhase(b:c)) / (c-b+1) * 100;
    MSbincounts(5) = sum(antiPhase(b:c)) / (c-b+1) * 100;
    MSbincounts(6) = sum(proximalDominantAntiPhase(b:c)) / (c-b+1) * 100;

    % Bin counts over Pre-Swing
    PSbincounts(1) = sum(proximalDominantInPhase(c:d)) / (d-c+1) * 100;
    PSbincounts(2) = sum(inPhase(c:d)) / (d-c+1) * 100;
    PSbincounts(3) = sum(distalDominantInPhase(c:d)) / (d-c+1) * 100;
    PSbincounts(4) = sum(distalDominantAntiPhase(c:d)) / (d-c+1) * 100;
    PSbincounts(5) = sum(antiPhase(c:d)) / (d-c+1) * 100;
    PSbincounts(6) = sum(proximalDominantAntiPhase(c:d)) / (d-c+1) * 100;

    %% One To One (No account for)
    OneToOneGCbincounts = zeros(1,6);
    OneToOneGCbincounts(1) = sum(OneToOneproximalDominantInPhase);
    OneToOneGCbincounts(2) = sum(OneToOneinPhase);
    OneToOneGCbincounts(3) = sum(OneToOnedistalDominantInPhase);
    OneToOneGCbincounts(4) = sum(OneToOnedistalDominantAntiPhase);
    OneToOneGCbincounts(5) = sum(OneToOneantiPhase);
    OneToOneGCbincounts(6) = sum(OneToOneproximalDominantAntiPhase);

    OneToOneESbincounts = zeros(1,6);
    OneToOneMSbincounts = zeros(1,6);
    OneToOneLSbincounts = zeros(1,6);

    % Bin counts over Loading Response
    OneToOneLRbincounts(1) = sum(OneToOneproximalDominantInPhase(a:b)) / (b-a+1) * 100;
    OneToOneLRbincounts(2) = sum(OneToOneinPhase(a:b)) / (b-a+1) * 100;
    OneToOneLRbincounts(3) = sum(OneToOnedistalDominantInPhase(a:b)) / (b-a+1) * 100;
    OneToOneLRbincounts(4) = sum(OneToOnedistalDominantAntiPhase(a:b)) / (b-a+1) * 100;
    OneToOneLRbincounts(5) = sum(OneToOneantiPhase(a:b)) / (b-a+1) * 100;
    OneToOneLRbincounts(6) = sum(OneToOneproximalDominantAntiPhase(a:b)) / (b-a+1) * 100;

    % Bin counts over Mid-Stance and Terminal Stance
    OneToOneMSbincounts(1) = sum(OneToOneproximalDominantInPhase(b:c)) / (c-b+1) * 100;
    OneToOneMSbincounts(2) = sum(OneToOneinPhase(b:c)) / (c-b+1) * 100;
    OneToOneMSbincounts(3) = sum(OneToOnedistalDominantInPhase(b:c)) / (c-b+1) * 100;
    OneToOneMSbincounts(4) = sum(OneToOnedistalDominantAntiPhase(b:c)) / (c-b+1) * 100;
    OneToOneMSbincounts(5) = sum(OneToOneantiPhase(b:c)) / (c-b+1) * 100;
    OneToOneMSbincounts(6) = sum(OneToOneproximalDominantAntiPhase(b:c)) / (c-b+1) * 100;

    % Bin counts over Pre-Swing
    OneToOnePSbincounts(1) = sum(OneToOneproximalDominantInPhase(c:d)) / (d-c+1) * 100;
    OneToOnePSbincounts(2) = sum(OneToOneinPhase(c:d)) / (d-c+1) * 100;
    OneToOnePSbincounts(3) = sum(OneToOnedistalDominantInPhase(c:d)) / (d-c+1) * 100;
    OneToOnePSbincounts(4) = sum(OneToOnedistalDominantAntiPhase(c:d)) / (d-c+1) * 100;
    OneToOnePSbincounts(5) = sum(OneToOneantiPhase(c:d)) / (d-c+1) * 100;
    OneToOnePSbincounts(6) = sum(OneToOneproximalDominantAntiPhase(c:d)) / (d-c+1) * 100;

    bincounts = [GCbincounts(1), GCbincounts(2), GCbincounts(3), GCbincounts(4), GCbincounts(5), GCbincounts(6); ...
                LRbincounts(1), LRbincounts(2), LRbincounts(3), LRbincounts(4), LRbincounts(5), LRbincounts(6); ...
                MSbincounts(1), MSbincounts(2), MSbincounts(3), MSbincounts(4), MSbincounts(5), MSbincounts(6); ...
                PSbincounts(1), PSbincounts(2), PSbincounts(3), PSbincounts(4), PSbincounts(5), PSbincounts(6); ...
                OneToOneGCbincounts(1), OneToOneGCbincounts(2), OneToOneGCbincounts(3), OneToOneGCbincounts(4), ...
                OneToOneGCbincounts(5), OneToOneGCbincounts(6); OneToOneLRbincounts(1), OneToOneLRbincounts(2), ...
                OneToOneLRbincounts(3), OneToOneLRbincounts(4), OneToOneLRbincounts(5), OneToOneLRbincounts(6); ...
                OneToOneMSbincounts(1), OneToOneMSbincounts(2), OneToOneMSbincounts(3), OneToOneMSbincounts(4), ...
                OneToOneMSbincounts(5), OneToOneMSbincounts(6); OneToOnePSbincounts(1), OneToOnePSbincounts(2), ...
                OneToOnePSbincounts(3), OneToOnePSbincounts(4), OneToOnePSbincounts(5), OneToOnePSbincounts(6)];

    % This just groups the time period next to the 1:1 of the same time period
    bincountsBar = [GCbincounts(1), GCbincounts(2), GCbincounts(3), GCbincounts(4), GCbincounts(5), GCbincounts(6); ...
                OneToOneGCbincounts(1), OneToOneGCbincounts(2), OneToOneGCbincounts(3), OneToOneGCbincounts(4), ...
                OneToOneGCbincounts(5), OneToOneGCbincounts(6); LRbincounts(1), LRbincounts(2), LRbincounts(3), ...
                LRbincounts(4), LRbincounts(5), LRbincounts(6); OneToOneLRbincounts(1), OneToOneLRbincounts(2), ...
                OneToOneLRbincounts(3), OneToOneLRbincounts(4), OneToOneLRbincounts(5), OneToOneLRbincounts(6); ...
                MSbincounts(1), MSbincounts(2), MSbincounts(3), MSbincounts(4), MSbincounts(5), MSbincounts(6); ...
                OneToOneMSbincounts(1), OneToOneMSbincounts(2), OneToOneMSbincounts(3), OneToOneMSbincounts(4), ...
                OneToOneMSbincounts(5), OneToOneMSbincounts(6); PSbincounts(1), PSbincounts(2), PSbincounts(3), ...
                PSbincounts(4), PSbincounts(5), PSbincounts(6); OneToOnePSbincounts(1), OneToOnePSbincounts(2), ...
                OneToOnePSbincounts(3), OneToOnePSbincounts(4), OneToOnePSbincounts(5), OneToOnePSbincounts(6)];
    
    barHandle = bar(bincountsBar, 'stacked');
    ylim([0 100])
    title('Percent Of Time In Each Bin', 'FontWeight', 'Bold')
    ylabel('Percent')
    xt = get(gca, 'XTick');
    set(gca,'XTick', xt, 'XTickLabel', {'GC', '1:1 GC', 'LR', '1:1 LR', 'SLS', '1:1 SLS', 'PS', '1:1 PS'})
    yd = get(barHandle, 'YData');
    barBase = zeros(4,7);
    
    for k1 = 1:size(bincountsBar,1)

        barBase(k1,:) = cumsum([0 bincountsBar(k1,:)]);
        for k2 = 1:size(bincountsBar,2)

            if ~(bincountsBar(k1,k2) == 0)

                percentLabelPositionX = xt(k1);
                percentLabelPositionY = bincountsBar(k1,k2) / 2 + barBase(k1,k2);
                txt = strcat(num2str(bincountsBar(k1,k2),3),'%');
                text(xt(k1),percentLabelPositionY,txt, 'HorizontalAlignment','center')

            end

        end

    end
    

    for k=1:6
        
        set(barHandle(k),'FaceColor',colors{k})
        
    end

    %% Legend
    a = 'Proximal-Dominant In-Phase';
    b = 'In-phase';
    c = 'Distal-Dominant In-Phase';
    d = 'Distal-Dominant Anti-Phase';
    e = 'Anti-Phase';
    f = 'Proximal-Dominant Anti-Phase';
    a = strcat(a, '(', num2str(GCbincounts(1),3), '%)');
    b = strcat(b, '(', num2str(GCbincounts(2),3), '%)');
    c = strcat(c, '(', num2str(GCbincounts(3),3), '%)');
    d = strcat(d, '(', num2str(GCbincounts(4),3), '%)');
    e = strcat(e, '(', num2str(GCbincounts(5),3), '%)');
    f = strcat(f, '(', num2str(GCbincounts(6),3), '%)');
    %legend(barHandle(:), {a, b, c, d, e, f}, 'Location', 'EastOutside')

    mainFigure = ancestor(mainF, 'figure');
    figureName = char(strcat(jointOrSegment1, {' '}, plane1, {' vs '}, jointOrSegment2, {' '}, plane2));

end