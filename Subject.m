classdef Subject < handle
    % Subject - holds an ID and a list of Contacts
    properties
        ID
        Contacts % array of Contact objects
    end
    methods
        function obj = Subject(ID, contacts)
            if nargin > 0
                obj.ID = ID;
                obj.Contacts = contacts;
            end
        end
    end
end