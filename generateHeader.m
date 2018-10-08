function header = generateHeader(subject, session, trial, side)
        header{1} = strcat(session.Folder,trial.fileName);
        header{2} = subject.ID;
        header{3} = subject.number;
        header{4} = subject.last_name;
        header{5} = subject.first_name;
        header{6} = trial.trial_type;
        header{7} = session.name;
        header{8} = side;
        header{9} = trial.cycle_info;
        header{10} = subject.affected_side;
end