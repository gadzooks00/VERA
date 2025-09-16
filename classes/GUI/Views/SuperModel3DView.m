classdef SuperModel3DView < AView & Abstract3DView
    % SuperModel3DView - Concrete VERA viewer
    % Inherits plotting/filtering from Abstract3DView
    properties
        SurfaceIdentifier = 'Surface';
        ElectrodeLocationIdentifier = 'ElectrodeLocation';
        ElectrodeDefinitionIdentifier = 'ElectrodeDefinition';
    end
    
    methods
        function obj = SuperModel3DView(varargin)
            obj@Abstract3DView(varargin{:});
        end
        
        function loadDataFromAvailableData(obj)
            % Populate abstract class properties from AvailableData
            if isprop(obj,'AvailableData') && ~isempty(obj.AvailableData)
                if obj.AvailableData.isKey(obj.SurfaceIdentifier)
                    obj.Surface = obj.AvailableData(obj.SurfaceIdentifier);
                end
                if obj.AvailableData.isKey(obj.ElectrodeLocationIdentifier)
                    obj.ElectrodePositions = obj.AvailableData(obj.ElectrodeLocationIdentifier);
                end
                if obj.AvailableData.isKey(obj.ElectrodeDefinitionIdentifier)
                    obj.ElectrodeDefinitions = obj.AvailableData(obj.ElectrodeDefinitionIdentifier);
                end
            end
        end
        function electrodeFilterCallback(obj)
            % Builds electrode selection UI
            if isempty(obj.ElectrodePositions)
                warndlg('No electrode locations available.');
                return;
            end
            
            elPos = obj.ElectrodePositions;
            elDef = obj.ElectrodeDefinitions;
            
            % Build names and indices
            nameLabels = {};
            for i = 1:numel(elPos.DefinitionIdentifier)
                defIdx = elPos.DefinitionIdentifier(i);
                if ~isempty(elDef) && defIdx > 0 && defIdx <= numel(elDef.Definition)
                    nameLabels{end+1} = obj.buildChannelName(elPos,elDef,defIdx,i); %#ok<AGROW>
                else
                    nameLabels{end+1} = sprintf('Channel %d', i); %#ok<AGROW>
                end
            end
            indexLabels = arrayfun(@(i) sprintf('%d',i), 1:numel(elPos.DefinitionIdentifier), 'UniformOutput', false);

            % Modal dialog
            d = dialog('Name','Select Electrodes','WindowStyle','modal','Resize','on','Position',[200 200 300 400]);

            % Mode selection
            bg = uibuttongroup('Parent',d,'Units','normalized','Position',[0.05 0.85 0.9 0.1]);
            r1 = uicontrol(bg,'Style','radiobutton','String','By Name','Units','normalized','Position',[0.05 0.1 0.4 0.8]);
            r2 = uicontrol(bg,'Style','radiobutton','String','By Index','Units','normalized','Position',[0.55 0.1 0.4 0.8]);
            bg.SelectedObject = r1;

            % Tree panel
            treePanel = uipanel('Parent',d,'Units','normalized','Position',[0.05 0.2 0.9 0.65]);
            [tree, container] = uitree('v0', 'Root', uitreenode('v0','root','Electrodes',[],false), 'Parent', d, 'Position', [20 80 260 250]);
            root = tree.getRoot;

            % Group electrodes by base name
            tokens = regexp(nameLabels,'^([A-Za-z]+)','tokens','once');
            baseNames = cellfun(@(t) t{1}, tokens, 'UniformOutput', false);
            uniqueBases = unique(baseNames,'stable');
            for b = 1:numel(uniqueBases)
                parentNode = uitreenode('v0', uniqueBases{b}, uniqueBases{b}, [], false);
                groupIdx = strcmp(baseNames, uniqueBases{b});
                for i = find(groupIdx)
                    child = uitreenode('v0', num2str(i), nameLabels{i}, [], true);
                    child.setUserObject(i);
                    parentNode.add(child);
                end
                root.add(parentNode);
            end
            tree.reloadNode(root);

            % OK / Cancel buttons
            uicontrol('Parent',d,'Style','pushbutton','String','OK','Units','normalized','Position',[0.55 0.05 0.4 0.1], ...
                'Callback',@(src,evt)uiresume(d));
            uicontrol('Parent', d, 'Style', 'pushbutton', 'String', 'Cancel', ...
                'Units', 'normalized', 'Position', [0.05 0.05 0.4 0.1], ...
                'Callback', @(src,evt)obj.cancelCallback(d));

            uiwait(d);

            % Apply filter
            if isvalid(d)
                cancelled = isappdata(d,'Cancelled');
                if ~cancelled
                    selectedNodes = tree.SelectedNodes;
                    selectedIdx = [selectedNodes.NodeData];
                    if bg.SelectedObject == r1
                        selectedLabels = nameLabels(selectedIdx);
                        obj.setElectrodeFilter('ByName',selectedLabels);
                    else
                        selectedIndices = cellfun(@str2double,indexLabels(selectedIdx));
                        obj.setElectrodeFilter('ByIndex',selectedIndices);
                    end
                end
                delete(d);
            end
        end
        
        function cancelCallback(~,d)
            setappdata(d, 'Cancelled', true);
            uiresume(d);
        end
    end
    methods (Access = protected)
        function dataUpdate(obj)
            if isempty(obj.Surface) % available data is loaded in after
                                    % constructor so check here
                obj.loadDataFromAvailableData();
            end
            obj.updateView();
        end
    end
end

