% Created by Kirsten Tulchin-Francis in 2017
% Modified by Jack Beitter in August 2018
% 
% Required files: MFquestdlg     openc3d.m    closec3d.m      c3dserver.m     createc3d.m    
%                 get3dtarget.m  savec3d.m    nframes.m      vectorCode.m
%           
%       
% This program reads a list of c3d files and returns a variable pull and/or vector code analysis
% based on the structure of a variable list excel file. See the example file list and variable list
% or the constants in this file for formatting your excel files.
% 
%
% Will be used to compare to the variable pull code

clear
clc
warning('off', 'MATLAB:nargchk:deprecated')
diary
if verLessThan('matlab', '9.0')
    msg = ['Warning: This program was written on Matlab 9.0 (R2016a), and you are running an ',...
           'older version of Matlab. Some functions may not work. If you would like to run the ',...
           'code anyway, press ''continue''; otherwise, press ''stop''.'];
    VersionWarningResponse = questdlg(msg, ...
                'Matlab Version Warning', ...
                'Continue','Stop', 'Stop');
    drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
    if strcmp(VersionWarningResponse, 'Stop')
        return
    end
end

[fileListName, fileListPath] = uigetfile('*.xlsx', 'Select a file list');
if fileListName == 0
    disp('No file selected.')
    return
end


multiWaitbar('Processing', 0);
disp('Loading file list...');
fileList = strcat(fileListPath,fileListName);
[fileListStatus,fileListSheets] = xlsfinfo(fileList);
if ~any(strcmp(fileListSheets,'FileList'))
    error(['The file list must have a sheet called ''FileList''. Please rename the sheet ',...
           'you would like to use. See exampleFileList.'])
end
[numFile, txtFile] = xlsread(fileList, 'FileList');
number_of_files = size(txtFile,1);
if (isempty(txtFile))
    error('The file list is empty.')
end

