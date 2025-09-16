% startup_MultiViewer.m
addpath(genpath('Tools/MultiviewerFileFunctions'));
addpath('classes/GUI/Views')
projects = selectProjectFolders();
if isempty(projects)
    disp('No projects selected.')
end

subjectDataMap = containers.Map();
surfaceModel = [];
for i=1:numel(projects)
    proj = projects{i};
    mni = fullfile(proj,'DataOutput/MNIbrain.mat');
    if isempty(surfaceModel)
        load(mni,'surfaceModel');
    end
    load(mni,'electrodes');

    % format data to make VERA happy
    elDef.Definition = electrodes.Definition;
    elDef.Name = 'ElectrodeDefinition';

    elPos = rmfield(electrodes,'Definition');

    subj.ElectrodePositions = elPos;
    subj.ElectrodeDefinitions = elDef;
    
    subjName = sprintf("Subject%d",i);
    subjectDataMap(subjName) = subj;
end

% === Launch the viewer ===
viewer = MultiSuperViewer(surfaceModel,subjectDataMap);