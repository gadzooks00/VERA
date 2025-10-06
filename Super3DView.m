classdef Super3DView < uix.Grid
    % Super3DView - 3D visualization of brain surfaces + electrodes
    % Uses normalized struct: Subjects(s).Contacts(c)
    
    properties
        Surface
        Subjects   % struct: Subjects(s).ID, .Contacts(:)
    end
    
    properties (Access = protected)
        % GUI handles
        axModel
        vSurf
        legendCheckbox
        exportButton
        electrodeLabelDropdown
        filterDialog
        viewModeDropdown
        cSlider
        filterButton
        brain_cmap
        appearanceButton
    end
    
    methods
        function obj = Super3DView(surface, subjectDataMap, varargin)
            % === Figure & layout ===
            f = figure('Color','k','Name','Viewer');
            set(obj,'Parent',f,'Units','normalized','Position',[0 0 1 1]);
            
            tmp_Grid = uix.Grid('Parent',obj);
            obj.axModel = axes('Parent',uicontainer('Parent',tmp_Grid),...
                'Units','normalized','Color','k');
            set(tmp_Grid,'BackgroundColor','k');
            
            % === Controls ===
            controlHBox = uix.HBox('Parent',obj);

            % electrode label dropdown + legend checkbox
            labelBox = uix.VBox('Parent',controlHBox);
            
            % Top row: label + dropdown
            labelGrid = uix.Grid('Parent',labelBox);
            uicontrol('Parent',labelGrid,'Style','text','String','Label electrodes by:');
            obj.electrodeLabelDropdown = uicontrol('Parent',labelGrid,'Style','popupmenu',...
                'String',{'Name','Number','None'},'Value',3,...
                'Callback',@(~,~)obj.updateView());
            labelGrid.Widths  = [120, -1];
            labelGrid.Heights = [20];
            
            % Bottom row: legend checkbox + export button
            buttonHBox = uix.HBox('Parent',labelBox);

            obj.exportButton = uicontrol('Parent',buttonHBox,'Style','pushbutton',...
                'String','Export figure',...
                'Callback',@(~,~)obj.exportFigure());
            obj.legendCheckbox = uicontrol('Parent',buttonHBox,'Style','checkbox',...
                'String','Legend','Value',1,...
                'Callback',@(~,~)obj.updateView());
            obj.legendCheckbox.Value = 0; % legend off by default because it's ugly
            buttonHBox.Widths = [-1, 70];
          
            labelBox.Heights = [20, 35];

            
            % view mode + slider
            leftBox = uix.VBox('Parent',controlHBox);
            viewGrid = uix.Grid('Parent',leftBox);
            uicontrol('Parent',viewGrid,'Style','text','String','View mode:');
            obj.viewModeDropdown = uicontrol('Parent',viewGrid,'Style','popupmenu',...
                'String',{'Original','Projected','Projected + Arrows'},'Value',1,...
                'Callback',@(~,~)obj.updateView());
            viewGrid.Widths  = [80, -1];
            viewGrid.Heights = [20];
            
            sliderGrid = uix.Grid('Parent',leftBox);
            uicontrol('Parent',sliderGrid,'Style','text','String','Opacity');
            obj.cSlider = uicontrol('Parent',sliderGrid,'Style','slider',...
                'Min',0,'Max',1,'Value',1);
            sliderGrid.Widths  = [60, -1];
            sliderGrid.Heights = [15];
            addlistener(obj.cSlider,'Value','PostSet',@(~,~)obj.changeAlpha());
            
            % filter + appearance buttons
            buttonGrid = uix.Grid('Parent',controlHBox);
            obj.filterButton = uicontrol('Parent',buttonGrid,'Style','pushbutton',...
                'String','Filter Electrodes','Callback',@(~,~)obj.electrodeFilterCallback());
            obj.appearanceButton = uicontrol('Parent',buttonGrid,'Style','pushbutton',...
                'String','Coloring','Callback',@(~,~)obj.appearCallback());
            buttonGrid.Heights = [30];
            buttonGrid.Widths  = [-1];
            
            obj.Widths  = [-1];
            obj.Heights = [-1, 60];
            
            % === Data setup ===
            obj.Surface = surface;
            obj.brain_cmap = [];
            obj.Subjects   = obj.buildCanonicalData(subjectDataMap);
            
            % initialize filter dialog
            obj.filterDialog = ElectrodeFilterDialog(obj.Subjects, ...
                isscalar(obj.Subjects));
            
            obj.updateView();
        end
        function changeAlpha(obj)
            if ~isempty(obj.vSurf) && isvalid(obj.vSurf)
                alpha(obj.vSurf, obj.cSlider.Value);
            end
        end
        
        function electrodeFilterCallback(obj)
            % Get selection from dialog and update Visible flags
            obj.Subjects = obj.filterDialog.open(obj.Subjects);
            obj.updateView();
        end
        function exportFigure(obj)
            [file, path] = uiputfile({'*.png';'*.jpg';'*.tif';'*.pdf';'*.eps'}, 'Save Axes As');
            if isequal(file,0)
                return; % user cancelled
            end
            filename = fullfile(path, file);
            exportgraphics(obj.axModel, filename, 'Resolution',300);
        end
        function appearCallback(obj)
            % Gather region names safely
            if isfield(obj.Surface, 'AnnotationLabel') && ~isempty(obj.Surface.AnnotationLabel)
                try
                    regionNames = { obj.Surface.AnnotationLabel.Name };  % struct-array -> cellstr
                catch
                    regionNames = obj.Surface.AnnotationLabel;
                end
            else
                regionNames = {};
            end
        
            % Call dialog: returns updated brain colormap + Subjects with contact colors/sizes
            [obj.brain_cmap, obj.Subjects] = appearanceDialog(regionNames, obj.brain_cmap, obj.Subjects);
        
            % Repaint with updated colors/sizes
            obj.updateView();
        end
        
        function updateView(obj)
            cla(obj.axModel);
            hold(obj.axModel,'off');
            
            if isempty(obj.Surface)
                return;
            end
            
            % --- Plot brain surface ---
            if ~isempty(obj.Surface.Model)
                if isempty(obj.Surface.Annotation)
                    obj.vSurf = plot3DModel(obj.axModel, obj.Surface.Model);
                else
                    pbar = waitbar(0,'Creating 3D Model...');
                    [annotation_remap, rand_cmap, names, name_id] = ...
                        createColormapFromAnnotations(obj.Surface,1);
                    obj.vSurf = plot3DModel(obj.axModel,obj.Surface.Model,annotation_remap);
                    set(obj.vSurf,'HitTest','off','PickableParts','none');
                    
                    if isempty(obj.brain_cmap), obj.brain_cmap = rand_cmap; end
                    colormap(obj.axModel,obj.brain_cmap);
                    material(obj.axModel,'dull');
                    
                    % Colorbar
                    if obj.legendCheckbox.Value
                        if isscalar(names)
                            colorbar(obj.axModel,'FontSize',12,'location','east',...
                                     'TickLabelInterpreter','none','Ticks',1,'TickLabels',names);
                        elseif numel(names)<100
                            colorbar(obj.axModel,'Ticks',linspace(1.5,length(name_id)+0.5,length(name_id)+1),...
                                     'Limits',[min(name_id) max(name_id)],...
                                     'TickLabels',names,'FontSize',12,'location','east',...
                                     'TickLabelInterpreter','none');
                        end
                    end
                    close(pbar);
                end
            end
            alpha(obj.vSurf,obj.cSlider.Value);
            
            set(obj.axModel,'AmbientLightColor',[1 1 1]);
            axis(obj.axModel,'equal','off');
            set(obj.axModel,'Color','k','clipping','off',...
                'XColor','none','YColor','none','ZColor','none');
            
            % --- Plot electrodes ---
            obj.plotElectrodes();
            
            % Data cursor
            dcm = datacursormode(gcf);
            dcm.Enable = 'on';
            dcm.UpdateFcn = @(~,evt) obj.tooltipUpdate(evt);
        end
        
        function plotElectrodes(obj)
            if isempty(obj.Subjects), return; end
            
            labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
            viewMode  = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});
            
            % For projection
            if viewMode ~= "Original"
                V = obj.getSurfaceVertices();
            end
            
            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)
                    contact = obj.Subjects(s).Contacts(c);
                    if ~contact.Visible, continue; end
                    
                    locOrig = contact.Location;
                    locPlot = locOrig;
                    drawArrow = false;
                    
                    if viewMode ~= "Original"
                        [proj_xyz, ~] = obj.projectElectrodesToSurface(locOrig, V);
                        if ~any(isnan(proj_xyz))
                            locPlot = proj_xyz;
                            drawArrow = (viewMode=="Projected + Arrows");
                        end
                    end
                    
                    % Plot sphere
                    ball = plotBallsOnVolume(obj.axModel, locPlot, contact.Color, contact.Size);
                    ball = ball{1};
                    
                    addprop(ball,'tooltipData');
                    ball.tooltipData = contact;
                    
                    % Labels
                    if ~strcmp(labelMode,'None')
                        switch labelMode
                            case 'Name', lbl = contact.Name;
                            otherwise,   lbl = num2str(c);
                        end
                        text(obj.axModel,locPlot(1)+1,locPlot(2)+1,locPlot(3)+1,...
                             lbl,'FontSize',14,'Color','k','Interpreter','none');
                    end
                    
                    % Arrow
                    if drawArrow && ~any(isnan(locOrig))
                        arrowVec = locPlot - locOrig;
                        hold(obj.axModel,'on');
                        quiver3(obj.axModel,locOrig(1),locOrig(2),locOrig(3),...
                            arrowVec(1),arrowVec(2),arrowVec(3),...
                            0,'k','LineWidth',1.2,...
                            'HitTest','off','PickableParts','none');
                        hold(obj.axModel,'off');
                    end
                end
            end
        end
        
        function txt = tooltipUpdate(~,evt)
            h = get(evt,'Target');
            info = get(h,'tooltipData');
            txt = {"Subject: "+info.Subject,...
                   "Name: "+info.Name,...
                   "Electrode: "+info.Electrode,...
                   sprintf("Pos: x=%.2f, y=%.2f, z=%.2f",info.Location)};
            set(h.DataTipTemplate,'Interpreter','none');
        end
    end
    
    methods (Access=private)
        function subjects = buildCanonicalData(~, subjectDataMap)
            % Convert subjectDataMap into struct-of-subjects-of-contacts
            keys = subjectDataMap.keys;
            subjects = struct('ID',{},'Contacts',{});
            
            for k = 1:numel(keys)
                subjID = keys{k};
                data   = subjectDataMap(subjID);
                elPos  = data.ElectrodePositions;
                elDef  = data.ElectrodeDefinitions;
                
                contacts = [];
                for i = 1:size(elPos.Location,1)
                    defIdx = elPos.DefinitionIdentifier(i);
                    if defIdx<=0 || defIdx>numel(elDef.Definition), continue; end
                    defName = elDef.Definition(defIdx).Name;
                    chName  = sprintf('%s_%s%d',subjID,defName,i);
                    
                    c.Subject   = subjID;
                    c.Name      = chName;
                    c.Electrode = defName;
                    c.Location  = elPos.Location(i,:);
                    c.Color     = [1 1 1];
                    c.Size      = 2;
                    c.Visible   = true;
                    
                    contacts = [contacts, c]; %#ok<AGROW>
                end
                subjects(end+1).ID = subjID; %#ok<AGROW>
                subjects(end).Contacts = contacts;
            end
        end
        
        function V = getSurfaceVertices(obj)
            if isempty(obj.vSurf) || ~isvalid(obj.vSurf)
                error('Surface patch handle missing');
            end
            V = double(obj.vSurf.Vertices);
        end
        
        function [proj_xyz, idx_surface] = projectElectrodesToSurface(~, coords, V)
            if isempty(coords)
                proj_xyz = [NaN NaN NaN]; idx_surface = 0; return;
            end
            k = convhull(V);
            outer = unique(k(:));
            Vouter = V(outer,:);
            d = vecnorm(Vouter - coords,2,2);
            [~,r] = min(d);
            idx_surface = outer(r);
            proj_xyz = V(idx_surface,:);
        end
    end
end
