% Retrieves feature of trajectory specified by inputs
function [result,timing] = variablePull(jointOrSegment, plane, event1, event2, feature, ...
                                        label, gettingTime, DataCycle, CycleNorm)

    center = figure('visible', 'off');
    movegui(center,'center')
    close

    % From main()
    global Variables;
    global PreviewResponse;
    global eventsMap;
    global planesMap;
    
    %% Checks inputs for mistakes
    if isempty(strmatch(jointOrSegment, Variables))
        error(['%s not found in variables list. Ensure that it is spelled correctly and that it ',...
               ' is included in the list of variables to pull from the dataset.'], jointOrSegment{:})
    elseif isempty(strmatch(event1,eventsMap))
        error(['%s not found in events map. Ensure that it is spelled correctly and that it is ',...
               'included in the list of events occuring in this cycle.'], event1{:})
    elseif isempty(strmatch(event2,eventsMap)) && strcmp(event2,'NA') == 0
        error(['%s not found in events map. Ensure that it is spelled correctly and that it is ',...
            'included in the list of events occuring in this cycle.'], event2{:})
    elseif isempty(strmatch(plane, planesMap))
        error(['%s not found in planes list. Ensure that it is spelled correctly and that it is ',...
            'capitalized.'], plane{:})
    else
        if strcmp(gettingTime, 'Yes')
            gettingTime = 1;
        else
            gettingTime = 0;
        end

        try
            warning('off','MATLAB:colon:nonIntegerIndex')
            switch feature{1}
                case 'Value'
                    result = DataCycle(int16(CycleNorm(min(strmatch(event1,eventsMap)))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables));
                    timing = 999;
                case 'Minimum'
                    if gettingTime
                        [result,timing] = min(DataCycle(CycleNorm(min(strmatch(event1,eventsMap))) + 1:CycleNorm(max(strmatch(event2,eventsMap))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables)));
                    else
                        result = min(DataCycle(CycleNorm(min(strmatch(event1,eventsMap))) + 1:CycleNorm(max(strmatch(event2,eventsMap))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables)));
                        timing = 999;
                    end
                case 'Maximum'
                    if gettingTime
                        [result,timing] = max(DataCycle(CycleNorm(min(strmatch(event1,eventsMap))) + 1:CycleNorm(max(strmatch(event2,eventsMap))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables)));
                    else
                        result = max(DataCycle(CycleNorm(min(strmatch(event1,eventsMap))) + 1:CycleNorm(max(strmatch(event2,eventsMap))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables)));
                        timing = 999;
                    end
                case 'Mean'
                    result = mean(DataCycle(CycleNorm(min(strmatch(event1,eventsMap))) + 1:CycleNorm(max(strmatch(event2,eventsMap))) + 1, ...
                                strmatch(plane, planesMap), ...
                                strmatch(jointOrSegment, Variables)));
                    timing = 999;
                otherwise
                    warning('Calculation not defined for %s! result = 9999, timing = 9999', feature{1})
                    result = 9999;
                    timing = 9999;
            end

        catch ME
            switch ME.identifier
            case 'MATLAB:badsubscript'
                msg = sprintf('DataCycle is %dx%dx%d, and you attempted to access %d:%d,%d,%d', size(DataCycle,1), ...
                        size(DataCycle,2), size(DataCycle,3), CycleNorm(min(strmatch(event1,eventsMap))) + 1, ...
                        CycleNorm(max(strmatch(event2,eventsMap))) + 1, strmatch(plane, planesMap), ...
                        strmatch(jointOrSegment, Variables));
                sprintf(msg)
                rethrow(ME)
            otherwise
                rethrow(ME)
            end
        end
    end
end