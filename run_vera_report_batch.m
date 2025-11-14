function summary_tbl = run_vera_report_batch(root_dir, out_dir, overwrite)
%--------------------------------------------------------------------------
% run_vera_report_batch - Headless batch generator for VERA ReportGenerator
%
% PURPOSE
%   Iterate over subject folders (P*) under ROOT_DIR, open each VERA
%   project, configure pipeline, and run ONLY the "ReportGenerator"
%   component—without any GUI interaction. PowerPoint outputs are saved to:
%       OUT_DIR / P# / sub-P#_report_summary.pptx
%
% INPUTS
%   root_dir  : char/str, parent folder containing P# projects
%   out_dir   : char/str, destination base folder for pptx outputs
%   overwrite : logical, true to overwrite existing reports
%
% OUTPUT
%   summary_tbl : table with per-subject status and output path
%
% Zane-style notes
%   - Variables are snake_case; functions are camelCase.
%   - Minimal “one-off” functions: everything is inline except this wrapper.
%   - Dependency/toolbox checks at top; errors are explicit and actionable.
%--------------------------------------------------------------------------

%======================== USER PARAMETERS (quick edit) =====================
if nargin < 1 || isempty(root_dir)
    root_dir = 'Z:\imaging_data\output_VERA';   % <-- EDIT ME
end
if nargin < 2 || isempty(out_dir)
    out_dir  = fullfile(root_dir);       % default next to projects
end
if nargin < 3 || isempty(overwrite)
    overwrite = false;
end
%==========================================================================

%----- sanity & toolboxes --------------------------------------------------
req_toolboxes = { ...
    'Computer Vision Toolbox', ...
    'Image Processing Toolbox', ...
    'MATLAB Report Generator', ...
    'Statistics and Machine Learning Toolbox' ...
};
v = ver; vstr = struct2cell(v);
for q = 1:numel(req_toolboxes)
    if ~any(contains(vstr, req_toolboxes{q}))
        error('Missing required toolbox: %s', req_toolboxes{q});
    end
end

%----- add VERA paths (mirror startup_VERA without bringing up GUI) --------
addpath(genpath('classes'));
addpath(genpath('Components'));
addpath(genpath('Dependencies'));
addpath(genpath('PipelineDesigner'));
warning off
if exist('Dependencies/Widgets Toolbox/resource/MathWorksConsultingWidgets.jar','file')
    javaaddpath('Dependencies/Widgets Toolbox/resource/MathWorksConsultingWidgets.jar');
end
import uiextras.jTree.* %#ok<NUSED>
warning on

% Load settings.xml if present (matches MainGUI behavior)
if exist('settings.xml','file')
    rootpath_guess = GetFullPath(fullfile(fileparts(mfilename('fullpath')),'..','..'));
    if exist(fullfile(rootpath_guess,'settings.xml'),'file')
        DependencyHandler.Instance.LoadDependencyFile(fullfile(rootpath_guess,'settings.xml'));
    else
        DependencyHandler.Instance.LoadDependencyFile(fullfile(pwd,'settings.xml'));
    end
end

%----- ensure output base exists ------------------------------------------
if ~isfolder(out_dir)
    mkdir(out_dir);
end

%----- build subject list --------------------------------------------------
dir_info = dir(fullfile(root_dir, 'P*'));
is_subject = [dir_info.isdir] & ~ismember({dir_info.name},{'.','..'});
subjects = {dir_info(is_subject).name};

