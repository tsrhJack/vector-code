    % I use these when programming. Not required for the program to run.
    MyPath = userpath;
    MyDir = MyPath(1:strfind(MyPath,';')-1);
    if exist(strcat(MyDir, '\Vector Coding\MyFunctions')) == 7
        addpath(strcat(MyDir, '\Vector Coding\MyFunctions'));
    end

    clc
    center = figure('visible', 'off');
    movegui(center,'center')
    close