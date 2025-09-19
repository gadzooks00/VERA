classdef (Abstract) Abstract3DView < uix.Grid
    % Abstract3DView - Base class for 3D surface + electrode visualization
    % Subclasses must populate Surface, ElectrodePositions, and
    % ElectrodeDefinitions.
    
    properties
        % Data to be plotted (populated by subclass)
        Surface
        ElectrodePositions
        ElectrodeDefinitions

        % Used to keep track of figure handles for tooltip
        ChannelHandles

        % Electrode filtering
        ElectrodeFilter = struct() % Filter criteria for electrode selection
    end
    
    properties (Access = protected)
        axModel         % Axes for plotting
        vSurf           % Handle to plotted surface
        electrodeLabelDropdown
        cSlider
        filterButton
    end
    
    methods
        function obj = Abstract3DView(surface,varargin)
            f = figure('Color','k','Name','Viewer');
            set(obj, 'Parent', f); % reparent the entire viewer grid
            set(obj, 'Units', 'normalized', 'Position', [0 0 1 1]);
            set(f, 'Color', [1 1 1]);
        
            % --- Layout grid: top = 3D axes, bottom = controls ---
            tmp_Grid = uix.Grid('Parent', obj);
            obj.axModel = axes('Parent', uicontainer('Parent', tmp_Grid), ...
                'Units','normalized','Color','k','ActivePositionProperty','Position');
            set(tmp_Grid,'BackgroundColor','k');
            set(obj,'BackgroundColor','k');
            
            % --- Shared controls panel ---
            controlHBox = uix.HBox('Parent', obj);
            
            % Left: electrode label dropdown
            labelGrid = uix.Grid('Parent', controlHBox);
            uicontrol('Parent', labelGrid, 'Style', 'text', 'String', 'Label electrodes by:');
            obj.electrodeLabelDropdown = uicontrol('Parent', labelGrid, 'Style', 'popupmenu', ...
                'String', {'Name','Number','None'}, 'Value', 1, ...
                'Callback', @obj.electrodeLabelCallback);
            labelGrid.Widths  = [120, -1];
            labelGrid.Heights = [20];
            
            % Right: opacity slider
            sliderGrid = uix.Grid('Parent', controlHBox);
            uicontrol('Parent', sliderGrid, 'Style', 'text', 'String', 'Opacity');
            obj.cSlider = uicontrol('Parent', sliderGrid, 'Style', 'slider', 'Min',0, 'Max',1, 'Value',1);
            sliderGrid.Widths  = [60, -1];
            sliderGrid.Heights = [15];
            addlistener(obj.cSlider, 'Value', 'PostSet', @obj.changeAlpha);
            
            % Electrode filter button
            buttonGrid = uix.Grid('Parent', controlHBox);
            obj.filterButton = uicontrol('Parent', buttonGrid, 'Style','pushbutton', ...
                'String', 'Filter Electrodes', ...
                'Callback', @(~,~)obj.electrodeFilterCallback());
            buttonGrid.Heights = [30];
            buttonGrid.Widths = [-1];
            
            controlHBox.Widths = [200, -1, 120];  % adjust as needed
            
            % Layout
            obj.Widths  = [-1];
            obj.Heights = [-1, 60];

            obj.Surface = surface;
        end
        
        %% Shared callback implementations
        function changeAlpha(obj,~,~)
            % Adjust surface alpha (shared)
            if ~isempty(obj.vSurf)
                alpha(obj.vSurf, obj.cSlider.Value);
            end
        end
        
        function electrodeLabelCallback(obj,~,~)
            % Label dropdown changed (shared)
            obj.updateView();
        end
    
        function setElectrodeFilter(obj, varargin)
            % Set electrode filter criteria
            % Usage:
            %   obj.setElectrodeFilter('ByName', {'Grid1','Strip2'})
            %   obj.setElectrodeFilter('ByIndex', [1,3,5:10])
            %   obj.setElectrodeFilter('ByDefinition', [1,2])
            
            p = inputParser;
            addParameter(p, 'ByName', {}, @iscell);
            addParameter(p, 'ByIndex', [], @isnumeric);
            addParameter(p, 'ByDefinition', [], @isnumeric);
            addParameter(p, 'ShowAll', false, @islogical);
            parse(p, varargin{:});
            
            obj.ElectrodeFilter = p.Results;
            obj.updateView();
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
                [annotation_remap, cmap, names, name_id] = createColormapFromAnnotations(surface, barflag);
        
                obj.vSurf = plot3DModel(obj.axModel, surface.Model, annotation_remap);
                % make brain surface noninteractive
                set(obj.vSurf, 'HitTest', 'off', 'PickableParts', 'none');

                colormap(obj.axModel, cmap);
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

    end
    methods (Abstract)
        electrodeFilterCallback(obj)
    end
    methods (Access = protected)
        function plotElectrodes(obj)
            % Plot electrodes according to filter and labeling
            if isempty(obj.ElectrodePositions)
                return;
            end
            
            obj.ChannelHandles = [];

            % Determine label mode if dropdown exists
            if ~isempty(obj.electrodeLabelDropdown)
                labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
            else
                labelMode = 'Index';
            end
            
            elPos = obj.ElectrodePositions;
            elDef = obj.ElectrodeDefinitions;
            
            for i = 1:numel(elPos.DefinitionIdentifier)
                if obj.shouldShowElectrode(elPos, elDef, i)
                    loc = elPos.Location(i,:);
                    % plot each ball one by one with a function that
                    % is meant to plot multiple at once 
                    % because I am a PSYCHOPATH
                    ball = plotBallsOnVolume(obj.axModel, loc, [], 2);

                    num_str = num2str(i);
                    defIdx = elPos.DefinitionIdentifier(i);
                    name = obj.buildChannelName(elPos,elDef,defIdx,i);

                    ball = ball{1};
                    addprop(ball,'tooltipData');
                    ball.tooltipData = struct("Name", name, ...
                                                "ChNum", num_str, ...
                                                "Pos", loc);
                    obj.ChannelHandles(end+1) = ball;
                    % Add label
                    switch labelMode
                        case 'Name'
                            labelStr = name;
                        case 'None'
                            labelStr = '';
                        otherwise
                            labelStr = num_str;
                    end
                    
                    text(obj.axModel, loc(1)+1, loc(2)+1, loc(3)+1, ...
                        labelStr, 'FontSize', 14, 'Color', 'k', 'Interpreter','none');
                end
            end
            uistack(obj.ChannelHandles,'top');
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
        
        function chName = buildChannelName(~, elPos, elDef, defIdx, electrodeIdx)
            % Build channel name string from electrode definitions
            defName = elDef.Definition(defIdx).Name;
            chIdx = find(find(elPos.DefinitionIdentifier == defIdx) == electrodeIdx);
            chName = sprintf('%s%d', defName, chIdx);
        end

        % function to create tooltips for electrodes
        function txt = tooltipUpdate(obj, evt)
            h = get(evt, 'Target');
            if ismember(h,obj.ChannelHandles)
                info = get(h, 'tooltipData');
                txt = {"Name: "+info.Name,...
                    "Ch. Num: "+info.ChNum,...
                    "Pos: "+sprintf("x:%.2f, y:%.2f, z:%.2f",info.Pos)};
            else
                txt = {};
            end
        end
    end
end
