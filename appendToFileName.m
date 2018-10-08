function appendToFileName(trial, suffix)
    if isempty(strfind(trial.fileName, suffix))
        if exist(strcat(trial.fileName(1:end-4), suffix, '.c3d'), 'file') == 2
            msg = sprintf(['Current file is %s, and %s exists, so using that file instead.'], ...
                            trial.fileName, strcat(trial.fileName(1:end-4), suffix, '.c3d'));
            trial.fileName = strcat(trial.fileName(1:end-4), suffix, '.c3d');
            disp(msg)
        else
            msg = sprintf('%s does not exist. File will be skipped if model outputs are incomplete.', ...
                            strcat(trial.fileName(1:end-4), suffix, '.c3d'));
            warning(msg)
        end
    end
end