% ************************************************************************************************
%  Need to attempt to follow all of the given file paths and add the ones that are broken to the 
%  file list. Then I can pre-allocate the memory for the number of subjects in the list!
% if exist(currentFile, 'file') == 0
%     if exist(currentSubject.Folder, 'file') == 0
%         currentSubject.flag = 1;
%         currentSubject.reasonForFlag = sprintf(['The path %s could not be followed. 
%            Ensure that the folder is in the right directory and ',  ...
%            'that the path is correct.'], currentSubject.Folder);
%     else
%         currentSubject.flag = 1;
%         currentSubject.reasonForFlag = sprintf(['The file %s was not found in the path',...
%            given (%s)'], currentSubject.fileName, currentSubject.Folder);
%     end
% end
% ************************************************************************************************

[variableListFile, variableListPath] = uigetfile('*.xlsx', 'Select a variable list', fileListPath);
if variableListFile == 0
    disp('No variable list selected.')
    return
end
variableList = strcat(variableListPath,variableListFile);

global Normalization;
str = {'1. FS-OFO-OFC-TO-FS  ex. Typical Gait Cycle (bilateral steps',...
'2. FS-TO-FS  ex .Single-side Gait Cycle, Deep Squat, Sit to Stand',...
'3. FS-TO-TO-FS  ex. Squat Hold','4. FS-GE-TO-FS ex. Step Down',...
'5. FS-TO-GE ex. Single Limb Squat, Toe Raises','6. TO-FS-GE ex. Drop Landing'...
'7. GE-TO-FS-GE ex. Single Leg Leap (FAI)','8. FS-GE-TO ex. Hopping (GCF)',...
'9. TO-FS-TO ex. Full Hip ROTs-Int (FAI)','10. FS-FS ex. Static','11. FS-GE ex. DropLanding Stance'};

[s]=listdlg('ListString',str,'SelectionMode','single','OKString','Select',...
    'ListSize',[450 160],'PromptString','Select the Normalization Scheme for your files.',...
    'Name','Choose Your Event Scheme');
Normalization=s;

if Normalization == 1
    msg = ['Do you want to check for newer versions of the files? (Example: fileName.c3d ', ...
            ' will also look for fileName_fa.c3d)'];
    appendPrompt = questdlg(msg, 'Append To File Name', ...
                'No', '_fa', 'Custom', 'No');
    drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
end

global Variables;
global processingSteps;
global PreviewResponse;
global eventsMap;
global planesMap;
global boths;
planesMap = {'Sagittal', 'Coronal', 'Transverse'};
boths = 0; % Number of files that both sides were run
PreviewResponse = 'No';
variablePullAverageResponse = 'No';
vectorCodeAverageResponse = 'No';

%% Instantiate variables used in program and set some default values
% Based on the structure of fileList.xlsx. Update if you change the fileList structure
inputFilePathColumn = 1;
% input of the number column shouldn't be counted, because when you use xlsread, it stores
% numbers in a separate variable. So even though the number input is the second column
% of the excel sheet, it is the first column in the numFile becuase it is the first numerical input
inputLastNameColumn = 3;
inputFirstNameColumn = 4;
inputTrialType = 5;
inputSessionColumn = 6;
inputSideColumn = 7;
inputCycleInfoColumn = 8;
inputAffectedSideColumn = 9; 

% Defines the structure of the headers of the excel results sheets.
headerNames = {'File', 'ID', 'Number', 'Last Name', 'First Name', 'Trial Type', 'Session', ...
               'Side', 'Cycle Info', 'Affected Side'};
headerFileIndex = 1;
headerIDIndex = 2;
headerNumberIndex = 3;
headerLastNameIndex = 4;
headerFirstNameIndex = 5;
headerTrialTypeIndex = 6;
headerSessionIndex = 7;
headerSideIndex = 8;
headerCycleInfoIndex = 9;
headerAffectedSideIndex = 10;
header = cell(1,10);

% Defines the structure of the variable pull and creates variables which reference each column 
% in case you change the order
VariablePullOutputColumnNames = headerNames;
VariablePullOutputNumberColumn = strmatch('Number', VariablePullOutputColumnNames);
VariablePullOutputSessionColumn = strmatch('Session', VariablePullOutputColumnNames);
VariablePullOutputSideColumn = strmatch('Side', VariablePullOutputColumnNames);

% Other
Subjects = Subject.empty;
currentSubject = Subject;
figureName = 'error';
VariablePullOutputRowCounter = 2; % Leaves room for the header
rowCounter = 1;
columnCounter = 0;
vectorCodeOutputRowCounter = 2; % Leaves room for the header
planesMap = {'Sagittal', 'Coronal', 'Transverse'}; % The order that our data is in
vectorCoding = false;
variablePulling = false;
processingSteps = 3;
global problemFiles;
problemFiles = cell(0,2);
Variables = {};
uniqueVariables = {};

% Constants used to estimate time for program to complete
C3D_LOAD_TIME = 1;
TIME_NORMALIZE_TIME = 2;
VECTOR_CODE_TIME = 1;
VARIABLE_PULL_TIME = 2;

if exist(strcat(fileListPath,'results.xlsx'))
    warning(['A ''results.xlsx'' file already exists in the path. This file will be overridden ',...
             'when the program completes. If you don''t want those results to be lost, ',...
             'rename or move the file.'])
end

[variableListStatus,variableListSheets] = xlsfinfo(variableList);
if ~any(strcmp(variableListSheets,'Variables')) || ~any(strcmp(variableListSheets,'Events'))
    error(['A ''Variables'' sheet and an ''Events'' sheet are required for this program, ',...
           'and at least one was not found in the variableList excel file. ',...
           'See exampleVariableList.'])
end
disp('Loading variable list...');
[numVariables,txtVariables,rawVariables] = xlsread(variableList, 'Variables');
[numEvents,txtEvents,rawEvents] = xlsread(variableList, 'Events');
allVariables = txtVariables(:,1);
if isempty(allVariables)
    error(['Variable list is empty. Check the ''Variables'' sheet of the variableList ',...
           'file and ensure that column A includes the needed variables.'])
end
number_of_variables = length(allVariables);
allVariables = reshape(allVariables, [1,number_of_variables]);

if any(strcmp(variableListSheets,'Measures'))
    variablePulling = true; %#ok<NASGU>
    [numMeasures,txtMeasures,rawMeasures] = xlsread(variableList, 'Measures');
    number_of_measures = size(txtMeasures,1);
    % Instantiates variable pull output cell array (now that we know the size of the file list 
    % and variable list) and creates the header
    for kk = 1:number_of_measures
        VariablePullOutputColumnNames(1,end+1) = txtMeasures(kk,6); %#ok<SAGROW>
        if strcmp(txtMeasures(kk,7), 'Yes')
                VariablePullOutputColumnNames(1,end+1) = strcat('time', txtMeasures(kk,6)); %#ok<SAGROW>
        end
    end
    outputVariablePull = cell([number_of_files+1, length(VariablePullOutputColumnNames)]);
    for kk = 1:length(VariablePullOutputColumnNames)
        outputVariablePull(1,1:length(VariablePullOutputColumnNames)) = VariablePullOutputColumnNames;
    end
end

% ******************* COMMENT THIS WHEN VARIABLE PULLING *************************
%                               variablePulling = false;
% ********************************************************************************

if ~any(strcmp(variableListSheets,'Vector Code'))
    warning(['A ''Vector Code'' sheet was not found in the variable list. If you intended ',...
            'to perform a vector coding analysis, stop the program and add/rename that  ',...
            'sheet in the variable list.'])
else
    vectorCoding = true;
    [numVectorCode,txtVectorCode,rawVectorCode] = xlsread(variableList, 'Vector Code');
    global customsave;
    customsave = 0;
    global subjectFolderSave;
    subjectFolderSave = 0;
    global customSavePath;
    customSavePath = 'None Specified';
    
    msg = ['Where would you like to save the vector code figures?'];
    SaveResponse = questdlg(msg, ...
                'Figure Save Location', ...
                'Custom Folder', 'Subject Folders', 'Both', 'Custom Folder');
    drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved

    if strcmp(SaveResponse, 'Both')
        customsave = 1;
        subjectFolderSave = 1;
    elseif strcmp(SaveResponse, 'Subject Folders')
        customsave = 0;
        subjectFolderSave = 1;
    elseif strcmp(SaveResponse, 'Custom Folder')
        customsave = 1;
        subjectFolderSave = 0;
    end

    if customsave
        customSavePath = uigetdir(fileListPath);
    end
    number_of_vector_code_pairs = size(txtVectorCode,1);
    % Defines the structure of the results file vector code sheet and creates variables which 
    % reference each column in case you add/change the order of the output
    if Normalization == 1
        outputVectorCodeColumnNames = {'File Name', 'ID', 'Number', 'Last Name', 'First Name', ...
        'Trial Type', 'Session', 'Side', 'Cycle Info', 'Affected Side', 'Variable 1', 'Plane 1', ...
        'Variable 2', 'Plane 2', 'PD In-Phase', 'In-Phase', 'DD In-Phase', 'DD Anti-Phase', ...
        'Anti-Phase', 'PD Anti-Phase', 'LR PD In-Phase', 'LR In-Phase', 'LR DD In-Phase', ...
        'LR DD Anti-Phase', 'LR Anti-Phase','LR PD Anti-Phase','SLS PD In-Phase', 'SLS In-Phase',...
        'SLS DD In-Phase', 'SLS DD Anti-Phase', 'SLS Anti-Phase', 'SLS PD Anti-Phase', ... 
        'PS PD In-Phase', 'PS In-Phase', 'PS DD In-Phase', 'PS DD Anti-Phase', 'PS Anti-Phase',...
        'PS PD Anti-Phase'};
    
        outputVectorCodeFileNameColumn = strmatch('File Name', outputVectorCodeColumnNames);
        outputVectorCodeLR_PDIPColumn = strmatch('LR PD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeLR_IPColumn = strmatch('LR In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeLR_DDIPColumn = strmatch('LR DD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeLR_DDAPColumn = strmatch('LR DD Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodeLR_APColumn = strmatch('LR Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodeLR_PDAPColumn = strmatch('LR PD Anti-Phase', outputVectorCodeColumnNames);

        outputVectorCodeSLS_PDIPColumn = strmatch('SLS PD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeSLS_IPColumn = strmatch('SLS In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeSLS_DDIPColumn = strmatch('SLS DD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodeSLS_DDAPColumn = strmatch('SLS DD Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodeSLS_APColumn = strmatch('SLS Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodeSLS_PDAPColumn = strmatch('SLS PD Anti-Phase', outputVectorCodeColumnNames);

        outputVectorCodePS_PDIPColumn = strmatch('PS PD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodePS_IPColumn = strmatch('PS In-Phase', outputVectorCodeColumnNames);
        outputVectorCodePS_DDIPColumn = strmatch('PS DD In-Phase', outputVectorCodeColumnNames);
        outputVectorCodePS_DDAPColumn = strmatch('PS DD Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodePS_APColumn = strmatch('PS Anti-Phase', outputVectorCodeColumnNames);
        outputVectorCodePS_PDAPColumn = strmatch('PS PD Anti-Phase', outputVectorCodeColumnNames);
    else
        outputVectorCodeColumnNames = {'File Name', 'ID', 'Number', 'Last Name', 'First Name', ...
        'Trial Type', 'Session', 'Side', 'Cycle Info', 'Affected Side', 'Variable 1', 'Plane 1', ...
        'Variable 2', 'Plane 2', 'PD In-Phase','In-Phase', 'DD In-Phase', 'DD Anti-Phase', ...
        'Anti-Phase', 'PD Anti-Phase'};
    end

    outputVectorCodeVariable1Column = strmatch('Variable 1', outputVectorCodeColumnNames);
    outputVectorCodePlane1Column = strmatch('Plane 1', outputVectorCodeColumnNames);
    outputVectorCodeVariable2Column = strmatch('Variable 2', outputVectorCodeColumnNames);
    outputVectorCodePlane2Column = strmatch('Plane 2', outputVectorCodeColumnNames);
    
    % Vector Code bincounts
    outputVectorCodeCycle_PDIPColumn = strmatch('PD In-Phase', outputVectorCodeColumnNames);
    outputVectorCodeCycle_IPColumn = strmatch('In-Phase', outputVectorCodeColumnNames);
    outputVectorCodeCycle_DDIPColumn = strmatch('DD In-Phase', outputVectorCodeColumnNames);
    outputVectorCodeCycle_DDAPColumn = strmatch('DD Anti-Phase', outputVectorCodeColumnNames);
    outputVectorCodeCycle_APColumn = strmatch('Anti-Phase', outputVectorCodeColumnNames);
    outputVectorCodeCycle_PDAPColumn = strmatch('PD Anti-Phase', outputVectorCodeColumnNames);

    % Preallocates memory based on size of the file list and the vector code sheet. 
    % Also adds a header to the output structure
    outputVectorCode = cell([number_of_files*number_of_vector_code_pairs,...
                                length(outputVectorCodeColumnNames)]);
    outputVectorCode(1,:) = outputVectorCodeColumnNames;

    %% User prompts to determine how the code will run
    % If you are running more than 5 files, previewing/approving will take forever. 
    % This feature was only inteneded to be used on a small file list, like if some files
    % failed, and you were troubleshooting
    if number_of_files < 5 
        PreviewResponse = questdlg('Would you like to preview each figure before it is saved?', ...
                                   'Preview Prompt', ...
                                   'Yes','No', 'Yes');
        drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
    end 
end 

if variablePulling
    msg = ['Would you like to average the variable pull results?'];
    variablePullAverageResponse = questdlg(msg, ...
                'Variable Pull Average Prompt', ...
                'No', 'By Context', 'Across Sides', 'No');
    drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
end

if vectorCoding
    msg = ['Would you like to average the vector code results?'];
    vectorCodeAverageResponse = questdlg(msg, ...
                'Vector Code Average Prompt', ...
                'No', 'By Context', 'Across Sides', 'No');
    drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
end

% Removes duplicate variables
found = 0;
A = allVariables{1};
uniqueVariables{1} = A(2:end);
for ii = 2:max(length(allVariables))
    A = allVariables{ii};
    if isempty(find(strcmp(uniqueVariables,A(2:end))))
        uniqueVariables{end+1} = A(2:end); %#ok<SAGROW>
    end
end
number_of_variables = max(length(uniqueVariables));

% Cuts out variables from variable list if they aren't in variable pull or vector coding. 
% This speeds up the program a lot
for ii = 1:number_of_variables
    currentCheck = uniqueVariables{ii};
    if (variablePulling && vectorCoding)
        for jj = 1:size(txtMeasures,1)
            if ~isempty(find(strcmp(txtMeasures(jj,1),currentCheck)))
                 found = 1;
                 break
            end
        end
        for jj = 1:size(txtVectorCode)
            if [~isempty(find(strcmp(txtVectorCode(jj,1),currentCheck))) || ...
                     ~isempty(find(strcmp(txtVectorCode(jj,4),currentCheck)))]
                     found = 1;
                     break
            end
        end
        if found == 1    
            Variables{end+1} = uniqueVariables{ii}; %#ok<SAGROW>
            found = 0;
        end
        TIMETOCOMPLETE = number_of_files * (C3D_LOAD_TIME + TIME_NORMALIZE_TIME + ...
                         VARIABLE_PULL_TIME) + size(txtVectorCode,1) * VECTOR_CODE_TIME ;

    elseif variablePulling
        for jj = 1:size(txtMeasures,1)
            if ~isempty(find(strcmp(txtMeasures(jj,1),currentCheck)))
                 found = 1;
                 break
            end
        end
        if found == 1    
            Variables{end+1} = uniqueVariables{ii}; %#ok<SAGROW>
            found = 0;
        end
        TIMETOCOMPLETE = number_of_files * (C3D_LOAD_TIME + TIME_NORMALIZE_TIME + VARIABLE_PULL_TIME);

    elseif vectorCoding
        for jj = 1:size(txtVectorCode,1)
            if [~isempty(find(strcmp(txtVectorCode(jj,1),currentCheck))) || ...
                 ~isempty(find(strcmp(txtVectorCode(jj,4),currentCheck))) ]
                 found = 1;
                 break
            end
        end
        if found == 1    
            Variables{end+1} = uniqueVariables{ii}; %#ok<SAGROW>
            found = 0;
        end
        TIMETOCOMPLETE = number_of_files * (C3D_LOAD_TIME + TIME_NORMALIZE_TIME) + ...
                         size(txtVectorCode,1) * VECTOR_CODE_TIME ;

    else
        error('This code requires at least one analysis to run! (variable pull, vector code, ect.)')
    end
end

Variables = reshape(Variables, [1, length(Variables)]);
number_of_variables = length(Variables);

% Builds the row name and number for rawData sheet
for ii = 1:length(number_of_files)
    if strcmp(txtFile(ii,7), 'Both') || strcmp(txtFile(ii,7), 'B')
        boths = boths + 1;
    end
end

% Preallocate memory for raw data
rawData = cell([(number_of_variables*3*100 + 5) (3 + number_of_files + boths)]);
variableSet = txtVariables(:,1);
variableNicknames = txtVariables(:,2:4);
n = 12;

for ii = 0:number_of_variables-1
    B = Variables{ii+1};
    locations = strfind(variableSet,B);
    index = min(find(~cellfun(@isempty,locations)));
    for jj = 1:3
        if strcmp(variableNicknames{index,jj}, 'xx')
            continue
        end
        currentNickname = char(variableNicknames{index,jj});
        for kk = 0:100
            rawData{n,1} = currentNickname;
            rawData{n,2} = kk;
            n = n + 1;
        end
    end
end

C3DCom = c3dserver;

%% Rough estimate of time to execute
if strcmp(PreviewResponse, 'No')
    hours = int16(TIMETOCOMPLETE / 3600);
    minutes = int16(TIMETOCOMPLETE - hours*60) / 60;
    seconds = rem((TIMETOCOMPLETE - hours*60), 60); 
    %fprintf(['\n\n*****Estimated time to completion: %d hours %d minutes %d seconds*****\n\n', ...
            % hours, minutes,seconds]);
end   

if vectorCoding
    processingSteps = processingSteps + 1;
end
if variablePulling
    processingSteps = processingSteps + 1;
end


%% Retrieve data and perform calculations
for ii = 1:number_of_files
    fprintf('\n\n\n')
    multiWaitbar('Processing File List', ii/number_of_files);
    currentFilePath = txtFile{ii,inputFilePathColumn};
    [currentSessionName, currentFolder, currentFileName, currentID] = parseFilePath(currentFilePath);
    
    if ii == 1
        currentSubject = Subject;
        Subjects = [Subjects; currentSubject];
        currentSubject.ID = currentID{1};
        currentSubject.number = numFile(ii,1);
        currentSubject.last_name = txtFile{ii,inputLastNameColumn};
        currentSubject.first_name = txtFile{ii,inputFirstNameColumn};
        currentSubject.affected_side = txtFile{ii,inputAffectedSideColumn};
        currentSubject.validateProperties()
        if currentSubject.flag == 1
            warning(currentSubject.reasonForFlag)
            addToProblemFiles(currentFilePath, currentSubject)
            continue
        end
        currentSession = Session;
        currentSubject.Sessions = [currentSubject.Sessions; currentSession];
        currentSession.name = currentSessionName;
        currentSession.Folder = currentFolder;
        currentSession.validateProperties(txtFile{ii,inputSessionColumn})
        if currentSession.flag == 1
            warning(currentSession.reasonForFlag)
            addToProblemFiles(currentFilePath, currentSession)
            continue
        end
    else
        if ischar(Subjects(1).ID)
            I = strfind([Subjects.ID], currentID);
        else
            I = find(Subjects.ID == currentID);
        end
        
        if isempty(I)
            currentSubject = Subject;
            disp('New Subject Created.')
            Subjects = [Subjects; currentSubject];
            currentSubject.ID = currentID{1};
            currentSubject.number = numFile(ii,1);
            currentSubject.last_name = txtFile{ii,inputLastNameColumn};
            currentSubject.first_name = txtFile{ii,inputFirstNameColumn};
            currentSubject.affected_side = txtFile{ii,inputAffectedSideColumn};
            currentSubject.validateProperties()
            if currentSubject.flag == 1
                warning(currentSubject.reasonForFlag)
                addToProblemFiles(currentFilePath, currentSubject)
                continue
            end
        else
            if ischar(Subjects(1).ID)
                I = (I - 1 ) / 5 + 1;
                currentSubject = Subjects(I);
            else
                currentSubject = Subjects(I);
            end
            
        end

        I = find(currentSubject.Sessions == currentSession);
        if isempty(I)
            currentSession = Session;
            currentSubject.Sessions = [currentSubject.Sessions; currentSession];
            currentSession.name = currentSessionName;
            currentSession.Folder = currentFolder;
            currentSession.validateProperties(txtFile{ii,inputSessionColumn})
            if currentSession.flag == 1
                warning(currentSession.reasonForFlag)
                addToProblemFiles(currentFilePath, currentSession)
                continue
            end
        else
            currentSession = currentSubject.Sessions(I);
        end
    end

    % This assumes a new line in the file list is ALWAYS a trial that hasn't been processed before
    currentTrial = Trial;
    currentSession.Trials = [currentSession.Trials; currentTrial];
    currentTrial.fileName = currentFileName;
    currentTrial.trial_type = txtFile{ii,inputTrialType};
    currentTrial.cycle_info = txtFile{ii,inputCycleInfoColumn};
    if strcmp(txtFile{ii, inputSideColumn},'B') || strcmp(txtFile{ii, inputSideColumn},'Both')
        currentTrial.sides = ['L','R'];
        currentSession.sides = ['L', 'R'];
    else
        if strcmp(txtFile{ii, inputSideColumn},'Left')
            currentTrial.sides = ['L'];
        elseif strcmp(txtFile{ii, inputSideColumn},'Right')
            currentTrial.sides = ['R'];
        else
            currentTrial.sides = [txtFile{ii, inputSideColumn}];
        end
        if ~ismember(currentTrial.sides, currentSession.sides)
            currentSession.sides = [currentSession.sides, currentTrial.sides];
        end
    end
    number_of_sides = length(currentTrial.sides);
    if Normalization == 1
        eventsMap = {'Foot Strike', 'Opposite Foot Off', 'Opposite Foot Strike', ...
                                  'Foot Off', 'Foot Strike'};
    elseif Normalization == 2
        eventsMap = {'Foot Strike', 'Foot Off', 'Foot Strike'};
    elseif Normalization == 3
        eventsMap = {'Foot Strike', 'Foot Off1', 'Foot Off2','Foot Strike'};
    elseif Normalization == 4
        eventsMap = {'Foot Strike','General Event','Foot Off','Foot Strike'};
    elseif Normalization == 5
        eventsMap = {'Foot Strike', 'Foot Off', 'General Event'};
    elseif Normalization == 6
        eventsMap = {'Foot Off', 'General Event', 'Foot Off'};
    elseif Normalization == 7
        eventsMap = {'General Event', 'Foot Off', 'Foot Strike', 'General Event'};
    elseif Normalization == 8
        eventsMap = {'Foot Strike', 'General Event', 'Foot Off'};
    elseif Normalization == 9
        eventsMap = {'Foot Off', 'Foot Strike','Foot Off'};
    elseif Normalization == 10
        eventsMap = {'Foot Strike', 'Foot Strike'};
    elseif Normalization == 11
        eventsMap = {'Foot Strike', 'General Event'};
    end
    currentTrial.validateProperties()
    if currentTrial.flag == 1
        warning(currentTrial.reasonForFlag)
        addToProblemFiles(currentFilePath, currentTrial)
        continue
    end

    % This step was necessary because we were orignially vector coding variables that came from
    % running the foot and ankle model. Sometimes this created a new c3d file with _fa
    % appended to the end. I wrote the function in a way that could be expanded to other 
    % suffixes. I temporarily only prompted the user if it was a normal walking trial, but if
    % you have suffixes for another type of trial, you can remove the "if Normalization == 1" from
    % below and at the prompt (search for "appendPrompt")
    if Normalization == 1
        if ~strcmp(appendPrompt, 'No')
            switch appendPrompt
                case 'Custom'
                    suffix = input('Try to append this to file names: ', 's');
                    appendToFileName(currentSession, currentTrial, suffix)
                case '_fa' 
                    suffix = '_fa';
                    appendToFileName(currentSession, currentTrial, suffix)
            end
            currentFilePath = strcat(currentSession.Folder, currentTrial.fileName);
        end
    end

    fprintf('(%d/%d)', ii, number_of_files)
    openc3d(C3DCom,1,currentFilePath);
    %% Import C3D data
    fprintf('Importing data...\n')
    frames = nframes(C3DCom);
    currentTrial.DataArray = zeros(frames,3,number_of_variables, number_of_sides);
    %% Collects data from patient c3d file
    for jj = 1:number_of_sides
        for kk=1:number_of_variables
            v=cell2mat(genvarname(strcat(currentTrial.sides(jj),Variables(1,kk))));
            X=get3dtarget(C3DCom,v,0);
            if isnan(X)
                v2 = strcat('Spec2:',v); %add subject name to front of traj
                X=get3dtarget(C3DCom,v2,0); %pull Subj_traj
            end

            % I put this step in a try-catch, so if there is a size mismatch error we can get 
            % more information about the size of the vectors.
            try            
                currentTrial.DataArray(:,:,kk,jj)=X;
            catch ME
                errorA = currentTrial.DataArray;
                errorB = X;
                currentTrial.flag = 1;
                switch ME.identifier
                    case 'MATLAB:subsassigndimmismatch'
                        if(size(errorA,2) ~= size(errorB,2))
                            currentTrial.flag = 1;
                            msg = ['Dimension mismatch occurred: First argument has ', ...
                                num2str(size(errorA,2)),' columns while second has ', ...
                                num2str(size(errorB,2)),' columns.'];
                            fprintf('current variable: %s has a problem \n', Variables{1,kk})
                            currentTrial.reasonForFlag = msg;
                        elseif(size(errorA,1) ~= size(errorB,1))
                            msg = ['Dimension mismatch occurred: First argument has ', ...
                                num2str(size(errorA,1)),' rows while second has ', ...
                                num2str(size(errorB,1)),' rows.'];
                            fprintf('current variable: %s \n', Variables{1,kk})
                        elseif(size(errorA,3) ~= size(errorB,3))
                            msg = ['Dimension mismatch occurred: First argument has ', ...
                                num2str(size(errorA,3)),' matrixes while second has ', ...
                                num2str(size(errorB,3)),' matrixes.'];
                            fprintf('current variable: %s \n', Variables{1,kk})
                        end
                        currentTrial.reasonForFlag = strcat(ME.message,msg);
                    otherwise
                        currentTrial.reasonForFlag = ME.message;
                end
                break
            end
        end
    end

    if currentTrial.flag == 1
        warning(currentTrial.reasonForFlag)
        addToProblemFiles(currentFilePath, currentTrial)
        continue
    end

    for jj = 1:number_of_sides
        for kk = 1:number_of_variables
            if sum(currentTrial.DataArray(:,:,kk,jj)) == 0
                currentTrial.flag = 1;
                currentTrial.reasonForFlag = 'Data array is empty';
                break
            end
        end
        if currentTrial.flag == 1
            break
        end
    end
    if currentTrial.flag == 1;
        addToProblemFiles(currentFilePath, currentTrial)
        warning(currentTrial.reasonForFlag)
        continue
    end

    %% Get events and time normalize
    warning('off','MATLAB:chckxy:IgnoreNaN')
    currentTrial.getEvents(C3DCom, Variables); %getEvents calls timeNormalizeData
    if currentTrial.flag == 1
        addToProblemFiles(currentFilePath, currentTrial)
        warning(currentTrial.reasonForFlag)
        continue
    end

    % Calculates Measures specified in the "Measures" tab of variableList
    if variablePulling
        fprintf('Running variable pull...\n')
        currentTrial.variablePullResults = zeros(1,number_of_measures,number_of_sides);
        currentTrial.variablePullTiming = zeros(1,number_of_measures,number_of_sides);
        for jj = 1:number_of_measures
            VariablePullOutputColumnCounter = length(header) + 2;
            currentVariable = txtMeasures(jj,1);
            currentPlane = txtMeasures(jj,2);
            event1 = txtMeasures(jj,3);
            event2 = txtMeasures(jj,4);
            currentFeature = txtMeasures(jj,5);
            currentLabel = txtMeasures(jj,6);
            gettingTime = txtMeasures(jj,7);
            for kk = 1:number_of_sides
                DataCycle = currentTrial.GaitCycle(:,:,:,kk);
                CycleNorm = currentTrial.CycleNorm(:,:,kk);
                [currentResult,currentTiming] = variablePull(currentVariable, currentPlane, event1, event2, ...
                                                currentFeature, currentLabel, gettingTime, DataCycle, CycleNorm);
                currentTrial.variablePullResults(1,jj,kk) = currentResult;
                currentTrial.variablePullTiming(1,jj,kk) = currentTiming;
            end
        end
    end

    if currentTrial.flag == 1
        warning(currentTrial.reasonForFlag)
        addToProblemFiles(currentFilePath, currentTrial)
        continue
    end

    % Calculates bin counts of couples specified in the "Vector Code" tab of variableList
    if vectorCoding
        fprintf('Vector Coding...\n')
        %% Parse Variable List
        for jj = 1:number_of_vector_code_pairs
            currentVariable1 = txtVectorCode(jj,1);
            currentVariable2 = txtVectorCode(jj,4);
            currentPlane1 = txtVectorCode(jj,2);
            currentPlane2 = txtVectorCode(jj,5);
            norm1 = numVectorCode(jj,1);
            norm2 = numVectorCode(jj,4);
            event1 = txtVectorCode(jj,7);
            event2 = txtVectorCode(jj,8);

            for kk = 1:number_of_sides
                currentSide = currentTrial.sides(kk);
                if kk == 2
                    if strcmp(PreviewResponse, 'Yes') 
                        continuePrompt = questdlg('Next Side?', ...
                            'Plot Validation Prompt', ...
                            'Yes','Next Joint/Seg Pair', 'Stop Program', 'Yes');
                            drawnow; pause(0.05);
                        if strcmp(continuePrompt, 'Next Joint/Seg Pair')
                            close
                            continue
                        elseif strcmp(continuePrompt, 'Stop Program')
                            close
                            return
                        else
                            close
                        end
                    end
                end
                DataCycle = currentTrial.GaitCycle(:,:,:,kk);
                CycleNorm = currentTrial.CycleNorm(:,:,kk);
                [mainFigure,figureName, bincounts] = VectorCode(currentVariable1, currentPlane1, norm1,...
                                                     currentVariable2, currentPlane2, norm2, ...
                                                     event1, event2, currentSubject, DataCycle, CycleNorm, kk);
                figureName = char(strcat(num2str(currentSubject.ID), {' '}, currentTrial.fileName(1:end-4), {' - '}, figureName));
                if mainFigure == 9999
                    msg = sprintf('Invalid figure for file %s (R Side, %s %s). Moving on to next side...', currentFile, currentVariable1{:}, currentVariable2{:});
                    warning(msg)
                    currentTrial.flag = 1;
                    currentTrial.reasonForFlag = msg;
                    addToProblemFiles(currentFilePath, currentTrial)
                else
                    saveFigure(currentSession, mainFigure, figureName)
                end
                
                    header = generateHeader(currentSubject, currentSession, currentTrial, currentSide);
                
                    outputVectorCode(rowCounter, 1:length(header)) = header;
                    
                    outputVectorCode{rowCounter, outputVectorCodeVariable1Column} = currentVariable1{:};
                    outputVectorCode{rowCounter, outputVectorCodePlane1Column} = currentPlane1{:};
                    outputVectorCode{rowCounter, outputVectorCodeVariable2Column} = currentVariable2{:};
                    outputVectorCode{rowCounter, outputVectorCodePlane2Column} = currentPlane2{:};

                    % Bin Counts Cycle
                    outputVectorCode{rowCounter, outputVectorCodeCycle_PDIPColumn} = bincounts(1,1);
                    outputVectorCode{rowCounter, outputVectorCodeCycle_IPColumn} = bincounts(1,2);
                    outputVectorCode{rowCounter, outputVectorCodeCycle_DDIPColumn} = bincounts(1,3);
                    outputVectorCode{rowCounter, outputVectorCodeCycle_DDAPColumn} = bincounts(1,4);
                    outputVectorCode{rowCounter, outputVectorCodeCycle_APColumn} = bincounts(1,5);
                    outputVectorCode{rowCounter, outputVectorCodeCycle_PDAPColumn} = bincounts(1,6);

                    if Normalization == 1
                        % Bin Counts LR
                        outputVectorCode{rowCounter,outputVectorCodeLR_PDIPColumn} = bincounts(2,1);
                        outputVectorCode{rowCounter,outputVectorCodeLR_IPColumn} = bincounts(2,2);
                        outputVectorCode{rowCounter,outputVectorCodeLR_DDIPColumn} = bincounts(2,3);
                        outputVectorCode{rowCounter,outputVectorCodeLR_DDAPColumn} = bincounts(2,4);
                        outputVectorCode{rowCounter,outputVectorCodeLR_APColumn} = bincounts(2,5);
                        outputVectorCode{rowCounter,outputVectorCodeLR_PDAPColumn} = bincounts(2,6);

                        % Bin Counts SLS
                        outputVectorCode{rowCounter,outputVectorCodeSLS_PDIPColumn} = bincounts(3,1);
                        outputVectorCode{rowCounter,outputVectorCodeSLS_IPColumn} = bincounts(3,2);
                        outputVectorCode{rowCounter,outputVectorCodeSLS_DDIPColumn} = bincounts(3,3);
                        outputVectorCode{rowCounter,outputVectorCodeSLS_DDAPColumn} = bincounts(3,4);
                        outputVectorCode{rowCounter,outputVectorCodeSLS_APColumn} = bincounts(3,5);
                        outputVectorCode{rowCounter,outputVectorCodeSLS_PDAPColumn} = bincounts(3,6);

                        % Bin Counts PS
                        outputVectorCode{rowCounter,outputVectorCodePS_PDIPColumn} = bincounts(4,1);
                        outputVectorCode{rowCounter,outputVectorCodePS_IPColumn} = bincounts(4,2);
                        outputVectorCode{rowCounter,outputVectorCodePS_DDIPColumn} = bincounts(4,3);
                        outputVectorCode{rowCounter,outputVectorCodePS_DDAPColumn} = bincounts(4,4);
                        outputVectorCode{rowCounter,outputVectorCodePS_APColumn} = bincounts(4,5);
                        outputVectorCode{rowCounter,outputVectorCodePS_PDAPColumn} = bincounts(4,6);
                    end
                    rowCounter = rowCounter + 1;
                

                if strcmp(PreviewResponse, 'Yes')
                    continuePrompt = questdlg('Continue to next in Variable List?', ...
                        'Plot Validation Prompt', ...
                        'Yes','Next File', 'Stop', 'Yes');
                        drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
                    if strcmp(continuePrompt, 'Next File')
                        close all 
                        break
                    elseif strcmp(continuePrompt, 'Stop')
                        close all 
                        return
                    else
                        close all
                    end
                end
            end
        end

        if currentTrial.flag == 1
            warning(currentTrial.reasonForFlag)
            addToProblemFiles(currentFilePath, currentTrial)
            continue
        end
    end
end

number_of_subjects = length(Subjects)

%% Adds data to Raw Data results sheet
columnCounter = 4;
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
                rawData(1:length(header),columnCounter) = header;
                rowCounter = length(header) + 2; % Starts two rows below the header
                for mm = 1:number_of_variables
                    B = Variables{mm};
                    locations = strfind(variableSet,B);
                    index = min(find(~cellfun(@isempty,locations)));
                    for nn = 1:3
                        if strcmp(variableNicknames{index,nn}, 'xx')
                            continue
                        end
                        for oo = 1:101
                            try
                                rawData{rowCounter,columnCounter} = currentTrial.GaitCycle(oo,nn,mm);
                            catch ME
                                rawData{rowCounter,columnCounter} = 999;
                                currentSession.flag = 1;
                                currentSession.reasonForFlag = sprintf(['incomplete %s gait cycle ',...
                                                            ' while writing to raw data'], currentSide);
                            end
                            rowCounter = rowCounter + 1;
                        end
                    end
                end
                columnCounter = columnCounter + 1;
            end
        end
    end
end

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

% Average Gait Data in the session by context
if strcmp(variablePullAverageResponse, 'By Context') || strcmp(vectorCodeAverageResponse, 'By Context')
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
                currentSession.aveCycleNorm = zeros(1,5,number_of_sides);
                currentSession.aveGaitCycle = zeros(101,3,number_of_variables,length(currentSession.sides));
                for ll = 1:number_of_sides
                    if strcmp(currentTrial.sides(ll),'L') 
                        currentSession.aveCycleNorm(:,:,1) = currentSession.aveCycleNorm(:,:,1) + currentTrial.CycleNorm(:,:,ll);
                        currentSession.aveGaitCycle(:,:,:,1) = currentSession.aveGaitCycle(:,:,:,1) + currentTrial.GaitCycle(:,:,:,ll);
                        currentSession.byContextCounter(1) = currentSession.byContextCounter(1) + 1;
                    else
                        currentSession.aveCycleNorm(:,:,2) = currentSession.aveCycleNorm(:,:,2) + currentTrial.CycleNorm(:,:,ll);
                        currentSession.aveGaitCycle(:,:,:,2) = currentSession.aveGaitCycle(:,:,:,2) + currentTrial.GaitCycle(:,:,:,ll);
                        currentSession.byContextCounter(2) = currentSession.byContextCounter(2) + 1;
                    end
                end
            end
            if currentSession.byContextCounter(1) > 1
                currentSession.aveCycleNorm(:,:,1) = currentSession.aveCycleNorm(:,:,1) / currentSession.byContextCounter(1);
                currentSession.aveGaitCycle(:,:,:,1) = currentSession.aveGaitCycle(:,:,:,1) / currentSession.byContextCounter(1);
            end
            if currentSession.byContextCounter(2) > 1
                currentSession.aveCycleNorm(:,:,2) = currentSession.aveCycleNorm(:,:,2) / currentSession.byContextCounter(2);
                currentSession.aveGaitCycle(:,:,:,2) = currentSession.aveGaitCycle(:,:,:,2) / currentSession.byContextCounter(2);
            end
        end
    end
end

% Average Gait Data in the session across sides
if strcmp(variablePullAverageResponse, 'Across Sides') || strcmp(vectorCodeAverageResponse, 'Across Sides')
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
                currentSession.aveCycleNorm = zeros(1,5,1); % Ends in 1 because all sides being combined
                currentSession.aveGaitCycle = zeros(101,3,number_of_variables, 1); % Ends in 1 because all sides being combined
                for ll = 1:number_of_sides
                    currentSide = currentTrial.sides(ll);
                    currentSession.aveCycleNorm(:,:,1) = currentSession.aveCycleNorm(:,:,1) + currentTrial.CycleNorm(:,:,ll);
                    currentSession.aveGaitCycle(:,:,:,1) = currentSession.aveGaitCycle(:,:,:,1) + currentTrial.GaitCycle(:,:,:,ll);
                    currentSession.acrossSidesCounter = currentSession.acrossSidesCounter + 1;
                end
            end
            if currentSession.acrossSidesCounter > 1
                currentSession.aveCycleNorm(:,:) = currentSession.aveCycleNorm(:,:) / currentSession.acrossSidesCounter;
                currentSession.aveGaitCycle(:,:,:) = currentSession.aveGaitCycle(:,:,:) / currentSession.acrossSidesCounter;
            end
        end
    end
end

%% Shapes averaged data into cell array for writing to excel
if strcmp(variablePullAverageResponse, 'Across Sides') || strcmp(vectorCodeAverageResponse, 'Across Sides') || strcmp(variablePullAverageResponse, 'By Context') || strcmp(vectorCodeAverageResponse, 'By Context')
    % Preallocate memory for ave raw data
    aveRawData = cell([(number_of_variables*3*100 + 5) (3 + number_of_files + boths)]);
    aveRawData(:,1) = rawData(:,1);
    if strcmp(variablePullAverageResponse, 'By Context') || strcmp(vectorCodeAverageResponse, 'By Context')
        %% Adds ave data to Ave Raw Data results sheet
        columnCounter = 4;
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                number_of_sides = length(currentSession.sides);
                for kk = 1:number_of_sides
                    currentSide = currentSession.sides(kk);
                    header = generateHeader(currentSubject, currentSession, currentSession.Trials(1), currentSide);
                    header{1} = currentSession.name;
                    aveRawData(1:length(header),columnCounter) = header;
                    rowCounter = length(header) + 2; % Starts two rows below the header
                    for mm = 1:number_of_variables
                        B = Variables{mm};
                        locations = strfind(variableSet,B);
                        index = min(find(~cellfun(@isempty,locations)));
                        for nn = 1:3
                            if strcmp(variableNicknames{index,nn}, 'xx')
                                continue
                            end
                            for oo = 1:101
                                try
                                    aveRawData{rowCounter,columnCounter} = currentSession.aveGaitCycle(oo,nn,mm,kk);
                                catch ME
                                    aveRawData{rowCounter,columnCounter} = 999;
                                    currentSession.flag = 1;
                                    currentSession.reasonForFlag = sprintf(['incomplete %s Data cycle ',...
                                                                ' while writing to average raw data'], currentSide);
                                end
                                rowCounter = rowCounter + 1;
                            end
                        end
                    end
                    columnCounter = columnCounter + 1;
                end
            end
        end
    end

    if strcmp(variablePullAverageResponse, 'Across Sides') || strcmp(vectorCodeAverageResponse, 'Across Sides')
        %% Adds ave data to Ave Raw Data results sheet
        columnCounter = 4;
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                number_of_sides = length(currentSession.sides);
                for ll = 1:number_of_sides
                    currentSide = currentSession.sides(ll);
                    if number_of_sides == 2;
                        header = generateHeader(currentSubject, currentSession, currentSession.Trials(1), 'B');
                    else
                        header = generateHeader(currentSubject, currentSession, currentSession.Trials(1), currentSide);
                    end
                    header{1} = currentSession.name;
                    aveRawData(1:length(header),columnCounter) = header;
                    rowCounter = length(header) + 2; % Starts two rows below the header
                    for mm = 1:number_of_variables
                        B = Variables{mm};
                        locations = strfind(variableSet,B);
                        index = min(find(~cellfun(@isempty,locations)));
                        for nn = 1:3
                            if strcmp(variableNicknames{index,nn}, 'xx')
                                continue
                            end
                            for oo = 1:101
                                try
                                    aveRawData{rowCounter,columnCounter} = currentSession.aveGaitCycle(oo,nn,mm);
                                catch ME
                                    aveRawData{rowCounter,columnCounter} = 999;
                                    currentSession.flag = 1;
                                    currentSession.reasonForFlag = sprintf(['incomplete %s Data cycle ',...
                                                                ' while writing to raw data'], currentSide);
                                end
                                rowCounter = rowCounter + 1;
                            end
                        end
                    end
                    columnCounter = columnCounter + 1;
                end
            end
        end
    end

end

%% Runs variable pull on session averages
if variablePulling
    if strcmp(variablePullAverageResponse, 'By Context')
        fprintf('Running average variable pull by context...\n')
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                number_of_sides = length(currentSession.sides);
                currentSession.averageVariablePullResults = zeros(1,number_of_measures,number_of_sides);
                currentSession.averageVariablePullTiming = zeros(1,number_of_measures,number_of_sides);
                for kk = 1:number_of_measures
                    %VariablePullOutputColumnCounter = length(header) + 2;
                    currentVariable = txtMeasures(kk,1);
                    currentPlane = txtMeasures(kk,2);
                    event1 = txtMeasures(kk,3);
                    event2 = txtMeasures(kk,4);
                    currentFeature = txtMeasures(kk,5);
                    currentLabel = txtMeasures(kk,6);
                    gettingTime = txtMeasures(kk,7);

                    for ll = 1:number_of_sides
                        DataCycle = currentSession.aveGaitCycle(:,:,:,ll);
                        CycleNorm = currentSession.aveCycleNorm(:,:,ll);
                        [currentResult,currentTiming] = variablePull(currentVariable, currentPlane, event1, event2, ...
                                                        currentFeature, currentLabel, gettingTime, DataCycle, CycleNorm);
                        currentSession.averageVariablePullResults(1,kk,ll) = currentResult;
                        currentSession.averageVariablePullTiming(1,kk,ll) = currentTiming;
                    end
                end
            end
        end
    end

    if strcmp(variablePullAverageResponse, 'Across Sides')
        fprintf('Running average variable pull across sides...\n')
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                currentSession.averageVariablePullResults = zeros(1,number_of_measures,1);
                currentSession.averageVariablePullTiming = zeros(1,number_of_measures,1);
                for kk = 1:number_of_measures
                    %VariablePullOutputColumnCounter = length(header) + 2;
                    currentVariable = txtMeasures(kk,1);
                    currentPlane = txtMeasures(kk,2);
                    event1 = txtMeasures(kk,3);
                    event2 = txtMeasures(kk,4);
                    currentFeature = txtMeasures(kk,5);
                    currentLabel = txtMeasures(kk,6);
                    gettingTime = txtMeasures(kk,7);
                    DataCycle = currentSession.aveGaitCycle(:,:,:,1);
                    CycleNorm = currentSession.aveCycleNorm(:,:,1);
                    [currentResult,currentTiming] = variablePull(currentVariable, currentPlane, event1, event2, ...
                                                    currentFeature, currentLabel, gettingTime, DataCycle, CycleNorm);
                    currentSession.averageVariablePullResults(1,kk,1) = currentResult;
                    currentSession.averageVariablePullTiming(1,kk,1) = currentTiming;
                end
            end
        end
    end  
end  

%% Runs vector code analysis on session averages
if vectorCoding
    if strcmp(vectorCodeAverageResponse, 'By Context')
        disp('running vector code average by context')
        vectorCodeAverage = cell([number_of_files*number_of_vector_code_pairs, length(outputVectorCodeColumnNames)]);
        vectorCodeAverage(1,1:length(outputVectorCodeColumnNames)) = outputVectorCodeColumnNames;
        rowCounter = 2;
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                number_of_sides = length(currentSession.sides);
                for kk = 1:number_of_vector_code_pairs
                    currentVariable1 = txtVectorCode(kk,1);
                    currentVariable2 = txtVectorCode(kk,4);
                    currentPlane1 = txtVectorCode(kk,2);
                    currentPlane2 = txtVectorCode(kk,5);
                    norm1 = numVectorCode(kk,1);
                    norm2 = numVectorCode(kk,4);
                    event1 = txtVectorCode(kk,7);
                    event2 = txtVectorCode(kk,8);
                    for ll = 1:number_of_sides
                        currentSide = currentSession.sides(ll);
                        DataCycle = currentSession.aveGaitCycle(:,:,:,ll);
                        CycleNorm = currentSession.aveCycleNorm(:,:,ll);
                        [mainFigure,figureName, bincounts] = VectorCode(currentVariable1, currentPlane1, norm1,...
                                                             currentVariable2, currentPlane2, norm2, ...
                                                             event1, event2, currentSubject, DataCycle, CycleNorm, ll);
                        figureName = char(strcat(num2str(currentSubject.ID), {' '}, currentSession.name, {' Ave - '}, figureName));
                        saveFigure(currentSession, mainFigure, figureName)

                        header = generateHeader(currentSubject, currentSession, currentSession.Trials(1), currentSide);
                        header{1} = currentSession.name;
                    
                        vectorCodeAverage(rowCounter, 1:length(header)) = header;
                        vectorCodeAverage{rowCounter, outputVectorCodeVariable1Column} = currentVariable1{:};
                        vectorCodeAverage{rowCounter, outputVectorCodePlane1Column} = currentPlane1{:};
                        vectorCodeAverage{rowCounter, outputVectorCodeVariable2Column} = currentVariable2{:};
                        vectorCodeAverage{rowCounter, outputVectorCodePlane2Column} = currentPlane2{:};
                        % Bin Counts Cycle
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_PDIPColumn} = bincounts(1,1);
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_IPColumn} = bincounts(1,2);
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_DDIPColumn} = bincounts(1,3);
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_DDAPColumn} = bincounts(1,4);
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_APColumn} = bincounts(1,5);
                        vectorCodeAverage{rowCounter, outputVectorCodeCycle_PDAPColumn} = bincounts(1,6);
                        rowCounter = rowCounter + 1;
                    end
                end
            end
        end
    end

    if strcmp(vectorCodeAverageResponse, 'Across Sides')
        disp('running vector code average across sides')
        vectorCodeAverage = cell([number_of_files*number_of_vector_code_pairs, length(outputVectorCodeColumnNames)]);
        vectorCodeAverage(1,1:length(outputVectorCodeColumnNames)) = outputVectorCodeColumnNames;
        rowCounter = 2;
        for ii = 1:number_of_subjects
            currentSubject = Subjects(ii);
            for jj = 1:length(currentSubject.Sessions)
                currentSession = currentSubject.Sessions(jj);
                if currentSession.flag
                    continue
                end
                for kk = 1:number_of_vector_code_pairs
                    currentVariable1 = txtVectorCode(kk,1);
                    currentVariable2 = txtVectorCode(kk,4);
                    currentPlane1 = txtVectorCode(kk,2);
                    currentPlane2 = txtVectorCode(kk,5);
                    norm1 = numVectorCode(kk,1);
                    norm2 = numVectorCode(kk,4);
                    event1 = txtVectorCode(kk,7);
                    event2 = txtVectorCode(kk,8);
                    DataCycle = currentSession.aveGaitCycle(:,:,:,1);
                    CycleNorm = currentSession.aveCycleNorm(:,:,1);
                    [mainFigure,figureName, bincounts] = VectorCode(currentVariable1, currentPlane1, norm1,...
                                                         currentVariable2, currentPlane2, norm2, ...
                                                         event1, event2, currentSubject, DataCycle, CycleNorm, 'B');
                    figureName = char(strcat(num2str(currentSubject.ID), {' '}, currentSession.name, {' Ave - '}, figureName));
                    saveFigure(currentSession, mainFigure, figureName)

                    currentSide = 'Across Sides';
                    header = generateHeader(currentSubject, currentSession, currentSession.Trials(1), currentSide);
                    header{1} = currentSession.name;
                
                    vectorCodeAverage(rowCounter, 1:length(header)) = header;
                    vectorCodeAverage{rowCounter, outputVectorCodeVariable1Column} = currentVariable1{:};
                    vectorCodeAverage{rowCounter, outputVectorCodePlane1Column} = currentPlane1{:};
                    vectorCodeAverage{rowCounter, outputVectorCodeVariable2Column} = currentVariable2{:};
                    vectorCodeAverage{rowCounter, outputVectorCodePlane2Column} = currentPlane2{:};
                    % Bin Counts Cycle
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_PDIPColumn} = bincounts(1,1);
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_IPColumn} = bincounts(1,2);
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_DDIPColumn} = bincounts(1,3);
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_DDAPColumn} = bincounts(1,4);
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_APColumn} = bincounts(1,5);
                    vectorCodeAverage{rowCounter, outputVectorCodeCycle_PDAPColumn} = bincounts(1,6);
                    rowCounter = rowCounter + 1;
                end
            end
        end
    end
