classdef RoiElectrodeLabeler < handle
    %--------------------------------------------------------------------------
    % RoiElectrodeLabeler
    %
    % PURPOSE
    %   Standalone GUI for labeling electrodes with flexible ROI tags.
    %
    % KEY DESIGN
    %   - DOES NOT modify VERA Contact class
    %   - Stores labels externally via LabelMap
    %   - Multiple labels per contact supported
    %
    %--------------------------------------------------------------------------

    properties
        Surface
        Subjects

        LabelMap   % containers.Map: contactName -> string array

        % GUI
        Fig
        MainGrid
        Viewer

        ContactList
        LabelInput
        AddButton
        RemoveButton

        SelectedIndices
    end

    methods
        function obj = RoiElectrodeLabeler(surface, subjectDataMap)

            %------------------------------%
            % Build viewer FIRST
            %------------------------------%
            obj.Surface = surface;
            obj.Viewer  = Super3DView(obj.Surface, subjectDataMap);

            % Share reference (CRITICAL)
            obj.Subjects = obj.Viewer.Subjects;

            %------------------------------%
            % Init label storage
            %------------------------------%
            obj.LabelMap = containers.Map('KeyType','char','ValueType','any');

            obj.SelectedIndices = [];

            %------------------------------%
            % Build GUI
            %------------------------------%
            obj.Fig = figure('Name','ROI Electrode Labeler','Color','w');

            obj.MainGrid = uix.Grid('Parent',obj.Fig);
            obj.MainGrid.Widths  = [-3 -1];
            obj.MainGrid.Heights = [-1];

            % LEFT: Viewer
            viewerContainer = uicontainer('Parent',obj.MainGrid);
            set(obj.Viewer.Parent,'Parent',viewerContainer);

            % RIGHT: Controls
            controlPanel = uix.VBox('Parent',obj.MainGrid);

            obj.ContactList = uicontrol( ...
                'Parent',controlPanel,...
                'Style','listbox',...
                'Max',2,...
                'String',obj.getContactNames(),...
                'Callback',@(~,~)obj.onSelectionChanged());

            obj.LabelInput = uicontrol( ...
                'Parent',controlPanel,...
                'Style','edit',...
                'String','ROI');

            buttonBox = uix.HBox('Parent',controlPanel);

            obj.AddButton = uicontrol( ...
                'Parent',buttonBox,...
                'Style','pushbutton',...
                'String','Add Label',...
                'Callback',@(~,~)obj.addLabel());

            obj.RemoveButton = uicontrol( ...
                'Parent',buttonBox,...
                'Style','pushbutton',...
                'String','Remove Label',...
                'Callback',@(~,~)obj.removeLabel());

            buttonBox.Widths = [-1 -1];
            controlPanel.Heights = [-1 30 40];

            % Initial draw
            obj.updateColors();
            obj.Viewer.refreshView();
        end

        %% ----------------------------
        % Selection callback
        %------------------------------
        function onSelectionChanged(obj)
            obj.SelectedIndices = obj.ContactList.Value;
        end

        %% ----------------------------
        % Add label
        %------------------------------
        function addLabel(obj)

            if isempty(obj.SelectedIndices)
                return;
            end

            label = strtrim(string(obj.LabelInput.String));
            if label == ""
                return;
            end

            idx = 0;

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)

                    idx = idx + 1;

                    if any(obj.SelectedIndices == idx)

                        contact = obj.Subjects(s).Contacts(c);
                        key = char(contact.Name);

                        if ~isKey(obj.LabelMap, key)
                            obj.LabelMap(key) = string.empty;
                        end

                        labels = obj.LabelMap(key);

                        if ~any(labels == label)
                            labels(end+1) = label;
                            obj.LabelMap(key) = labels;
                        end
                    end
                end
            end

            obj.updateColors();
            obj.Viewer.refreshView();
        end

        %% ----------------------------
        % Remove label
        %------------------------------
        function removeLabel(obj)

            if isempty(obj.SelectedIndices)
                return;
            end

            label = strtrim(string(obj.LabelInput.String));
            if label == ""
                return;
            end

            idx = 0;

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)

                    idx = idx + 1;

                    if any(obj.SelectedIndices == idx)

                        contact = obj.Subjects(s).Contacts(c);
                        key = char(contact.Name);

                        if isKey(obj.LabelMap, key)
                            labels = obj.LabelMap(key);
                            labels = labels(labels ~= label);
                            obj.LabelMap(key) = labels;
                        end
                    end
                end
            end

            obj.updateColors();
            obj.Viewer.refreshView();
        end

        %% ----------------------------
        % Color update
        %------------------------------
        function updateColors(obj)

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)

                    contact = obj.Subjects(s).Contacts(c);
                    key = char(contact.Name);

                    if isKey(obj.LabelMap, key)
                        labels = obj.LabelMap(key);
                    else
                        labels = string.empty;
                    end

                    % --- Basic color rules ---
                    if any(labels == "ROI")
                        contact.Color = [1 0 0];         % red
                    elseif any(labels == "SOZ")
                        contact.Color = [1 0.5 0];       % orange
                    else
                        contact.Color = [0 0.7 1];       % blue
                    end
                end
            end
        end

        %% ----------------------------
        % Helper: names
        %------------------------------
        function names = getContactNames(obj)

            names = {};
            idx = 0;

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)

                    idx = idx + 1;

                    contact = obj.Subjects(s).Contacts(c);

                    if isprop(contact,'Electrode')
                        elec = contact.Electrode;
                    else
                        elec = "";
                    end

                    names{idx,1} = sprintf('%s (%s)', contact.Name, elec); %#ok<AGROW>
                end
            end
        end
    end
end