function saveExcel(data, sheet_name, filePath)
    saveSuccess = 0;
    oldFolder = cd(filePath);
    while ~saveSuccess
        try
            % Try to open a workbook.
            xlswrite('results.xls', data, sheet_name)
            saveSuccess = 1;
        catch ME
            msg = 'The results file is already open in Excel. Please close ''results.xls''';
            causeException = MException('MATLAB:myCode:dimensions',msg);
            ME = addCause(ME,causeException);
            warning(msg)
            pause(1)
            irrelevant_response = questdlg(msg, ...
                    'Please close excel file', ...
                    'Ok', 'Ok');
            drawnow; pause(0.05);  % This prevents matlab from hanging after the response is recieved
        end
    end
    fprintf('Data added to ''%s'' sheet in results.xls\n', sheet_name)
    cd(oldFolder)
end