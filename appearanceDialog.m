function [regionCMap, subjects] = appearanceDialog(regionNames, regionCMap, subjects)
    % appearanceDialog - UI for editing region + electrode appearance
    % Updates regionCMap and subjects(:).Contacts(:).Color/Size

    persistent lastRegionSelection lastContactSelection

    f = uifigure('Name','Appearance Editor',...
        'Position',[200 200 500 500],...
        'CloseRequestFcn',@(~,~) uiresume(f));

    % OK button
    uibutton(f,'Text','OK',...
        'Position',[200 15 100 30],...
        'ButtonPushedFcn',@(~,~) uiresume(f));

    % Tab group
    tg = uitabgroup(f,'Position',[0 50 500 440]);
    tab1 = uitab(tg,'Title','Regions');
    tab2 = uitab(tg,'Title','Electrodes');

    % Regions tab
    lb = makeRegionTab(tab1, regionNames);

    % Electrodes tab
    makeContactTab(tab2);

    uiwait(f);
    lastRegionSelection = lb.Value;
    delete(f);

    % -------------------------------
    % Regions tab
    % -------------------------------
    function lb = makeRegionTab(parent, names)
        lb = uilistbox(parent,...
            'Items',names,...
            'Multiselect','on',...
            'Position',[10 60 180 330],...
            'ValueChangedFcn',@(~,~) setColorPatch());

        cp = uicolorpicker(parent,...
            'Position',[210 300 100 30],...
            'Value',[0 0 0],...
            'ValueChangedFcn',@(src,~) pickColor(src.Value));

        ax = uiaxes(parent,'Position',[330 280 80 80]);
        disableDefaultInteractivity(ax);
        axis(ax,'off');

        uibutton(parent,'Text','Select All',...
            'Position',[10 20 80 25],...
            'ButtonPushedFcn',@(~,~) selectAll());

        if ~isempty(lastRegionSelection)
            lb.Value = intersect(lastRegionSelection, lb.Items);
        end

        setColorPatch();

        function selectAll()
            lb.Value = lb.Items;
            setColorPatch();
        end
        function setColorPatch()
            if isempty(lb.Value), return; end
            [~, idx] = ismember(lb.Value, names);
            c = mean(regionCMap(idx,:),1);
            cp.Value = c;
            cla(ax); patch(ax,[0 1 1 0],[0 0 1 1],c); axis(ax,'off');
        end
        function pickColor(newColor)
            if isempty(lb.Value), return; end
            [~, idx] = ismember(lb.Value, names);
            regionCMap(idx,:) = repmat(newColor,numel(idx),1);
            setColorPatch();
        end
    end

    % -------------------------------
    % Electrodes tab
    % -------------------------------
    function makeContactTab(parent)
    
        tree = uitree(parent,'Position',[10 60 180 330],...
            'Multiselect','on',...
            'SelectionChangedFcn',@(src,~) setColorPatch(src));
    
        % Build tree: subject -> electrode -> contact
        for s = 1:numel(subjects)
            subj = subjects(s);
            sID = subj.ID;
            subjNode = uitreenode(tree,'Text',sID,'NodeData',...
                struct('type','subject','subj',sID));
            % Group contacts by electrode
            contacts = subj.Contacts;
            electrodes = unique({contacts.Electrode});
            for e = 1:numel(electrodes)
                elecName = electrodes{e};
                elecNode = uitreenode(subjNode,'Text',elecName,'NodeData',...
                    struct('type','electrode','subj',sID,'elec',elecName));
    
                % Add contacts under this electrode
                for c = 1:numel(contacts)
                    ct = contacts(c);
                    if strcmp(ct.Electrode, elecName)
                        nd = struct('type','contact','subj',sID,'idx',c);
                        cNode = uitreenode(elecNode,'Text',ct.Name,'NodeData',...
                            nd);
                        if ~isempty(lastContactSelection) && ...
                                any(cellfun(@(x) isequal(x, nd), lastContactSelection))
                            % add contact node
                            tree.SelectedNodes = [cNode; tree.SelectedNodes];
                            % add electrode node
                            if ~ismember(elecNode,tree.SelectedNodes)
                                tree.SelectedNodes = [elecNode;...
                                    tree.SelectedNodes];
                            end
                            % add subject node
                            if ~ismember(subjNode,tree.SelectedNodes)
                                tree.SelectedNodes = [subjNode;...
                                    tree.SelectedNodes];
                            end
                        end
                    end
                end
            end
        end
    
        % Color picker and size field
        cp = uicolorpicker(parent,'Position',[210 300 100 30],...
            'Value',[1 1 1],'ValueChangedFcn',@(src,~) pickColor(src.Value));
    
        uilabel(parent,'Text','Size:','Position',[210 250 40 22]);
        sizeField = uieditfield(parent,'numeric','Position',[260 250 80 22],...
            'ValueChangedFcn',@(src,~) setSize(src.Value));
    
        ax = uiaxes(parent,'Position',[330 280 80 80]);
        disableDefaultInteractivity(ax); axis(ax,'off');
    
        uibutton(parent,'Text','Select All','Position',[10 20 80 25],...
            'ButtonPushedFcn',@(~,~) selectAll());
    
        setColorPatch(tree);
    
        %% --- Nested functions ---
        function selectAll()
            tree.SelectedNodes = findall(tree,'Type','uitreenode');
            setColorPatch(tree);
        end
    
        function [contacts,nodes] = getAllContacts(node)
            % Recursively collect all contact nodes under a node
            nodes = [];
            contacts = [];
            if isprop(node,'NodeData')
                nd = node.NodeData;
                if strcmp(nd.type,'contact')
                    nodes = node;
                    sIdx = strcmp(nd.subj,{subjects.ID});
                    cIdx = nd.idx;
                    subj = subjects(sIdx);
                    contacts = subj.Contacts(cIdx);
                else
                    for ch = node.Children'
                        [sub_c, sub_n] = getAllContacts(ch);
                        nodes = [nodes; ch; sub_n];
                        contacts = [contacts; sub_c];
                    end
                end
            end
        end
    
        function setColorPatch(srcTree)
            nodes = srcTree.SelectedNodes;
            if isempty(nodes), return; end
    
            contacts = [];
            for n = nodes'
                [sub_c,sub_n] = getAllContacts(n);
                contacts = [contacts; sub_c];
                nodes = [nodes; sub_n];
            end
            srcTree.SelectedNodes = nodes;
            if ~isempty(contacts)
                colors = vertcat(contacts.Color);
                sizes = [contacts.Size];
                cp.Value = mean(colors,1);
                sizeField.Value = mean(sizes);
                cla(ax); patch(ax,[0 1 1 0],[0 0 1 1],mean(colors,1)); axis(ax,'off');
                nd = {nodes.NodeData};
                types = cellfun(@(x) x.type,nd,'UniformOutput',false);
                lastContactSelection = {nd{strcmp(types,'contact')}};
            end
        end
    
        function setSize(newSize)
            nodes = tree.SelectedNodes;
            for nd = nodes'
                if strcmp(nd.NodeData.type,'contact')
                    ct = getContact(nd);
                    ct.Size = newSize;
                    setContact(ct);
                end
            end
            setColorPatch(tree);
        end
    
        function pickColor(newColor)
            nodes = tree.SelectedNodes;
            for n = nodes'
                [~,nodes] = getAllContacts(n);
                for nd = nodes'
                    if strcmp(nd.NodeData.type,'contact')
                        ct = getContact(nd);
                        ct.Color = newColor;
                        setContact(ct);
                    end
                end
            end
            setColorPatch(tree);
        end
        function ct = getContact(nd)
            d = nd.NodeData;
            % this is a bad way to do this, but passing by 
            % reference in MATLAB is complicated.
            sIdx = strcmp({subjects.ID},d.subj);
            subj = subjects(sIdx);
            ct = subj.Contacts(d.idx);
        end
        function setContact(ct)
            sIdx = strcmp({subjects.ID},ct.Subject);
            subj = subjects(sIdx);
            cIdx = strcmp({subj.Contacts.Name},ct.Name);
            subj.Contacts(cIdx) = ct;
            subjects(sIdx) = subj;
        end
    end

end
