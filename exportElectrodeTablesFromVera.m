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

roiRegions = [
    "orbitofrontal";
    "parstriangularis";
    "parsorbitalis";
    "superiortemporal";
    "middletemporal";
    "supramarginal";
    "middlefrontal";
    "transversetemporal";
    "inferiortemporal"
];

%% ----------------------------%
% Select project folders       %
%------------------------------%
projects = selectProjectFolders();

if isempty(projects)
    disp('No projects selected.');
    return;
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
        dataPath = fullfile(proj, "DataOutput", "brain.mat");

        if ~isfile(dataPath)
            warning("Missing brain.mat for %s", subjName);
            continue;
        end

        S = load(dataPath, 'electrodes');
        electrodes = S.electrodes;

        subjectTable = buildElectrodeTable(electrodes, roiRegions);

        %% ============================
        % LOAD MNI SPACE
        %==============================
        dataPathMNI = fullfile(proj, "DataOutput", "MNIbrain.mat");

        if isfile(dataPathMNI)
            S2 = load(dataPathMNI, 'electrodes');
            electrodesMNI = S2.electrodes;

            mniTable = buildElectrodeTable(electrodesMNI, roiRegions);
        else
            warning("Missing MNIbrain.mat for %s", subjName);
            mniTable = subjectTable;
            mniTable.x(:) = NaN;
            mniTable.y(:) = NaN;
            mniTable.z(:) = NaN;
        end

        %% ============================
        % WRITE EXCEL
        %==============================
        outFile = fullfile(proj, subjName + "_ElectrodeCoordinates.xlsx");

        if isfile(outFile)
            delete(outFile);
        end

        writetable(subjectTable, outFile, 'Sheet', 'subject_space');
        writetable(mniTable,     outFile, 'Sheet', 'mni_space');

        fprintf("[✓] Saved: %s\n", outFile);

    catch ME
        warning("Failed for %s: %s", subjName, ME.message);
        continue;
    end
end

fprintf("\n[✓] Export complete.\n");

%% =======================================================================
% FUNCTION: buildElectrodeTable
%=========================================================================

function T = buildElectrodeTable(electrodes, roiRegions)

    n = size(electrodes.Location,1);

    %------------------------------
    % Initialize table
    %------------------------------
    T = table();

    % Contact index and name
    T.contact_index = (1:n)';
    T.contact_name = string(electrodes.Name(:));

    % Coordinates
    T.x = electrodes.Location(:,1);
    T.y = electrodes.Location(:,2);
    T.z = electrodes.Location(:,3);

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

    %------------------------------%
    % FreeSurfer label (Annotation)
    %------------------------------%
    if isfield(electrodes,'Label')
        T.fs_label = string(electrodes.Label(:));
    else
        T.fs_label = strings(n,1);
    end

    % ----------------------------
    % ROI labeling using FreeSurfer
    % ----------------------------
    ROI_flag = strings(n,1);

    for i = 1:n

        label = T.fs_label(i);

        if label == "" || label == "Unknown"
            ROI_flag(i) = "Unknown";

        elseif any(contains(lower(label), lower(roiRegions)))
            ROI_flag(i) = "Y";

        elseif any(contains(lower(label), ["unknown","white","wm"]))
            ROI_flag(i) = "Review";
        
        else
            ROI_flag(i) = "N";

        end
    end
    T.ROI_flag = ROI_flag;
end