end




%% Output Average Variable Pull results
if variablePulling 
    switch variablePullAverageResponse 
        case 'By Context'
            disp('outputting averaged VP results by context')
            variablePullAverage(1,1:length(VariablePullOutputColumnNames)) = VariablePullOutputColumnNames;
            rowCounter = 2;
            for ii = 1:number_of_subjects
                currentSubject = Subjects(ii);
                for jj = 1:length(currentSubject.Sessions)
                    currentSession = currentSubject.Sessions(jj);
                    if currentSession.flag
                        continue
                    end
                    number_of_sides = length(currentSession.sides);
                    for kk = 1:number_of_sides
                        currentSide = currentSession.sides(kk);
                        header = generateHeader(currentSubject, currentSession, currentTrial, currentSide);
                        header{1} = currentSession.name; % We want the first column to say the session name rather than the trial name which is what generateHeader() usually puts here
                        variablePullAverage(rowCounter, 1:length(header)) = header;
                        columnCounter = length(header) + 1;
                        for mm = 1:number_of_measures
                            variablePullAverage{rowCounter,columnCounter} = currentSession.averageVariablePullResults(1,mm,kk);
                            columnCounter = columnCounter + 1;
                            if currentSession.averageVariablePullTiming(mm) ~= 999
                                variablePullAverage{rowCounter,columnCounter} = currentSession.averageVariablePullTiming(1,mm,kk);
                                columnCounter = columnCounter + 1;
                            end
                        end     
                    end
                    rowCounter = rowCounter + 1;
                end
            end
        case 'Across Sides'
            disp('outputting averaged VP results across sides')
            variablePullAverage(1,1:length(VariablePullOutputColumnNames)) = VariablePullOutputColumnNames;
            rowCounter = 2;
            for ii = 1:number_of_subjects
                currentSubject = Subjects(ii);
                for jj = 1:length(currentSubject.Sessions)
                    currentSession = currentSubject.Sessions(jj);
                    if currentSession.flag
                        continue
                    end
                    number_of_sides = length(currentSession.sides);
                    if number_of_sides == 2
                        currentSide = 'B';
                    else
                        currentSide = currentSession.sides(1)
                    end
                    header = generateHeader(currentSubject, currentSession, currentTrial, currentSide);
                    header{1} = currentSession.name; % We want the first column to say the session name rather than the trial name which is what generateHeader() usually puts here
                    variablePullAverage(rowCounter, 1:length(header)) = header;
                    columnCounter = length(header) + 1;
                    for mm = 1:number_of_measures
                        variablePullAverage{rowCounter,columnCounter} = currentSession.averageVariablePullResults(1,mm,1);
                        columnCounter = columnCounter + 1;
                        if currentSession.averageVariablePullTiming(mm) ~= 999
                            variablePullAverage{rowCounter,columnCounter} = currentSession.averageVariablePullTiming(1,mm,1);
                            columnCounter = columnCounter + 1;
                        end
                    end 
                    rowCounter = rowCounter + 1;    
                end
            end
            header = generateHeader(currentSubject, currentSession, currentTrial, 'B');
    end