%----- create a temporary uiputfile shim to suppress GUI ------------------
shim_dir = fullfile(tempdir, ['uiputfile_shim_' char(java.util.UUID.randomUUID())]);
mkdir(shim_dir);
fid = fopen(fullfile(shim_dir,'uiputfile.m'),'w');
% This shim captures the intended "default_path" and ignores it, returning:
%   [fname, pth] =  (BATCH_REPORT_FILENAME, fullfile(BATCH_REPORT_OUTDIR, BATCH_REPORT_SUBJECT))
fprintf(fid, 'function [fname, pth] = uiputfile(default_path, varargin)\n');
fprintf(fid, 'outdir = getenv(''BATCH_REPORT_OUTDIR'');\n');
fprintf(fid, 'subj   = getenv(''BATCH_REPORT_SUBJECT'');\n');
fprintf(fid, 'force  = getenv(''BATCH_REPORT_FILENAME'');\n');
fprintf(fid, 'if isempty(force)\n');
fprintf(fid, '  [~,base,ext] = fileparts(default_path);\n');
fprintf(fid, '  fname = [base ext];\n');
fprintf(fid, 'else\n');
fprintf(fid, '  fname = force;\n');
fprintf(fid, 'end\n');
fprintf(fid, 'if ~isempty(outdir) && ~isempty(subj)\n');
fprintf(fid, '  pth = fullfile(outdir, subj, filesep);\n');
fprintf(fid, '  if ~exist(pth,''dir''), mkdir(pth); end\n');
fprintf(fid, 'else\n');
fprintf(fid, '  pth = [fileparts(default_path) filesep];\n');
fprintf(fid, 'end\n');
fclose(fid);
addpath(shim_dir, '-begin');  % ensure our shim is found before MATLAB's

%----- batch loop ----------------------------------------------------------
n = numel(subjects);
status   = strings(n,1);
ppt_path = strings(n,1);
message  = strings(n,1);

for i = 1:n
    subj_id  = subjects{i};                     % e.g., 'P14'
    subj_dir = fullfile(root_dir, subj_id);
    dest_dir = fullfile(out_dir,  subj_id);
    if ~isfolder(dest_dir), mkdir(dest_dir); end

    target_name = sprintf('%s_Report-summary.pptx', subj_id);
    target_path = fullfile(dest_dir, target_name);

    % Skip if already exists (unless overwrite)
    if ~overwrite && exist(target_path,'file')
        status(i)   = "skipped";
        ppt_path(i) = string(target_path);
        message(i)  = "Report exists";
        continue;
    end

    % Route ReportGenerator's uiputfile() to our desired name/location
    setenv('BATCH_REPORT_OUTDIR',  out_dir);
    setenv('BATCH_REPORT_SUBJECT', subj_id);
    setenv('BATCH_REPORT_FILENAME', target_name);

    try
        % Open project headlessly (equivalent to MainGUI.openProject path)
        [prj, pwf_file] = Project.OpenProjectFromPath(subj_dir); %#ok<NASGU>
        runner = Runner.CreateFromProject(prj);

        % Configure all components (mirrors MainGUI.configureAll, simplified)
        comps = runner.Components;
        for c = 1:numel(comps)
            runner.ConfigureComponent(comps{c});
        end

        % Run ONLY the ReportGenerator component (no GUI)
        embertools.utils.sendNotification(string(subj_id) + " Report Generator need to be configured");
        runner.RunComponent('Report Generator MRI');

        % Verify output exists where we forced it
        if exist(target_path,'file')
            status(i)   = "ok";
            ppt_path(i) = string(target_path);
            message(i)  = "Generated";
        else
            status(i)   = "error";
            ppt_path(i) = "";
            message(i)  = "Process completed but pptx not found (shim or path issue).";
        end

    catch ME
        status(i)   = "error";
        ppt_path(i) = "";
        message(i)  = "Failure: " + string(ME.message);
        % Continue to next subject
    end
end

%----- cleanup shim path ---------------------------------------------------
rmpath(shim_dir);
try
    rmdir(shim_dir,'s');
catch
end

%----- summary table -------------------------------------------------------
summary_tbl = table(string(subjects(:)), status, ppt_path, message, ...
    'VariableNames', {'subject_id','status','pptx_path','message'});

% Also echo to command window
disp(summary_tbl);

end
