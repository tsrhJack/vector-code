classdef Subject < handle

	properties

        ID
        number
        last_name
        first_name
        Sessions = Session.empty
        affected_side

        flag = 0;
        reasonForFlag

	end

	methods

        function validateProperties(subject)
            if isempty(subject.ID)
                msg = 'ID is empty';
                warning(msg)
            end
            if isempty(subject.number)
                msg = 'number is empty';
                warning(msg)
            end
            if isempty(subject.last_name)
                msg = 'last name is empty';
                warning(msg)
            end
            if isempty(subject.first_name)
                msg = 'first name is empty';
                warning(msg)
            end
            if isempty(subject.affected_side)
                msg = 'affected side is empty';
                warning(msg)
            end
        end

	end

end