%--------------------------------------------------------------------------
% exportElectrodeTablesFromVERA
%
% PURPOSE
%   Load electrode data from VERA brain.mat / MNIbrain.mat files
%   and export structured tables to Excel.
%
% OUTPUT PER SUBJECT
%   sub-XX_ElectrodeCoordinates.xlsx
%       - Sheet: subject_space
%       - Sheet: mni_space
%
%--------------------------------------------------------------------------

clearvars;
clc;

addpath(genpath('FileFunctions'));

%% ----------------------------%
% Select project folders       %
%------------------------------%
projects = selectProjectFolders();

if isempty(projects)
    disp('No projects selected.');
    return;
end

%% =========================================================
% LOAD NIFTI ROI (FROM ITK-SNAP)
% =========================================================
roiPath = 'Z:\ember_lab\mindbeam_roi.nii.gz'; % adjust to specific roi .nii file 
distThresh = 5;   % needs adjustment (in voxels)

roiFileExists = exist(roiPath) == 2;

if roiFileExists
    nii = niftiread(roiPath);
    info = niftiinfo(roiPath);
    
    roiMask = nii > 0;   % assume binary or labeled mask
    
    % Extract affine (voxel -> MNI)
    transform = info.Transform.T;
    
    % Get mask voxel indices
    [i,j,k] = ind2sub(size(roiMask), find(roiMask));
    vox = [i j k ones(size(i))];
    
    mni_coords = vox * transform;
    mni_coords = mni_coords(:,1:3);
else
    warning("ROI.nii not found. Exporting table without ROI classification...")
end

