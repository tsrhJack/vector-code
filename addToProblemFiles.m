function addToProblemFiles(filePath, object)
    global problemFiles;
    problemFiles{end+1,1} = filePath;
    problemFiles{end,2} = object.reasonForFlag;
end