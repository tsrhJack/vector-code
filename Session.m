classdef Session < handle

    properties

        name
        Folder
        Trials = Trial.empty
        sides = []
        byContextCounter = [0,0]; % Keeps track of how many trials contain each side for averaging the data by context
        acrossSidesCounter = 0; % Keeps track of the overall number of cycles being averaged together across sides
        aveCycleNorm

        aveDataArray
        aveGaitCycle

        flag = 0;
        reasonForFlag

        averageVariablePullResults
        averageVariablePullTiming
        averageVectorCodeResults

    end

    methods

        function validateProperties(session, testName)
            if isempty(session.Folder)
                msg = 'Folder not given for Session';
                warning(msg)
            end
            if strcmp(session.name,testName) == 0
                currentSubject.flag = 1;
                currentSubject.reasonForFlag = sprintf(['subject session in file path does not match given ', ...
                                                        'subject session in file list. (Session in path: %s. ',...
                                                        'Session given: %s.)'],session.name, testName);
            end
        end

    end


end