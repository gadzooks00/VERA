function [regionCMap,contactCMap,contactSizeMap] = appearanceDialog(regionNames,regionCMap,electrodeInfo,definitionInfo,contactCMap,contactSizeMap)
    persistent lastRegionSelection lastContactSelection

    f = uifigure('Name','Color Picker',...
        'Position',[200 200 450 500],...
        'CloseRequestFcn',@onClose);

    % OK button at the bottom
    uibutton(f,'Text','OK',...
        'Position',[180 15 90 30],...
        'ButtonPushedFcn',@(~,~) uiresume(f));

    % Tab group
    tg = uitabgroup(f,'Position',[0 50 450 440]);
    tab1 = uitab(tg,'Title','Regions');
    tab2 = uitab(tg,'Title','Electrodes');

    % Regions tab
    lb=makeRegionTab(tab1, regionNames, regionCMap);

    % Electrodes tab
    makeContactTab(tab2, electrodeInfo, definitionInfo);

    uiwait(f);
    lastRegionSelection = lb.Value;
    delete(f);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Regions tab
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function lb=makeRegionTab(parent, names, cmap)
    
        % Listbox for multiple items
        lb = uilistbox(parent,...
            'Items',names,...
            'Multiselect','on',...   % <-- allow multiple
            'Position',[10 60 180 330], ...
             'ValueChangedFcn',@(src,evt) setColorPatch());

        % Button to pick color
        cp = uicolorpicker(parent,...
            'Position',[210 300 100 30],...
            'Value', [0 0 0], ... % initial color, can set based on first item
            'ValueChangedFcn',@(src,evt) pickColor(src.Value));

        % Axes to show current color (use first selection as preview)
        ax = uiaxes(parent,'Position',[330 280 80 80]);
        disableDefaultInteractivity(ax); axis(ax,'off');
        axis(ax,'off');
        setColorPatch();

        uibutton(parent,'Text','Select All',...
        'Position',[10 20 80 25],...
        'ButtonPushedFcn',@(btn,evt) selectAll());

        if ~isempty(lastRegionSelection)
            lb.Value = intersect(lastRegionSelection, lb.Items); 
        end

        function selectAll()
            % Select all items in the listbox
            lb.Value = lb.Items;
            setColorPatch();
        end
        function setColorPatch()
            if ~isempty(lb.Items)
                idx = lb.Value; % Value returns string of selected item
                % Find index in names
                [~, itemIdx] = ismember(idx, names);
                c = cmap(itemIdx,:);
                c = mean(c,1);
                cp.Value = c; % update color picker
                cla(ax);
                patch(ax,[0 1 1 0],[0 0 1 1],c);
                axis(ax,'off');
            end
        end

        function pickColor(newColor)
            if isempty(lb.Value), return; end
            if length(newColor)==3
                for k = 1:numel(lb.Value)
                    itemIdx = find(strcmp(names,lb.Value{k}));
                    cmap(itemIdx,:) = newColor;
                    regionCMap(itemIdx,:) = newColor;
                end
                cla(ax);
                patch(ax,[0 1 1 0],[0 0 1 1],newColor);
                axis(ax,'off');
            end
        end

    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Contact tab
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function makeContactTab(parent, electrodeInfo, definitionInfo)

        n = numel(electrodeInfo.Name);

        % Build UITree
        tree = uitree(parent,'Position',[10 60 180 330],...
            'Multiselect','on',...
            'SelectionChangedFcn',@(src,evt) setColorPatch());
        

        % Create nodes for each definition
        defNodes = gobjects(numel(definitionInfo.Definition),1);
        for d = 1:numel(definitionInfo.Definition)
            defNodes(d) = uitreenode(tree,'Text',definitionInfo.Definition(d).Name,...
                                     'NodeData',struct('isDefinition',true,'index',d));
        end

        % Create child nodes for contacts
        for i = 1:n
            defIdx = electrodeInfo.DefinitionIdentifier(i);
            parentNode = defNodes(defIdx);
            uitreenode(parentNode,'Text',electrodeInfo.Name{i},...
                       'NodeData',struct('isDefinition',false,'index',i));
        end

        cp = uicolorpicker(parent,...
            'Position',[210 300 100 30],...
            'Value',[1 1 1],... % or use mean color of selected nodes
            'ValueChangedFcn',@(src,evt) pickColor(src.Value));

        % Numeric field for size
        uilabel(parent,'Text','Size:',...
            'Position',[210 250 40 22]);
        sizeField = uieditfield(parent,'numeric',...
            'Position',[260 250 80 22],...
            'ValueChangedFcn',@setSize);

        % Axes to show current color
        ax = uiaxes(parent,'Position',[330 280 80 80]);
        disableDefaultInteractivity(ax);
        axis(ax,'off');
        setColorPatch();

        if ~isempty(lastContactSelection)
            % Match by Text
            allNodes = findall(tree,'Type','uitreenode');
            matchNodes = allNodes(ismember({allNodes.Text}, lastContactSelection));
            tree.SelectedNodes = matchNodes;
        end

        uibutton(parent,'Text','Select All',...
            'Position',[10 20 80 25],...
            'ButtonPushedFcn',@(btn,evt) selectAll());
        
        function selectAll()
            % find all nodes except the root "allNode"
            allContacts = findall(tree,'Type','uitreenode');
            tree.SelectedNodes = allContacts;         % select them all
            setColorPatch();                          % update color patch
        end
        function setColorPatch()
            nodes = tree.SelectedNodes;
            if isempty(nodes), return; end
            nd = nodes(1).NodeData; % just take first
            if ~nd.isDefinition
                idx = nd.index;
                c = contactCMap(idx,:);
                sz = contactSizeMap(idx);
            else
                contacts = find(electrodeInfo.DefinitionIdentifier == nd.index);
                if ~isempty(contacts)
                    c = mean(contactCMap(contacts,:),1);
                    sz = mean(contactSizeMap(contacts));
                else
                    c = [1 1 1];
                    sz = 2;
                end
            end
            cp.Value = c; % update color picker
            sizeField.Value = sz; % update size item
            cla(ax);
            patch(ax,[0 1 1 0],[0 0 1 1],c);
            axis(ax,'off');
            lastContactSelection = arrayfun(@(n) n.Text, tree.SelectedNodes, 'UniformOutput', false);
        end
        function setSize(src,~)
            nodes = tree.SelectedNodes;
            if isempty(nodes), return; end
            newSize = src.Value;
            for k = 1:numel(nodes)
                ndk = nodes(k).NodeData;
                if ~ndk.isDefinition
                    contactSizeMap(ndk.index) = newSize;
                else
                    contacts = find(electrodeInfo.DefinitionIdentifier == ndk.index);
                    contactSizeMap(contacts) = newSize;
                end
            end
        end
        function pickColor(newColor)
            nodes = tree.SelectedNodes;
            if isempty(nodes), return; end
            if length(newColor)==3
                for k = 1:numel(nodes)
                    ndk = nodes(k).NodeData;
                    if ndk.isDefinition
                        contacts = find(electrodeInfo.DefinitionIdentifier == ndk.index);
                        contactCMap(contacts,:) = repmat(newColor,numel(contacts),1);
                    else
                        contactCMap(ndk.index,:) = newColor;
                    end
                end
                setColorPatch();
            end
        end

    end

    function onClose(~,~)
        uiresume(f);
    end
end
