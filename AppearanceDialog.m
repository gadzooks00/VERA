classdef AppearanceDialog < handle
    % AppearanceDialog - persistent UI for editing region + electrode appearance
    %
    % Usage:
    %   dlg = AppearanceDialog(regionNames, regionCMap, subjects);
    %   [regionCMap, subjects] = dlg.getData();

    properties
        regionNames
        regionCMap
        subjects % now array of Subject handles
        fig
    end

    properties (Access = private)
        tabgroup
        regionList
        regionColorPicker
        regionPatch
        contactTree
        contactColorPicker
        contactSizeField
        contactPatch
        lastRegionSelection
        lastElecSelection
    end

    methods
        % ==============================================================
        % Constructor
        % ==============================================================
        function obj = AppearanceDialog(regionNames, regionCMap, subjects)
            obj.regionNames = regionNames;
            obj.regionCMap  = regionCMap;
            obj.subjects    = subjects; % handle objects, edits are live
            obj.buildUI();
        end

        function show(obj)
            obj.fig.Visible = 'on';
            uistack(obj.fig, 'top');
            figure(obj.fig);
        end

        function hide(obj)
            obj.fig.Visible = 'off';
            obj.lastRegionSelection = obj.regionList.Value;
            nd = obj.contactTree.SelectedNodes;
            if isempty(nd), return; end
            obj.lastElecSelection = {nd.NodeData};
        end

        function [regionCMap, subjects] = getData(obj)
            regionCMap = obj.regionCMap;
            subjects = obj.subjects; % handle objects; external edits preserved
        end
    end

    methods (Access = private)
        function buildUI(obj)
            % Main figure
            obj.fig = uifigure('Name','Appearance Editor', ...
                'Position',[200 200 500 500], ...
                'Visible','off', ...
                'CloseRequestFcn', @(~,~) obj.closeDialog());

            % OK button
            uibutton(obj.fig,'Text','OK', ...
                'Position',[200 15 100 30], ...
                'ButtonPushedFcn', @(~,~) obj.closeDialog());

            % Tabs
            obj.tabgroup = uitabgroup(obj.fig, 'Position',[0 50 500 440]);
            tab1 = uitab(obj.tabgroup, 'Title','Regions');
            tab2 = uitab(obj.tabgroup, 'Title','Electrodes');

            obj.buildRegionTab(tab1);
            obj.buildContactTab(tab2);
        end

        function closeDialog(obj)
            obj.hide()
            uiresume(obj.fig)
        end

        %% =========================
        %% Regions Tab
        %% =========================
        function buildRegionTab(obj, parent)
            obj.regionList = uilistbox(parent,'Items',obj.regionNames,'Multiselect','on', ...
                'Position',[10 60 180 330], 'ValueChangedFcn',@(~,~) obj.updateRegionPatch());

            obj.regionColorPicker = uicolorpicker(parent, ...
                'Position',[210 300 100 30], ...
                'Value',[0 0 0], ...
                'ValueChangedFcn',@(src,~) obj.pickRegionColor(src.Value));

            ax = uiaxes(parent,'Position',[330 280 80 80]); 
            disableDefaultInteractivity(ax); axis(ax,'off');
            obj.regionPatch = patch(ax,[0 1 1 0],[0 0 1 1],[0 0 0]);

            uibutton(parent,'Text','Select All','Position',[10 20 80 25], ...
                'ButtonPushedFcn',@(~,~) obj.selectAllRegions());

            if ~isempty(obj.lastRegionSelection)
                obj.regionList.Value = intersect(obj.lastRegionSelection, obj.regionList.Items);
            end
            obj.updateRegionPatch();
        end

        function selectAllRegions(obj)
            obj.regionList.Value = obj.regionList.Items;
            obj.updateRegionPatch();
        end

        function updateRegionPatch(obj)
            lb = obj.regionList;
            if isempty(lb.Value), return; end
            [~, idx] = ismember(lb.Value, obj.regionNames);
            c = mean(obj.regionCMap(idx,:),1);
            obj.regionColorPicker.Value = c;
            obj.regionPatch.FaceColor = c;
        end

        function pickRegionColor(obj, newColor)
            lb = obj.regionList;
            if isempty(lb.Value), return; end
            [~, idx] = ismember(lb.Value, obj.regionNames);
            obj.regionCMap(idx,:) = repmat(newColor,[numel(idx),1]);
            obj.regionPatch.FaceColor = newColor;
        end

        %% =========================
        %% Electrodes Tab
        %% =========================
        function buildContactTab(obj, parent)
            obj.contactTree = uitree(parent,'Position',[10 60 180 330],'Multiselect','on', ...
                'SelectionChangedFcn',@(src,evt) obj.updateContactPatch(src,evt));
        
            % Build tree from handle objects
            for s = 1:numel(obj.subjects)
                subjNode = uitreenode(obj.contactTree,'Text',obj.subjects(s).ID, ...
                    'NodeData',obj.subjects(s));
                contacts = obj.subjects(s).Contacts;
                [elecNames,~,elecIdx] = unique({contacts.Electrode},'stable');
                for e = 1:numel(elecNames)
                    elecNode = uitreenode(subjNode,'Text',elecNames{e});
                    cIdx = find(elecIdx==e);
                    for ci = cIdx(:)' % ensure row vector for loop
                        uitreenode(elecNode,'Text',contacts(ci).Name,'NodeData',contacts(ci));
                    end
                end
            end
        
            % UI Controls
            obj.contactColorPicker = uicolorpicker(parent,'Position',[210 300 100 30],'Value',[1 1 1], ...
                'ValueChangedFcn',@(src,~) obj.pickContactColor(src.Value));
            uilabel(parent,'Text','Size:','Position',[210 250 40 22]);
            obj.contactSizeField = uieditfield(parent,'numeric','Position',[260 250 80 22], ...
                'ValueChangedFcn',@(src,~) obj.setContactSize(src.Value));
        
            ax = uiaxes(parent,'Position',[330 280 80 80]); 
            disableDefaultInteractivity(ax); axis(ax,'off');
            obj.contactPatch = patch(ax,[0 1 1 0],[0 0 1 1],[1 1 1]);
        
            uibutton(parent,'Text','Select All','Position',[10 20 80 25], ...
                'ButtonPushedFcn',@(~,~) obj.selectAllContacts());
        
            % Restore previous selection
            obj.restoreSelection();
        
            % Initial update
            obj.updateContactPatch(obj.contactTree);
        end
        
        function updateContactPatch(obj, srcTree, ~)
            % Get the user-selected nodes
            nodes = srcTree.SelectedNodes;
            if isempty(nodes), return; end
        
            % --- Propagate selection to all child nodes ---
            allSelected = nodes;  % start with top-level selection
            for n = nodes'
                % find only the direct descendants of this node
                childNodes = n.Children;  % returns TreeNode array
                allSelected = [allSelected; childNodes(:)]; %#ok<AGROW>
        
                % Optional: recursively add deeper children
                for cn = childNodes(:)'
                    allSelected = [allSelected; cn.Children(:)]; %#ok<AGROW>
                end
            end
        
            % Remove duplicates
            allSelected = unique(allSelected);
        
            % Assign back to tree
            srcTree.SelectedNodes = allSelected;
        
            % --- Collect Contact objects for UI patch ---
            contacts = Contact.empty;
            for n = allSelected'
                nd = n.NodeData;
                if isa(nd,'Contact')
                    contacts(end+1) = nd; %#ok<AGROW>
                end
            end
        
            if isempty(contacts), return; end
        
            colors = vertcat(contacts.Color);
            sizes  = [contacts.Size];
            obj.contactColorPicker.Value = mean(colors,1);
            obj.contactSizeField.Value = mean(sizes);
            obj.contactPatch.FaceColor = mean(colors,1);
        
            % Save selection for later restoration
            obj.lastElecSelection = {srcTree.SelectedNodes.NodeData};
        end
        
        function restoreSelection(obj)
            if isempty(obj.lastElecSelection), return; end
        
            restored = gobjects(0,1);
            for nd = obj.lastElecSelection
                nd = nd{:};
                match = findall(obj.contactTree,'Type','uitreenode', ...
                    '-function',@(n) isequal(n.NodeData,nd));
                if ~isempty(match)
                    % include all child nodes
                    restored = [restored; match; findall(match,'Type','uitreenode')]; %#ok<AGROW>
                end
            end
            if ~isempty(restored)
                obj.contactTree.SelectedNodes = unique(restored);
            end
        end

        function selectAllContacts(obj)
            obj.contactTree.SelectedNodes = findall(obj.contactTree,'Type','uitreenode');
            obj.updateContactPatch(obj.contactTree);
        end

        function setContactSize(obj, newSize)
            nodes = obj.contactTree.SelectedNodes;
            for n = nodes'
                if isa(n.NodeData,'Contact')
                    n.NodeData.Size = newSize;
                end
            end
            obj.updateContactPatch(obj.contactTree);
        end

        function pickContactColor(obj, newColor)
            nodes = obj.contactTree.SelectedNodes;
            for n = nodes'
                if isa(n.NodeData,'Contact')
                    n.NodeData.Color = newColor;
                end
            end
            obj.updateContactPatch(obj.contactTree);
        end
    end
end
