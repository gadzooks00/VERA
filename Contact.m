classdef Contact < handle
    % Contact - single electrode/contact
    properties
        Subject       % Subject ID
        Name          % Unique contact name
        Electrode     % Electrode type
        Location      % [x,y,z]
        Color         % RGB
        Size          % numeric
        Visible       % logical
        Handle        % graphics handle
        LabelHandle   % graphics handle
        ArrowHandle   % graphics handle
    end
    methods
        function obj = Contact(sID, name, electrode, loc)
            if nargin > 0
                obj.Subject = sID;
                obj.Name = name;
                obj.Electrode = electrode;
                obj.Location = loc;
                obj.Color = [1 1 1];
                obj.Size = 2;
                obj.Visible = true;
                obj.Handle = [];
                obj.LabelHandle = [];
                obj.ArrowHandle = [];
            end
        end
    end
end