%% ----------------------------%
% Loop projects                %
%------------------------------%
for i = 1:numel(projects)

    proj = projects{i};
    [~, subjName] = fileparts(proj);

    fprintf("\n--- Processing %s ---\n", subjName);

    try
        %% ============================
        % LOAD SUBJECT SPACE
        %==============================
        dataPath = fullfile(proj, "DataOutput","brain.mat");
        dataPathMNI = fullfile(proj, "DataOutput","MNIbrain.mat");

        % Load subject electrode data
        if ~isfile(dataPath)
            warning("Missing brain.mat for %s", subjName);
            continue;
        end
        S = load(dataPath,'electrodes');
        electrodes = S.electrodes;

        % Load MNI electrode data
        if isfile(dataPathMNI)
            S2 = load(dataPathMNI,'surfaceModel','electrodes');
            electrodesMNI = S2.electrodes;
            surfaceModel = S2.surfaceModel;
        else
            warning("Missing MNIbrain.mat for %s", subjName);
            electrodesMNI.Location = electrodes.Location;
            electrodesMNI.Location(:,:) = NaN;
        end
        
        %% ============================
        % COMPUTE INCLUSION
        %==============================
        ROI = zeros(1,height(electrodes.Location));

        if roiFileExists
            % Convert electrode coords (MNI) -> voxel space
            coords = electrodesMNI.Location;
            coords_h = [coords ones(size(coords,1),1)];
            invT = inv(transform);
            vox_coords = coords_h * invT;
            vox_coords = round(vox_coords(:,1:3));  % nearest voxel
            vox_coords = round(vox_coords);

            % bounds check
            valid = ...
                vox_coords(:,1) >= 1 & vox_coords(:,1) <= size(roiMask,1) & ...
                vox_coords(:,2) >= 1 & vox_coords(:,2) <= size(roiMask,2) & ...
                vox_coords(:,3) >= 1 & vox_coords(:,3) <= size(roiMask,3);
            
            distMap = bwdist(roiMask);
            inROI = false(size(coords,1),1);
            nearROI = false(size(coords,1),1);
            
            for idx = find(valid)'
            
                x = vox_coords(idx,1);
                y = vox_coords(idx,2);
                z = vox_coords(idx,3);
            
                if roiMask(x,y,z)
                    inROI(idx) = true;
                elseif distMap(x,y,z) <= distThresh
                    nearROI(idx) = true;
                end
            end
            ROI(inROI) = "2";
            ROI(nearROI) = "1";
        end

        subjectTable = buildElectrodeTable(electrodes, electrodesMNI,ROI);
        %% ============================
        % VISUALIZATION
        %==============================
        fig = figure('Position',[100 100 1000 700]);
        tiles = tiledlayout(2,2);

        tile = nexttile(tiles);
        ax(1,1) = plotBrain(tile, surfaceModel, coords, 180, 0, false);
        tile = nexttile(tiles);
        ax(1,2) = plotBrain(tile, surfaceModel, coords, -90, 0, false);
        tile = nexttile(tiles);
        ax(2,1) = plotBrain(tile, surfaceModel, coords, 0, 90, false);
        tile = nexttile(tiles);
        ax(2,2) = plotBrain(tile, surfaceModel, coords, -45, 45, true);

        if roiFileExists
            ax(1,1) = plotROI(ax(1,1), roiMask, transform);
            ax(1,1) = plotROIElectrodes(ax(1,1), coords, nearROI, inROI);
            ax(1,2) = plotROI(ax(1,2), roiMask, transform);
            ax(1,2) = plotROIElectrodes(ax(1,2), coords, nearROI, inROI);
            ax(2,1) = plotROI(ax(2,1), roiMask, transform);
            ax(2,1) = plotROIElectrodes(ax(2,1), coords, nearROI, inROI);
            ax(2,2) = plotROI(ax(2,2), roiMask, transform);
            ax(2,2) = plotROIElectrodes(ax(2,2), coords, nearROI, inROI);
        
            sgtitle(sprintf('%s: Red=In (%d) | Yellow=Near (%d) | Total=%d', ...
                subjName, sum(inROI), sum(nearROI), numel(inROI)))
        end
        %% ============================
        % WRITE OUTPUT
        %==============================
        outFile = fullfile(proj, subjName + "_ElectrodeCoordinates.xlsx");
        outPlot = fullfile(proj, subjName + "_ElectrodeRegionsROI.png");

        if isfile(outFile); delete(outFile); end
        if isfile(outPlot); delete(outPlot); end

        writetable(subjectTable, outFile, 'Sheet', 'coordinates');
        exportgraphics(fig, outPlot, 'Resolution',300);

        fprintf("[✓] Saved: %s\n", outFile);
        fprintf("[✓] Saved: %s\n", outPlot);

    catch ME
        warning("Failed for %s: %s", subjName, ME.message);
        continue;
    end
end

fprintf("\n[✓] Export complete.\n");

%% =======================================================================
% FUNCTION: buildElectrodeTable
%=========================================================================

