function saveFigure(session, mainFigure, figureName)
    global subjectFolderSave;
    global customsave;
    global customSavePath;
    if subjectFolderSave
        %saveas(mainFigure, fullfile(session.Folder,figureName), 'jpg')
        fprintf('Saved %s.jpg in patient folder\n', figureName)
    end
    if customsave
        %saveas(mainFigure, fullfile(customSavePath,figureName), 'jpg')
        fprintf('Saved %s.jpg in custom folder\n', figureName)
    end
end