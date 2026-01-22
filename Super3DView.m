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
        exportObjButton
        electrodeLabelDropdown
        filterDialog
        viewModeDropdown
        cSlider
        filterButton
        brain_cmap
        appearanceButton
        appearanceDialog
        surfNames
        annotation
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
            obj.exportObjButton = uicontrol('Parent',buttonHBox,'Style','pushbutton',...
                'String','Export OBJ',...
                'Callback',@(~,~)obj.exportObj());
            obj.legendCheckbox = uicontrol('Parent',buttonHBox,'Style','checkbox',...
                'String','Legend','Value',1,...
                'Callback',@(~,~)obj.updateView());
            obj.legendCheckbox.Value = 0; % legend off by default
            buttonHBox.Widths = [-1, -1, 70];
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

        % === Callbacks ===
        function changeAlpha(obj)
            if ~isempty(obj.vSurf) && isvalid(obj.vSurf)
                alpha(obj.vSurf, obj.cSlider.Value);
            end
        end
        
        function electrodeFilterCallback(obj)
            obj.filterDialog.show();
            uiwait(obj.filterDialog.Fig);
            obj.refreshView();
        end

        function exportFigure(obj)
            [file, path] = uiputfile({'*.png';'*.jpg';'*.tif';'*.pdf';'*.eps'}, 'Save Axes As');
            if isequal(file,0), return; end
            exportgraphics(obj.axModel, fullfile(path,file), 'Resolution',300);
        end

        function exportObj(obj)
            [file, path] = uiputfile({'*.obj'}, 'Save OBJ As');
            if isequal(file,0), return; end

            [~, base_name] = fileparts(file);

            % convert spaces to underscores
            base_name = replace(base_name,' ','_');

            brain_base = [base_name, '_brain'];
            elec_base  = [base_name, '_electrodes'];

            % --- Build exports ---
            have_surface = ~isempty(obj.Surface) && ~isempty(obj.Surface.Model);

            fv_el = struct('vertices',[],'faces',[]);
            el_rgb = zeros(0,3);
            if ~isempty(obj.Subjects)
                [fv_el, el_rgb] = obj.buildElectrodeSpheresObjExport();
            end

            fv_surf = struct('vertices',[],'faces',[]);
            surf_rgb = zeros(0,3);
            if have_surface
                [fv_surf, surf_rgb] = obj.buildSurfaceObjExport();
            end

            brain_alpha = obj.cSlider.Value;

            % --- Now switch folders for writing ---
            old_dir = pwd;
            cleanup = onCleanup(@() cd(old_dir));
            cd(path);

            % delete any prior outputs
            if exist([brain_base, '.obj'], 'file'); delete([brain_base, '.obj']); end
            if exist([brain_base, '.mtl'], 'file'); delete([brain_base, '.mtl']); end

            if exist([elec_base, '.obj'], 'file'); delete([elec_base, '.obj']); end
            if exist([elec_base, '.mtl'], 'file'); delete([elec_base, '.mtl']); end

            % --- 1) Brain only ---
            if have_surface
                obj_write_color(fv_surf, brain_base, surf_rgb, 'object', brain_base, 'd', brain_alpha);
            end

            % --- 2) Electrodes only ---
            if ~isempty(fv_el.faces)
                obj_write_color(fv_el, elec_base, el_rgb, 'object', elec_base);
            end
        end

        function appearCallback(obj)
            obj.appearanceDialog.show();
            uiwait(obj.appearanceDialog.fig);
            obj.brain_cmap = obj.appearanceDialog.getData();
            obj.refreshView();
        end

        % === Main update logic ===
        function updateView(obj)
            % Called externally - decide whether to rebuild or refresh
            if isempty(obj.vSurf) || ~isvalid(obj.vSurf)
                obj.initializeView();
            else
                obj.refreshView();
            end
        end

        % === Initialize (first draw) ===
        function initializeView(obj)
            cla(obj.axModel);
            hold(obj.axModel,'off');

            if isempty(obj.Surface)
                return;
            end

            % --- Plot brain surface ---
            if ~isempty(obj.Surface.Model)
                [obj.annotation, rand_cmap, names, ~] = ...
                    makeColormap(obj.Surface,0);
                obj.brain_cmap = rand_cmap;
                obj.surfNames = names;
                obj.vSurf = plotModel(obj.axModel,obj.Surface.Model, ...
                    obj.annotation,rand_cmap, []);
                set(obj.vSurf,'HitTest','off','PickableParts','none');
                material(obj.axModel,'dull');
            end
            alpha(obj.vSurf,obj.cSlider.Value);
            set(obj.axModel,'AmbientLightColor',[1 1 1]);
            axis(obj.axModel,'equal','off');
            set(obj.axModel,'Color','k','clipping','off');

            % Init appearance dialog
            obj.appearanceDialog = AppearanceDialog(obj.surfNames, ...
                obj.brain_cmap, obj.Subjects);
            
            % --- Create electrode handles ---
            obj.createElectrodePlots();

            % Data cursor
            dcm = datacursormode(gcf);
            dcm.UpdateFcn = @(~,evt) obj.tooltipUpdate(evt);
        end

        % === Create all electrodes (first draw) ===
        function createElectrodePlots(obj)
            labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
            viewMode  = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});

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

                    % --- Create sphere (save handle) ---
                    h = plotBall(obj.axModel, locPlot, contact.Color, ...
                        contact.Size, []);
                    addprop(h,'tooltipData');
                    h.tooltipData = contact;
                    obj.Subjects(s).Contacts(c).Handle = h;

                    % --- Label ---
                    if ~strcmp(labelMode,'None')
                        switch labelMode
                            case 'Name', lbl = contact.Name;
                            otherwise,   lbl = num2str(c);
                        end
                        lh = text(obj.axModel,locPlot(1)+1,locPlot(2)+1,locPlot(3)+1,...
                                 lbl,'FontSize',14,'Color','k','Interpreter','none');
                        obj.Subjects(s).Contacts(c).LabelHandle = lh;
                    end

                    % --- Arrow ---
                    if drawArrow && ~any(isnan(locOrig))
                        arrowVec = locPlot - locOrig;
                        hold(obj.axModel,'on');
                        ah = quiver3(obj.axModel,locOrig(1),locOrig(2),locOrig(3),...
                            arrowVec(1),arrowVec(2),arrowVec(3),...
                            0,'k','LineWidth',1.2,...
                            'HitTest','off','PickableParts','none');
                        hold(obj.axModel,'off');
                        obj.Subjects(s).Contacts(c).ArrowHandle = ah;
                    end
                end
            end
        end

        % === Refresh existing plots ===
        function refreshView(obj)
            % --- Brain surface ---
            if isvalid(obj.vSurf)
                obj.vSurf = plotModel(obj.axModel,obj.Surface.Model, ...
                    obj.annotation,obj.brain_cmap, obj.vSurf);
                alpha(obj.vSurf, obj.cSlider.Value);
            end

            labelMode = obj.electrodeLabelDropdown.String{obj.electrodeLabelDropdown.Value};
            viewMode  = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});

            if viewMode ~= "Original"
                V = obj.getSurfaceVertices();
            end

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)
                    contact = obj.Subjects(s).Contacts(c);
                    if isempty(contact.Handle) || ~isvalid(contact.Handle)
                        continue;
                    end
                    
                    if contact.Visible
                        % Update color & size
                        contact.Handle = plotBall(obj.axModel, ...
                            contact.Location, contact.Color, contact.Size, ...
                            contact.Handle);
                        % Update label
                        if ~strcmp(labelMode,'None')
                            if isempty(contact.LabelHandle) || ~isvalid(contact.LabelHandle)
                                loc = contact.Location;
                                lh = text(obj.axModel,loc(1)+1,loc(2)+1,loc(3)+1,...
                                    contact.Name,'FontSize',14,'Color','k','Interpreter','none');
                                obj.Subjects(s).Contacts(c).LabelHandle = lh;
                            end
                            set(contact.LabelHandle,'Visible','on');
                        else
                            if ~isempty(contact.LabelHandle) && isvalid(contact.LabelHandle)
                                set(contact.LabelHandle,'Visible','off');
                            end
                        end
                    else
                        set(contact.Handle,'Visible','off');
                    end
                end
            end
        end

        % === Tooltip ===
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
            keys = subjectDataMap.keys;
            subjects = Subject.empty;

            for k = 1:numel(keys)
                subj_id = keys{k};
                data    = subjectDataMap(subj_id);
                el_pos  = data.ElectrodePositions;
                el_def  = data.ElectrodeDefinitions;
                el_pos  = data.ElectrodePositions;
                el_def  = data.ElectrodeDefinitions;

                % Defensive check: Name should align with Location rows
                n_loc = size(el_pos.Location, 1);
                if ~isfield(el_pos, 'Name') || numel(el_pos.Name) ~= n_loc
                    error('ElectrodePositions.Name must exist and have one entry per Location row.');
                end

                contacts = Contact.empty;

                for i = 1:n_loc
                    def_idx = el_pos.DefinitionIdentifier(i);
                    if def_idx <= 0 || def_idx > numel(el_def.Definition)
                        continue;
                    end

                    % Keep def_name as the electrode GROUP label (used for dropdown grouping)
                    def_name = el_def.Definition(def_idx).Name;

                    % Use the provided per-contact name for the channel/contact label
                    pos_name = el_pos.Name{i};
                    if isstring(pos_name), pos_name = char(pos_name); end

                    % If you want subject prefix, do it here; otherwise just use pos_name
                    ch_name = sprintf('%s_%s', subj_id, pos_name);

                    contacts(end+1) = Contact(subj_id, ch_name, def_name, el_pos.Location(i,:));
                end

                subjects(end+1) = Subject(subj_id, contacts);
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

        function [fv_surf, surf_rgb] = buildSurfaceObjExport(obj)
            fv_surf.vertices = double(obj.Surface.Model.vert);
            fv_surf.faces    = double(obj.Surface.Model.tri);

            if min(fv_surf.faces(:)) == 0
                fv_surf.faces = fv_surf.faces + 1;
            end

            fv_surf.vertices = obj.rotateVertices(fv_surf.vertices, 1, pi/2);

            n_vert = size(fv_surf.vertices, 1);
            surf_rgb = repmat([0.7 0.7 0.7], n_vert, 1);

            if ~isempty(obj.annotation) && ~isempty(obj.brain_cmap)
                ann = double(obj.annotation(:));
                if numel(ann) == n_vert
                    k = size(obj.brain_cmap, 1);
                    idx = ann;
                    idx(~isfinite(idx)) = 0;
                    keep = (idx >= 1) & (idx <= k);
                    surf_rgb(keep,:) = obj.brain_cmap(idx(keep),:);
                end
            end

            surf_rgb = obj.normalizeRgb01(surf_rgb);
        end

        function [fv_el, el_rgb] = buildElectrodeSpheresObjExport(obj)
            fv_el.vertices = [];
            fv_el.faces    = [];
            el_rgb         = zeros(0,3);

            viewMode  = string(obj.viewModeDropdown.String{obj.viewModeDropdown.Value});

            sphereRes = 16;
            [x, y, z] = sphere(sphereRes);
            p = surf2patch(x, y, z, 'triangles');
            v0 = double(p.vertices);
            f0 = double(p.faces);

            v_offset = 0;

            for s = 1:numel(obj.Subjects)
                for c = 1:numel(obj.Subjects(s).Contacts)
                    contact = obj.Subjects(s).Contacts(c);
                    if ~contact.Visible
                        continue;
                    end

                    locOrig = double(contact.Location);
                    locPlot = locOrig;

                    if viewMode ~= "Original"
                        Vraw = double(obj.Surface.Model.vert);
                        [proj_xyz, ~] = obj.projectElectrodesToSurface(locOrig, Vraw);
                        if ~any(isnan(proj_xyz))
                            locPlot = proj_xyz;
                        end
                    end

                    locPlot = obj.rotateVertices(locPlot, 1, pi/2);
                    
                    radius = double(contact.Size);

                    v_i = v0 * radius + locPlot;
                    f_i = f0 + v_offset;

                    rgb = obj.normalizeRgb01(contact.Color);

                    fv_el.vertices = [fv_el.vertices; v_i];
                    fv_el.faces    = [fv_el.faces; f_i];
                    el_rgb         = [el_rgb; repmat(rgb, size(v_i,1), 1)];

                    v_offset = v_offset + size(v_i,1);
                end
            end
        end

        function v_out = rotateVertices(~, V, indice, angle)
            Rz = [ cos(angle), -sin(angle), 0 ;
                  sin(angle), cos(angle), 0 ;
                  0, 0, 1 ];
            Ry = [ cos(angle), 0, sin(angle) ;
                  0, 1, 0 ;
                  -sin(angle), 0, cos(angle) ];
            Rx = [ 1, 0, 0 ;
                  0, cos(angle), -sin(angle);
                  0, sin(angle), cos(angle) ];
            
            if(indice==1)
                   v_out = V*Rx;
            end
            if(indice==2)
                   v_out = V*Ry;
            end
            if(indice==3)
                   v_out = V*Rz;
            end
        end

        function rgb01 = normalizeRgb01(~, rgb)
            rgb = double(rgb);
            if max(rgb(:)) > 1.5
                rgb = rgb ./ 255;
            end
            rgb01 = max(0, min(1, rgb));
        end
    end
end
