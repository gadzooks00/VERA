classdef SuperModel3DView < AView & uix.Grid
    % SuperModel3DView - View of a Surface
    % Shows a Surface and the Electrode Locations if available
    % In modification to allow more flexibility in viewing
    % See also AView
    properties
        SurfaceIdentifier %Identifier for which surface to show
        ElectrodeLocationIdentifier %Identifier for the Electrode Location to be shown
        ElectrodeDefinitionIdentifier
        ElectrodeFilter = struct() % Filter criteria for electrode selection
        ShowAllElectrodes = true   % Master switch for electrode visibility
    end
    properties (Access = private)
        axModel
        requiresUpdate = false
        cSlider
        vSurf
        electrodeLabelDropdown  % New dropdown for electrode labeling
        oroperties
    end

    methods
        function obj = SuperModel3DView(varargin)
            %MODEL3DVIEW Construct an instance of this class
            obj.SurfaceIdentifier='Surface';
            obj.ElectrodeLocationIdentifier='ElectrodeLocation';
            obj.ElectrodeDefinitionIdentifier='ElectrodeDefinition';
            %opengl hardware;
            tmp_Grid=uix.Grid('Parent',obj);
            obj.axModel=axes('Parent',uicontainer('Parent',tmp_Grid),'Units','normalized','Color','k','ActivePositionProperty', 'Position');
            set(tmp_Grid,'BackgroundColor','k');
            set(obj,'BackgroundColor','k');
            
            % Create control panel grid
            controlGrid=uix.Grid('Parent',obj);
            
            % Opacity slider section
            sliderGrid=uix.Grid('Parent',controlGrid);
            uicontrol('Parent',sliderGrid,'Style','text','String','Opacity');
            obj.cSlider=uicontrol('Parent',sliderGrid,'Style','slider','Min',0,'Max',1,'Value',1);
            sliderGrid.Widths=[60,-1];
            sliderGrid.Heights=[15];
            addlistener(obj.cSlider, 'Value', 'PostSet',@obj.changeAlpha);
            
            % Electrode labeling dropdown section
            labelGrid=uix.Grid('Parent',controlGrid);
            uicontrol('Parent',labelGrid,'Style','text','String','Label electrodes by:');
            obj.electrodeLabelDropdown = uicontrol('Parent',labelGrid,'Style','popupmenu',...
                'String',{'Channel Name','Channel Number'},'Value',1,...
                'Callback',@obj.electrodeLabelCallback);
            labelGrid.Widths=[120,-1];
            labelGrid.Heights=[20];
            
            % Set control grid layout
            controlGrid.Widths=[-1];
            controlGrid.Heights=[15,20];
            
            obj.Widths=[-1];
            obj.Heights=[-1, 35]; % Increased height for controls
            addlistener(obj.cSlider, 'Value', 'PostSet',@obj.changeAlpha);
            
            try
                uix.set( obj, varargin{:} )
            catch e
                delete( obj )
                e.throwAsCaller()
            end

            obj.autoLoadElectrodeSelection();
        end
    end

    methods(Access = protected)
        function loadElectrodeSelection(obj, filename)
            % Load electrode selection from a text file
            % File format: one electrode per line, can be names or indices
    
            if ~exist(filename, 'file')
                warning('Electrode selection file not found: %s', filename);
                return;
            end
    
            fid = fopen(filename, 'r');
            lines = {};
            while ~feof(fid)
                line = fgetl(fid);
                if ischar(line) && ~isempty(strtrim(line))
                    lines{end+1} = strtrim(line);
                end
            end
            fclose(fid);
    
            % Determine if lines contain numbers or names
            if all(cellfun(@(x) ~isnan(str2double(x)), lines))
                % Numeric indices
                indices = cellfun(@str2double, lines);
                obj.setElectrodeFilter('ByIndex', indices);
            else
                % Electrode names
                obj.setElectrodeFilter('ByName', lines);
            end
        end
        function setElectrodeFilter(obj, varargin)
            % Set electrode filter criteria
            % Usage: setElectrodeFilter('ByName', {'Grid1', 'Strip2'})
            %        setElectrodeFilter('ByIndex', [1,3,5:10])
            %        setElectrodeFilter('ByDefinition', [1,2])
            
            p = inputParser;
            addParameter(p, 'ByName', {}, @iscell);
            addParameter(p, 'ByIndex', [], @isnumeric);
            addParameter(p, 'ByDefinition', [], @isnumeric);
            addParameter(p, 'ShowAll', false, @islogical);
            
            parse(p, varargin{:});
            
            obj.ElectrodeFilter = p.Results;
            obj.ShowAllElectrodes = p.Results.ShowAll;
            obj.updateView(); % Refresh display
        end
        function changeAlpha(obj,~,~)
            if(~isempty(obj.vSurf))
                alpha(obj.vSurf,obj.cSlider.Value);
            end
        end
        
        function electrodeLabelCallback(obj, ~, ~)
            % Callback for electrode labeling dropdown change
            obj.updateView(); % Refresh the view with new labeling
        end

        function dataUpdate(obj)
            obj.updateView();
        end

        function updateView(obj)
            if(~obj.AvailableData.isKey(obj.SurfaceIdentifier))
                cla(obj.axModel);
                obj.vSurf=[];
                return;
            end
            surface=obj.AvailableData(obj.SurfaceIdentifier);
            hold(obj.axModel,'off');

            if(~isempty(surface))

                if(~isempty(surface.Model) && isempty(surface.Annotation))
                    obj.vSurf=plot3DModel(obj.axModel,surface.Model);
                    % trisurf(surface.Model.tri, surface.Model.vert(:, 1), surface.Model.vert(:, 2), surface.Model.vert(:, 3) ,'Parent',obj.axModel,settings{:});
                elseif(~isempty(surface.Model) && ~isempty(surface.Annotation))
                    pbar=waitbar(0,'Creating 3D Model...');
                    
                    % append gray bar between surface and electrodes on colorbar
                    % not sure why, but when barflag=0 it messes up the
                    % color map of the 3D model
                    % barflag = 0;
                    % if obj.AvailableData.isKey(obj.ElectrodeLocationIdentifier)
                    %     if isprop(obj.AvailableData(obj.ElectrodeLocationIdentifier),'Location')
                    %         if ~isempty(obj.AvailableData(obj.ElectrodeLocationIdentifier).Location)
                    %             barflag = 1;
                    %         end
                    %     end
                    % end
                    barflag = 1;
                    [annotation_remap,cmap,names,name_id]=createColormapFromAnnotations(surface,barflag);

                    obj.vSurf=plot3DModel(obj.axModel,surface.Model,annotation_remap);
                    % trisurf(surface.Model.tri, surface.Model.vert(:, 1), surface.Model.vert(:, 2), surface.Model.vert(:, 3),annotation_remap ,'Parent',obj.axModel,settings{:});
                    colormap(obj.axModel,cmap);

                    %light(obj.axModel,'Position',[-1 0 0]);
                    % camlight(obj.axModel,'headlight');
                    material(obj.axModel,'dull');
                    elIdentifiers=obj.ElectrodeLocationIdentifier;
                    elDefIdentifiers=obj.ElectrodeDefinitionIdentifier;
                    if(~iscell(obj.ElectrodeLocationIdentifier))
                        elIdentifiers={obj.ElectrodeLocationIdentifier};
                    end
                    if(~iscell(obj.ElectrodeDefinitionIdentifier))
                        elDefIdentifiers={obj.ElectrodeDefinitionIdentifier};
                    end
                    waitbar(0.3,pbar);
                    for i_elId=1:length(elIdentifiers)
                        waitbar(0.3+0.7*(i_elId/length(elIdentifiers)),pbar);
                        if(obj.AvailableData.isKey(elIdentifiers{i_elId}))
                            elPos=obj.AvailableData(elIdentifiers{i_elId});
                            if(~isempty(elPos) && ~isempty(elPos.DefinitionIdentifier))
                                for i=unique(elPos.DefinitionIdentifier)'
                                    plotBallsOnVolume(obj.axModel,elPos.Location(elPos.DefinitionIdentifier==i,:),[],2);
                                    if(obj.AvailableData.isKey(elDefIdentifiers{i_elId}))
                                        elDef=obj.AvailableData(elDefIdentifiers{i_elId});
                                        names{end+1}=elDef.Definition(i).Name;
                                        name_id(end+1)=length(name_id)+1;
                                    end
                                end
                            end

                            % Get the selected labeling mode
                            labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
                            
                            % Get electrode definition for channel name labeling
                            if(obj.AvailableData.isKey(elDefIdentifiers{i_elId}))
                                elDef=obj.AvailableData(elDefIdentifiers{i_elId});
                            else
                                elDef = [];
                            end

                            % Add electrode labels based on selected mode
                            for iLoc = 1:size(elPos.Location,1)
                                % Check if this electrode should be displayed
                                if ~obj.shouldShowElectrode(elPos, elDef, iLoc)
                                    continue; % Skip this electrode
                                end
                                switch labelMode
                                    case 'Channel Name'
                                        labelStr = "n/a"; % fallback
                                        if ~isempty(elDef) && isprop(elDef, 'Definition') ...
                                           && iLoc <= numel(elPos.DefinitionIdentifier)

                                            defIdx = elPos.DefinitionIdentifier(iLoc);
                                            if defIdx > 0 && defIdx <= numel(elDef.Definition) ...
                                            && isfield(elDef.Definition(defIdx), 'Name')

                                                def_name = elDef.Definition(defIdx).Name;

                                                % Match table view's channel index calculation
                                                chidx = find(find(elPos.DefinitionIdentifier == defIdx) == iLoc);

                                                labelStr = sprintf('%s%d', def_name, chidx);
                                            end
                                        end
                                    otherwise
                                        % same old channel numbering system
                                        labelStr = num2str(iLoc);
                                end

                                text(obj.axModel, ...
                                    elPos.Location(iLoc,1)+1, ...
                                    elPos.Location(iLoc,2)+1, ...
                                    elPos.Location(iLoc,3)+1, ...
                                    labelStr, ...
                                    'FontSize', 14, 'Color', 'k', ...
                                    'Interpreter', 'none'); % ensure raw text
                            end
                        end
                    end
                    if  length(names) == 1
                        cb = colorbar(obj.axModel,'FontSize',12,'location','east','TickLabelInterpreter','none','Ticks',1,'TickLabels',names);
                    elseif length(names) > 1 && length(names) < 100 % color bars that are too long are illegible anyway
                        cb = colorbar(obj.axModel,'Ticks',linspace(1.5,length(name_id)+0.5,length(name_id)+1),'Limits',[min(name_id) max(name_id)],...
                            'TickLabels',names,'FontSize',12,'location','east','TickLabelInterpreter','none');
                    end
                    % set(cb,'TickLabelInterpreter','none')
                    close(pbar);
                end
                alpha(obj.vSurf,obj.cSlider.Value);

                set(obj.axModel,'AmbientLightColor',[1 1 1])
                %zoom(obj.axModel,'on');

                set(obj.axModel,'xtick',[]);
                set(obj.axModel,'ytick',[]);
                axis(obj.axModel,'equal');
                axis(obj.axModel,'off');
                xlim(obj.axModel,'auto');
                ylim(obj.axModel,'auto');
                set(obj.axModel,'Color','k');
                set(obj.axModel,'clipping','off');
                set(obj.axModel,'XColor', 'none','YColor','none','ZColor','none')
            else
                delete(obj.axModel.Children);
            end
        end
    end
    methods (Access = private)
        function autoLoadElectrodeSelection(obj)
            configFile = 'classes/GUI/Views/electrodes.txt';
            if exist(configFile,'file')
                obj.loadElectrodeSelection(configFile)
                return;
            end
            % If no config file found, show all electrodes
            obj.ShowAllElectrodes = true;
        end
        function chName = buildChannelName(obj, elPos,elDef,defIdx,electrodeIdx)
            defName = elDef.Definition(defIdx).Name;
            chidx = find(find(elPos.DefinitionIdentifier == defIdx) == electrodeIdx);
            chName =  sprintf('%s%d', defName, chidx);
        end
        function showElectrode = shouldShowElectrode(obj, elPos, elDef, electrodeIdx)
            % Determine if electrode should be displayed based on current filter
            if obj.ShowAllElectrodes
                showElectrode = true;
                return;
            end
            
            showElectrode = false;
            % Filter by name pattern
            if ~isempty(obj.ElectrodeFilter.ByName) && ~isempty(elDef)
                defIdx = elPos.DefinitionIdentifier(electrodeIdx);
                if defIdx > 0 && defIdx <= numel(elDef.Definition)
                    chName = obj.buildChannelName(elPos,elDef,defIdx,electrodeIdx);
                    if any(strcmpi(obj.ElectrodeFilter.ByName, chName)) % check if chName matches any in filter
                        showElectrode = true;
                        return;
                    end
                end
            end
            
            % If no filters are set, show all
            if isempty(fieldnames(rmfield(obj.ElectrodeFilter, 'ShowAll')))
                showElectrode = true;
            end
        end
    end
end