classdef Super3DView < uix.Grid
    % Super3DView - 3D visualization of brain surfaces + electrodes
    % Supports single- or multi-subject data.
    
    properties
        % Data to be plotted
        Surface
        ElectrodePositions
        ElectrodeDefinitions
        ChannelHandles
        ElectrodeFilter = struct()
    end
    
    properties (Access = protected)
        % GUI handles
        axModel
        vSurf
        electrodeLabelDropdown
        filterDialog
        viewModeDropdown
        cSlider
        filterButton
        brain_cmap
        contact_cmap
        contact_sizemap
        appearanceButton
    end
    
    properties (Access = private)
        % Multi-subject support
        SubjectIDs
        SubjectDataMap
        singleMode
    end
    
    methods
        function obj = Super3DView(surface, subjectDataMap, varargin)
            % Constructor: works for single or multiple subjects
            
            % === Figure & layout ===
            f = figure('Color','k','Name','Viewer');
            set(obj, 'Parent', f);
            set(obj, 'Units', 'normalized', 'Position', [0 0 1 1]);
            set(f, 'Color', [1 1 1]);
            
            tmp_Grid = uix.Grid('Parent', obj);
            obj.axModel = axes('Parent', uicontainer('Parent', tmp_Grid), ...
                'Units','normalized','Color','k','ActivePositionProperty','Position');
            set(tmp_Grid,'BackgroundColor','k');
            set(obj,'BackgroundColor','k');
            
            % === Controls ===
            controlHBox = uix.HBox('Parent', obj);
            
            % electrode label dropdown
            labelGrid = uix.Grid('Parent', controlHBox);
            uicontrol('Parent', labelGrid, 'Style', 'text', 'String', 'Label electrodes by:');
            obj.electrodeLabelDropdown = uicontrol('Parent', labelGrid, 'Style', 'popupmenu', ...
                'String', {'Name','Number','None'}, 'Value', 1, ...
                'Callback', @obj.electrodeLabelCallback);
            labelGrid.Widths  = [120, -1];
            labelGrid.Heights = [20];
            
            % view mode + slider
            leftBox = uix.VBox('Parent', controlHBox);
            viewGrid = uix.Grid('Parent', leftBox);
            uicontrol('Parent', viewGrid, 'Style', 'text', 'String', 'View mode:');
            obj.viewModeDropdown = uicontrol('Parent', viewGrid, 'Style', 'popupmenu', ...
                'String', {'Original','Projected','Projected + Arrows'}, 'Value', 1, ...
                'Callback', @obj.viewModeCallback);
            viewGrid.Widths  = [80, -1];
            viewGrid.Heights = [20];
            
            sliderGrid = uix.Grid('Parent', leftBox);
            uicontrol('Parent', sliderGrid, 'Style', 'text', 'String', 'Opacity');
            obj.cSlider = uicontrol('Parent', sliderGrid, 'Style', 'slider', ...
                'Min',0, 'Max',1, 'Value',1);
            sliderGrid.Widths  = [60, -1];
            sliderGrid.Heights = [15];
            addlistener(obj.cSlider, 'Value', 'PostSet', @obj.changeAlpha);
            
            % filter + appearance buttons
            buttonGrid = uix.Grid('Parent', controlHBox);
            obj.filterButton = uicontrol('Parent', buttonGrid, 'Style','pushbutton', ...
                'String', 'Filter Electrodes', ...
                'Callback', @(~,~)obj.electrodeFilterCallback());
            obj.appearanceButton = uicontrol('Parent', buttonGrid, 'Style','pushbutton', ...
                'String', 'Coloring', ...
                'Callback', @(~,~)obj.appearCallback());
            buttonGrid.Heights = [30];
            buttonGrid.Widths = [-1];
            
            obj.Widths  = [-1];
            obj.Heights = [-1, 60];
            
            % === Data setup ===
            obj.Surface = surface;
            obj.contact_cmap = [];
            obj.contact_sizemap = [];
            obj.brain_cmap = [];
            
            if nargin > 1 && isa(subjectDataMap,'containers.Map')
                obj.SubjectIDs = subjectDataMap.keys;
                obj.SubjectDataMap = subjectDataMap;
                obj.combineSubjectData(subjectDataMap);
            else
                obj.SubjectIDs = {};
                obj.SubjectDataMap = containers.Map;
            end

            obj.filterDialog =  ElectrodeFilterDialog(obj.SubjectIDs, ...
                obj.SubjectDataMap, obj.singleMode);
            
            obj.updateView();
        end
        
        function changeAlpha(obj,~,~)
            if ~isempty(obj.vSurf)
                alpha(obj.vSurf, obj.cSlider.Value);
            end
        end
        
        function electrodeLabelCallback(obj,~,~), obj.updateView(); end
        function viewModeCallback(obj,~,~), obj.updateView(); end
        
        function setElectrodeFilter(obj, varargin)
            p = inputParser;
            addParameter(p, 'ByName', {}, @iscell);
            addParameter(p, 'ByIndex', [], @isnumeric);
            addParameter(p, 'ByDefinition', [], @isnumeric);
            addParameter(p, 'ShowAll', false, @islogical);
            parse(p, varargin{:});
            obj.ElectrodeFilter = p.Results;
            obj.updateView();
        end
        
        function electrodeFilterCallback(obj)
            % Open the new electrode filter dialog
            selections = obj.filterDialog.open();
            
            % Update the filter
            obj.setElectrodeFilter('ByIndex', selections);
            
            % Refresh view
            obj.updateView();
        end

        
        % function to project electrode contacts to outer convex surface
        function [proj_xyz, idx_surface] = projectElectrodesToSurface(~, coords_xyz, V)
            if isempty(coords_xyz)
                proj_xyz = zeros(0,3);
                idx_surface = zeros(0,1);
                return;
            end
            if size(coords_xyz,2) ~= 3 || size(V,2) ~= 3
                error('coords_xyz and V must be [*,3].');
            end

            % Convex hull to identify "outer" vertices only
            k = convhull(V);                 % Mx3 triangles
            outer_vertices = unique(k(:));   % linear indices of outer shell
            V_outer = V(outer_vertices,:);

            n_elec = size(coords_xyz,1);
            proj_xyz    = NaN(n_elec,3);
            idx_surface = zeros(n_elec,1);

            for i = 1:n_elec
                p = coords_xyz(i,:);
                if any(isnan(p))
                    continue; % leave as NaN / 0
                end
                d = vecnorm(V_outer - p, 2, 2);
                [~, rel_idx] = min(d);
                global_idx = outer_vertices(rel_idx);
                proj_xyz(i,:) = V(global_idx,:);
                idx_surface(i) = global_idx;
            end
        end
        % function to get surface vertices from current patch
        function V = getSurfaceVertices(obj)
            % Returns [Nv x 3] vertices for the current plotted surface.
            if isempty(obj.vSurf) || ~isvalid(obj.vSurf)
                error('Surface patch handle (vSurf) is not available. Plot the surface first.');
            end
            if ~isprop(obj.vSurf, 'Vertices')
                error('Surface patch does not expose a Vertices property.');
            end
            V = double(obj.vSurf.Vertices);
            if size(V,2) ~= 3
                error('Surface vertices must be [Nv x 3].');
            end
        end
        function chName = buildChannelName(~, elPos, elDef, defIdx, electrodeIdx)
            % Build channel name string from electrode definitions
            defName = elDef.Definition(defIdx).Name;
            chIdx = find(find(elPos.DefinitionIdentifier == defIdx) == electrodeIdx);
            chName = sprintf('%s%d', defName, chIdx);
        end

        % function to create tooltips for electrodes
        function txt = tooltipUpdate(obj, evt)
            h = get(evt, 'Target');
            info = get(h, 'tooltipData');
            [arr,~] = split(info.Name,'_');
            subj = arr(1);
            subj = subj{:};
            name = arr(end);
            name = name{:}; % why do i need to index like this? MATLAB :(
            txt = {"Subject: "+ subj,...
                "Name: "+name,...
                "Ch. Num: "+info.ChNum,...
                "Pos: "+sprintf("x:%.2f, y:%.2f, z:%.2f",info.Pos)};
            % Force plain text
            set(h.DataTipTemplate, 'Interpreter','none');
        end
        function showElectrode = shouldShowElectrode(obj, elPos, elDef, electrodeIdx)
            % Determine if electrode should be shown based on current filter
            showElectrode = false;
            
            defIdx = [];
            if ~isempty(elPos) && isfield(elPos,'DefinitionIdentifier')
                defIdx = elPos.DefinitionIdentifier(electrodeIdx);
            end
            
            % Filter by index
            if isfield(obj.ElectrodeFilter,'ByIndex') && ~isempty(obj.ElectrodeFilter.ByIndex)
                if any(electrodeIdx == obj.ElectrodeFilter.ByIndex)
                    showElectrode = true;
                    return;
                end
            end
            
            % Filter by definition
            if isfield(obj.ElectrodeFilter,'ByDefinition') && ~isempty(obj.ElectrodeFilter.ByDefinition)
                if ~isempty(defIdx) && defIdx > 0 && defIdx <= numel(elDef.Definition)
                    defLabel = elDef.Definition(defIdx).Name;
                    if any(strcmpi(obj.ElectrodeFilter.ByDefinition, defLabel)) || ...
                            any(defIdx == obj.ElectrodeFilter.ByDefinition)
                        showElectrode = true;
                        return;
                    end
                end
            end
            
            % Filter by name
            if isfield(obj.ElectrodeFilter,'ByName') && ~isempty(obj.ElectrodeFilter.ByName) && ~isempty(elDef)
                if ~isempty(defIdx) && defIdx > 0 && defIdx <= numel(elDef.Definition)
                    chName = obj.buildChannelName(elPos, elDef, defIdx, electrodeIdx);
                    if any(strcmpi(obj.ElectrodeFilter.ByName, chName))
                        showElectrode = true;
                        return;
                    end
                end
            end
            
            % If no filters defined, show all
            filtCopy = rmfield(obj.ElectrodeFilter, intersect(fieldnames(obj.ElectrodeFilter),{'ShowAll'}));
            if isempty(fieldnames(filtCopy)) || all(structfun(@isempty,filtCopy))
                showElectrode = true;
            end
        end
        
        function updateView(obj) 
            % Clear if no surface available
            if ~isprop(obj,'Surface')
                cla(obj.axModel);
                obj.vSurf = [];
                return;
            end
        
            surface = obj.Surface;
            cla(obj.axModel);
            hold(obj.axModel,'off');
        
            if isempty(surface)
                delete(obj.axModel.Children);
                return;
            end
        
            % --- Surface plotting ---
            if ~isempty(surface.Model) && isempty(surface.Annotation)
                % Plain surface (no annotation)
                obj.vSurf = plot3DModel(obj.axModel, surface.Model);
            elseif ~isempty(surface.Model) && ~isempty(surface.Annotation)
                % Surface with annotation coloring
                pbar = waitbar(0,'Creating 3D Model...');
                barflag = 1;
                [annotation_remap, rand_cmap, names, name_id] = ...
                    createColormapFromAnnotations(surface, barflag);
                
                obj.vSurf = plot3DModel(obj.axModel, surface.Model, annotation_remap);
                % make brain surface noninteractive
                set(obj.vSurf, 'HitTest', 'off', 'PickableParts', 'none');

                if isempty(obj.brain_cmap)
                    obj.brain_cmap = rand_cmap;
                end
                colormap(obj.axModel, obj.brain_cmap);
                material(obj.axModel,'dull');
        
                obj.plotElectrodes();
                % Enable data cursor
                dcm = datacursormode(gcf);
                dcm.Enable = 'on';
                dcm.UpdateFcn = @(~,evt) obj.tooltipUpdate(evt);
                
                % --- Colorbar ---
                if isscalar(names)
                    colorbar(obj.axModel,'FontSize',12,'location','east', ...
                             'TickLabelInterpreter','none','Ticks',1,'TickLabels',names);
                elseif length(names) > 1 && length(names) < 100
                    colorbar(obj.axModel,'Ticks',linspace(1.5,length(name_id)+0.5,length(name_id)+1), ...
                             'Limits',[min(name_id) max(name_id)], ...
                             'TickLabels',names,'FontSize',12,'location','east', ...
                             'TickLabelInterpreter','none');
                end
                close(pbar);
            end
            alpha(obj.vSurf, obj.cSlider.Value);
        
            set(obj.axModel,'AmbientLightColor',[1 1 1]);
            axis(obj.axModel,'equal','off');
            xlim(obj.axModel,'auto'); ylim(obj.axModel,'auto');
            set(obj.axModel,'Color','k','clipping','off', ...
                'XColor','none','YColor','none','ZColor','none');
        end
        function appearCallback(obj)
            [obj.brain_cmap,obj.contact_cmap, obj.contact_sizemap] = ...
                appearanceDialog({obj.Surface.AnnotationLabel.Name},obj.brain_cmap,...
                            obj.ElectrodePositions, obj.ElectrodeDefinitions,...
                            obj.contact_cmap,obj.contact_sizemap);
            obj.updateView();
        end
        function plotElectrodes(obj)
            % Plot electrodes according to filter and labeling
            if isempty(obj.ElectrodePositions)
                return;
            end
            
            obj.ChannelHandles = {};

            % Determine label mode if dropdown exists
            if ~isempty(obj.electrodeLabelDropdown)
                labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
            else
                labelMode = 'Index';
            end
            
            % Determine view mode if dropdown exists
            if ~isempty(obj.viewModeDropdown)
                viewMode = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});
            else
                viewMode = 'Original';
            end

            elPos = obj.ElectrodePositions;
            elDef = obj.ElectrodeDefinitions;

            % Determine which coordinates to plot based on view mode
            locOriginal = elPos.Location;  % assume [N x 3] numeric
            coordsToPlot = locOriginal;
            drawArrows = false;
            
            viewMode = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});

            if viewMode ~= "Original"
                % Need projected coordinates
                V = obj.getSurfaceVertices();
                [proj_xyz, ~] = obj.projectElectrodesToSurface(locOriginal, V);
                coordsToPlot = proj_xyz;
                drawArrows = (viewMode == "Projected + Arrows");
            end

            % Build colormap if needed
            n_contacts = size(elPos.DefinitionIdentifier,1);
            if isempty(obj.contact_cmap)
                obj.contact_cmap = ones([n_contacts, 3]);
            end
            if isempty(obj.contact_sizemap)
                obj.contact_sizemap = 2*ones([n_contacts, 1]);
            end
            % Main loop
            for i = 1:size(locOriginal,1)
                if obj.shouldShowElectrode(elPos, elDef, i)

                    % pick plotted coordinate (original or projected)
                    locPlot = coordsToPlot(i,:);

                    % Skip if projected is NaN (e.g., missing original)
                    if any(isnan(locPlot))
                        continue;
                    end

                    color = obj.contact_cmap(i,:);
                    con_size = obj.contact_sizemap(i);

                    % Plot pickable "ball" at the *plotted* location
                    ball = plotBallsOnVolume(obj.axModel, locPlot, color, con_size);
                    ball = ball{1};

                    % Tooltip payload
                    num_str = num2str(i);
                    def_idx = elPos.DefinitionIdentifier(i);
                    name = obj.buildChannelName(elPos, elDef, def_idx, i);

                    addprop(ball,'tooltipData');
                    ball.tooltipData = struct("Name", name, ...
                                              "ChNum", num_str, ...
                                              "Pos", locPlot);
                    obj.ChannelHandles{end+1} = ball;

                    % Labels (attach to plotted position)
                    if ~strcmp(labelMode, "None")
                        switch labelMode
                            case 'Name'
                                labelStr = name;
                            otherwise
                                labelStr = num_str;
                        end
                        text(obj.axModel, locPlot(1)+1, locPlot(2)+1, locPlot(3)+1, ...
                             labelStr, 'FontSize', 14, 'Color', 'k', 'Interpreter','none');
                    end

                    % Optional: draw original point + arrow in arrows mode
                    if drawArrows
                        locOrig = locOriginal(i,:);
                        if ~any(isnan(locOrig))
                            % Original point (non-pickable)
                            % scatter3(obj.axModel, locOrig(1), locOrig(2), locOrig(3), ...
                            %     80, 'b', 'filled', 'MarkerEdgeColor', 'k', ...
                            %     'HitTest','off','PickableParts','none');

                            % Arrow (non-pickable)
                            hold(obj.axModel,'on');  
                            arrowVec = locPlot - locOrig;
                            quiver3(obj.axModel, locOrig(1), locOrig(2), locOrig(3), ...
                                arrowVec(1), arrowVec(2), arrowVec(3), ...
                                0, 'k', 'LineWidth', 1.2, ...
                                'HitTest','off','PickableParts','none');
                            hold(obj.axModel,'off');
                        end
                    end
                end
            end
        end  

        function combineSubjectData(obj, subjectDataMap)
                % Flatten multiple subjects into single Surface + Electrode sets
                if isscalar(obj.SubjectIDs)
                    subj = obj.SubjectIDs{1};
                    data = subjectDataMap(subj);
                    obj.ElectrodePositions = data.ElectrodePositions;
                    obj.ElectrodeDefinitions = data.ElectrodeDefinitions;
                    obj.singleMode = 1;
                    return
                end
                obj.singleMode = 0;
                % Concatenate electrode positions + defs, tagging with subject ID
                allPos = [];
                allDef = [];
                subjLabels = {};
                
                defCounter = 0; % counts definitions (ie., electode name
                                % so that each channel is given electrode
                                % from correct subj
                
                for k = 1:numel(obj.SubjectIDs)
                    subj = obj.SubjectIDs{k};
                    data = subjectDataMap(subj);
                    if isempty(data.ElectrodePositions), continue; end
                    
                    pos = data.ElectrodePositions;
                    def = data.ElectrodeDefinitions;
    
                    pos.DefinitionIdentifier = pos.DefinitionIdentifier + defCounter;
                    defCounter = defCounter + numel(data.ElectrodeDefinitions.Definition);
    
                    if isempty(allPos)
                        allPos = pos;
                    else
                        allPos.Location = [allPos.Location;...
                                pos.Location];
                        allPos.DefinitionIdentifier = ...
                            [allPos.DefinitionIdentifier; 
                                pos.DefinitionIdentifier];
                        allPos.Name = [allPos.Name; ...
                            pos.Name];
                    end
                    for d = 1:numel(def.Definition) 
                        def.Definition(d).Name = sprintf('%s_%s', ...
                            subj, def.Definition(d).Name); 
                    end 
                    if isempty(allDef) 
                        allDef = def; 
                    else 
                        allDef.Definition = [allDef.Definition; def.Definition];
                    end 
                end
    
                obj.ElectrodePositions = allPos;
                obj.ElectrodeDefinitions = allDef;
               
        end
    end
end