function T = buildElectrodeTable(electrodes, mniElectrodes, ROI)

    n = size(electrodes.Location,1);
        
    % Check if sizes of electrode and mni electrodes is the same 
    % If this throws an error, something in the imaging/file loading has
    % failed.
    if n ~= size(mniElectrodes.Location,1)
        error("Dimension mismatch for electrode and mni electrode coordinate tables.")
    end

    %------------------------------
    % Initialize table
    %------------------------------
    T = table();

    % Contact index
    T.contact_index = (1:n)';
    
    % Contact name
    ids = electrodes.DefinitionIdentifier;
    chidx = arrayfun(@(i) sum(ids(1:i) == ids(i)), 1:numel(ids));
    defNames = arrayfun(@(id) electrodes.Definition(id).Name, ids, 'UniformOutput', false);
    T.contact_name = strcat(defNames, string(chidx)');

    %------------------------------
    % Electrode group (Definition)
    %------------------------------
    def_names = strings(n,1);

    if isfield(electrodes,'Definition') && isfield(electrodes,'DefinitionIdentifier')
        defs = electrodes.Definition;
        def_idx = electrodes.DefinitionIdentifier;

        for i = 1:n
            if def_idx(i) > 0 && def_idx(i) <= numel(defs)
                def_names(i) = string(defs(def_idx(i)).Name);
            end
        end
    end

    T.electrode_group = def_names;

    %------------------------------
    % Prepare electrode coordinates
    %------------------------------
    % Coordinates
    T.x = electrodes.Location(:,1);
    T.y = electrodes.Location(:,2);
    T.z = electrodes.Location(:,3);

    % MNI oordinates
    T.mniX = mniElectrodes.Location(:,1);
    T.mniY = mniElectrodes.Location(:,2);
    T.mniZ = mniElectrodes.Location(:,3);

    % ----------------------------
    % ROI labeling using custom region
    % ----------------------------
    ROI_flag = strings(n,1);

    for i = 1:n
        label = ROI(i);

        if label == 0
            ROI_flag(i) = "N";

        elseif label == 1
            ROI_flag(i) = "Review";

        elseif label == 2
            ROI_flag(i) = "Y";

        else
            ROI_flag(i) = "Unknown";

        end
    end
    T.ROI_flag = ROI_flag;

    % %------------------------------%
    % % FreeSurfer label (Annotation)
    % %------------------------------%
    % if isfield(electrodes,'Label')
    %     T.fs_label = string(electrodes.Label(:));
    % else
    %     T.fs_label = strings(n,1);
    % end
    % 
    % % ----------------------------
    % % ROI labeling using FreeSurfer
    % % ----------------------------
    % ROI_flag = strings(n,1);
    % 
    % for i = 1:n
    % 
    %     label = T.fs_label(i);
    % 
    %     if label == "" || label == "Unknown"
    %         ROI_flag(i) = "Unknown";
    % 
    %     elseif any(contains(lower(label), lower(roiRegions)))
    %         ROI_flag(i) = "Y";
    % 
    %     elseif any(contains(lower(label), ["unknown","white","wm"]))
    %         ROI_flag(i) = "Review";
    % 
    %     else
    %         ROI_flag(i) = "N";
    % 
    %     end
    % end
    % T.ROI_flag = ROI_flag;

    %% Close oldest figures if looping
    figs = findall(0, 'Type', 'figure');

    if numel(figs) > 5
        close(figs(6:end))   % keeps the 5 most recent
    end
end


%% =======================================================================
% FUNCTION: plotBrain
%=========================================================================

function ax = plotBrain(ax, surfaceModel, coords, az, el, color)
        hold on; axis equal off;
        view(az,el); camlight; lighting gouraud;
        
        [annotation,cmap] = makeColormap(surfaceModel,0);
        if ~color
            cmap = cmap2gray(cmap);
        end
        vSurf = plotModel(ax,surfaceModel.Model,annotation,cmap,[]);
        set(vSurf,'EdgeColor','none');
        alpha(vSurf,0.05);
        
        % electrodes
        scatter3(ax,coords(:,1),coords(:,2),coords(:,3),25,'b','filled');

end

function ax = plotROI(ax, roiMask, T)
    fv = isosurface(roiMask, 0.5);
    
    % convert vertices to MNI
    V = fv.vertices;
    V = [V(:,2), V(:,1), V(:,3)];
    V = [V ones(size(V,1),1)];
    V = V * T;
    fv.vertices = V(:,1:3);
    
    roiPatch = patch(ax, fv);
    set(roiPatch, ...
        'FaceColor', [1 0 0], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.1);   % transparency
end

function ax = plotROIElectrodes(ax, coords, nearROI, inROI)
    colors = repmat([0 0.6 1], size(coords,1), 1);   % blue (outside)

    colors(nearROI,:) = repmat([1 1 0], sum(nearROI), 1); % yellow
    colors(inROI,:)   = repmat([1 0 0], sum(inROI), 1);   % red overrides

    scatter3(ax,coords(:,1),coords(:,2),coords(:,3),40,colors,'filled');
end