end

%% Output Average Vector Code results
% Vector code average results are updated as the bincounts are being calculated

%% Save Results

% This warning would just create confusion. Basically matlab throws a warning if you are saving to 
% a sheet that didn't previously exist, so I turned this warning off
warning('off', 'MATLAB:xlswrite:AddSheet') 

if variablePulling
    saveExcel(outputVariablePull, 'Variable Pull', fileListPath)
    saveExcel(rawData, 'Raw Data', fileListPath)
    if ~strcmp(variablePullAverageResponse, 'No')
        saveExcel(variablePullAverage, 'Avg Variable Pull', fileListPath)
    end
end
if vectorCoding
    saveExcel(outputVectorCode, 'Vector Code', fileListPath)
    if ~strcmp(vectorCodeAverageResponse, 'No')
        saveExcel(vectorCodeAverage, 'Avg Vector Code', fileListPath)
    end
end
if ~strcmp(variablePullAverageResponse, 'No') || ~strcmp(vectorCodeAverageResponse, 'No')
    saveExcel(aveRawData, 'Ave Raw Data', fileListPath)
end
if ~isempty(problemFiles)
    saveExcel(problemFiles, 'Problem Files', fileListPath)
    fprintf(['Program was unable to analyze %d files. Reasons have been added to the ',...
             '''Problem Files'' sheet of ''results.xlsx''\n', size(problemFiles,1)])
end
workspaceVariables = strcat(fileListPath, 'vector_code_workspace_', datestr(now, 'mm-dd-yyyy HH-MM'), '.mat');
save(workspaceVariables)
consoleLog = strcat(fileListPath, 'vector_code_consolelog_', datestr(now, 'mm-dd-yyyy HH-MM'), '.txt');
diary consoleLog
diary off
multiWaitbar('CLOSEALL');
disp('Processing Complete.')