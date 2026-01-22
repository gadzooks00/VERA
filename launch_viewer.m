clear appearanceDialog
addpath(genpath('FileFunctions'));

projects = selectProjectFolders();
if isempty(projects)
    disp('No projects selected.')
end

subjectDataMap = containers.Map();
surfaceModel = [];

n_proj = numel(projects);
surf_idx = randi(n_proj);

for i=1:n_proj
    proj = projects{i};
    if i == surf_idx
        % This subject provides the surface
        [subj, surfaceModel] = loadSubj(~isscalar(projects), proj);
    else
        % All others load without surface
        [subj, ~] = loadSubj(true, proj);
    end
    [~,subjName] = fileparts(proj);
    subjectDataMap(subjName) = subj;
end

% === Launch the viewer ===
viewer = Super3DView(surfaceModel,subjectDataMap);
%else
%    [subj,surface] = loadSubj(false, projects{1});

%    viewer = SingleSuperView(surface,subj);
%end

function [subj,surface]=loadSubj(mni,proj)
dir = "DataOutput/";
if mni
    dir = dir + "MNIbrain.mat";
else
    dir = dir + "brain.mat";
end
data = fullfile(proj,dir);
load(data,'surfaceModel');
surface = surfaceModel;

load(data,'electrodes');
% format data to make VERA happy
elDef.Definition = electrodes.Definition;
elDef.Name = 'ElectrodeDefinition';

elPos = rmfield(electrodes,'Definition');

subj.ElectrodePositions = elPos;
subj.ElectrodeDefinitions = elDef;
end