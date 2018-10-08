function [outputSession, outputFolder, outputFileName, outputID] = parseFilePath(filePath) 
    slashes = strfind(filePath,'\');
    outputFolder = filePath(1:slashes(end));
    outputFileName = filePath(slashes(end)+1:end);
    pattern = '[A-Z a-z]{2}[0-9]{2}(?=\\)';
    outputSession = regexp(filePath, pattern, 'match');
    outputSession = outputSession{1};
    % check if this matches the file list
    pattern = '[0-9]{6}|(?<=\\)H{1}[0-9]{4}';
    outputID = regexp(filePath, pattern, 'match');
    if(size(outputID,2) > 1)
        warning('not sure if ID is %s or %s in %s! Picking the first...', ...
                 outputID{1}, outputID{2}, filePath)
    end
    %outputID = str2num(outputID{1});
end