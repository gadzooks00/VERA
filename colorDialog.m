function [regionCMap,electrodeCMap] = colorDialog(regionNames,regionCMap,electrodeNames,electrodeCMap)

    f = figure('Name','Color Picker','MenuBar','none','ToolBar','none',...
        'NumberTitle','off','Position',[200 200 400 500],...
        'CloseRequestFcn',@onClose);

    % OK button at the bottom
    uicontrol(f,'Style','pushbutton','String','OK',...
        'Units','normalized','Position',[0.4 0.02 0.2 0.06],...
        'Callback',@(~,~) uiresume(f));

    % Tab group
    tg = uitabgroup(f,'Units','normalized','Position',[0 0.1 1 0.88]);
    tab1 = uitab(tg,'Title','Regions');
    tab2 = uitab(tg,'Title','Electrodes');

    makeColorTab(tab1, regionNames, regionCMap, 'Regions');
    makeColorTab(tab2, electrodeNames, electrodeCMap, 'Electrodes');

    uiwait(f);
    delete(f);

    function makeColorTab(parent, names, cmap, field)
        n = numel(names);

        % Listbox for all items
        lb = uicontrol(parent,'Style','listbox',...
            'Units','normalized',...
            'Position',[0 0.1 0.5 0.9],...
            'String',names,'Value',1,'Max',1,'Min',1);

        % Button to pick color
        btn = uicontrol(parent,'Style','pushbutton','String','Pick Color',...
            'Position',[200 200 100 30],'Callback',@pickColor);

        % Small axes to show current color
        ax = axes('Parent',parent,'Units','pixels','Position',[320 200 40 40]);
        patch([0 1 1 0],[0 0 1 1],[1 1 1]); % dummy
        axis off
        setColorPatch();

        % Update color patch when selection changes
        lb.Callback = @(src,~) setColorPatch();

        function setColorPatch()
            if ~isempty(lb.String)
                idx = lb.Value;
                c = cmap(idx,:);
                cla(ax);
                patch([0 1 1 0],[0 0 1 1],c,'Parent',ax);
                axis(ax,'off');
            end
        end

        function pickColor(~,~)
            idx = lb.Value;
            newColor = uisetcolor(cmap(idx,:),'Pick a color');
            if length(newColor)==3
                cmap(idx,:) = newColor;
                setColorPatch();
                if field=="Regions"
                    regionCMap(idx,:) = newColor;
                else
                    electrodeCMap(idx,:) = newColor;
                end
            end
        end
    end

    function onClose(~,~)
        uiresume(f);
    end
end
