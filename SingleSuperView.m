classdef SingleSuperView < Abstract3DView
    % SuperModel3DView - Concrete VERA viewer
    % Inherits plotting/filtering from Abstract3DView
    properties
    end
    
    methods
        function obj = SingleSuperView(surface,subject,varargin)
            obj@Abstract3DView(surface,varargin{:});
            obj.ElectrodePositions = subject.ElectrodePositions;
            obj.ElectrodeDefinitions = subject.ElectrodeDefinitions;

            obj.updateView();
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
                    nameLabels{end+1} = sprintf('Channel %d', i);
                end
            end
            indexLabels = arrayfun(@(i) sprintf('%d',i), 1:numel(elPos.DefinitionIdentifier), 'UniformOutput', false);

            % Modal dialog
            d = uifigure('Name','Channel Selection');

            % Mode selection
            bg = uibuttongroup('Parent',d,'Units','normalized','Position',[0.05 0.85 0.9 0.1]);
            r1 = uicontrol(bg,'Style','radiobutton','String','By Name','Units','normalized','Position',[0.05 0.1 0.4 0.8]);
            r2 = uicontrol(bg,'Style','radiobutton','String','By Index','Units','normalized','Position',[0.55 0.1 0.4 0.8]);
            bg.SelectedObject = r1;

            % Tree panel
            treePanel = uigridlayout(d,[1 1]);
            tree = uitree(treePanel, 'checkbox');

            % Group electrodes by base name
            tokens = regexp(nameLabels,'^([A-Za-z]+)','tokens','once');
            baseNames = cellfun(@(t) t{1}, tokens, 'UniformOutput', false);
            uniqueBases = unique(baseNames,'stable');
            for b = 1:numel(uniqueBases)
                parentNode = uitreenode(tree,'Text',uniqueBases{b});
                groupIdx = strcmp(baseNames, uniqueBases{b});
                for i = find(groupIdx)
                    uitreenode(parentNode,'Text',nameLabels{i});
                end
            end

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
                    nodes = tree.CheckedNodes;
                    names = {};
                    for ch = 1:numel(nodes)
                        node = nodes(ch);
                        names{end + 1} = node.Text;
                    end
                    obj.setElectrodeFilter('ByName',names);
                end
                delete(d);
            end
        end
        
        function cancelCallback(~,d)
            setappdata(d, 'Cancelled', true);
            uiresume(d);
        end
    end
end

