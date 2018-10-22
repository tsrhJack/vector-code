%% Creates Variable Pull results sheet
if variablePulling
    rowCounter = 2;
    for ii = 1:number_of_subjects
        currentSubject = Subjects(ii);
        for jj = 1:length(currentSubject.Sessions)
            currentSession = currentSubject.Sessions(jj);
            for kk = 1:length(currentSession.Trials)
                currentTrial = currentSession.Trials(kk);
                if currentTrial.flag
                    continue
                end
                number_of_sides = length(currentTrial.sides);
                for ll = 1:number_of_sides
                    currentSide = currentTrial.sides(ll);
                    if number_of_sides == 2;
                        header = generateHeader(currentSubject, currentSession, currentTrial, currentSide);
                    else
                        header = generateHeader(currentSubject, currentSession, currentTrial, 'B');
                    end
                    outputVariablePull(rowCounter, 1:length(header)) = header;
                    columnCounter = length(header) + 1;
                    for mm = 1:number_of_measures
                        outputVariablePull{rowCounter,columnCounter} = currentTrial.variablePullResults(1,mm,ll);
                        columnCounter = columnCounter + 1;
                        if currentTrial.variablePullTiming(mm) ~= 999
                            outputVariablePull{rowCounter,columnCounter} = currentTrial.variablePullTiming(1,mm,ll);
                            columnCounter = columnCounter + 1;
                        end
                    end
                    rowCounter = rowCounter + 1;     
                end
            end
        end
    end
end