classdef FreesurferModelGeneration < AComponent
    %FreesurferModelGeneration Run Freesurfer segmentation within VERA

    properties
        MRIIdentifier %Input MRI Data Identifier
        SurfaceIdentifier %Output Surface Data Identifier
        SphereIdentifier %Output Sphere Surface Volume Identifier (will start with L_ and R_ )
        AnnotationType
        SegmentationPathIdentifier
        SurfaceType
    end
    properties (Dependent, Access = protected)
        LeftSphereIdentifier
        RightSphereIdentifier
    end

    methods

        function obj = FreesurferModelGeneration()
            obj.MRIIdentifier='MRI';
            obj.SurfaceIdentifier='Surface';
            obj.SphereIdentifier='Sphere';
            obj.AnnotationType='aparc';
            obj.SegmentationPathIdentifier='SegmentationPath';
            obj.SurfaceType='pial';
        end

        function value=get.LeftSphereIdentifier(obj)
            value=['L_' obj.SphereIdentifier];
        end
        function value=get.RightSphereIdentifier(obj)
            value=['R_' obj.SphereIdentifier];
        end

        function Publish(obj)
            obj.AddInput(obj.MRIIdentifier,'Volume');
            obj.AddOutput(obj.SurfaceIdentifier,'Surface');
            obj.AddOutput(obj.LeftSphereIdentifier,'Surface');
            obj.AddOutput(obj.RightSphereIdentifier,'Surface');
            obj.AddOutput(obj.SegmentationPathIdentifier,'PathInformation');
        end
        function Initialize(obj)
            path=obj.GetDependency('Freesurfer');
            addpath(fullfile(path,'matlab'));
            if(ispc)
                obj.GetDependency('UbuntuSubsystemPath');
                if(system('WHERE bash >nul 2>nul echo %ERRORLEVEL%') == 1)
                    error('If you want to use Freesurfer components on windows, the Windows 10 Ubuntu subsystem is required!');
                else
                    disp('Found ubuntu subsystem on Windows 10!');
                    disp('This Component requires GUI Access to freeview, make sure you can run freeview from the Linux subsystem (requires Xserver installed on windows)');
                end
            end

        end

        function [surf,lsphere,rsphere,pathInfo] = Process(obj,mri)
            segmentationFolder=obj.ComponentPath;
            mri_path=GetFullPath(mri.Path);
            freesurferPath=obj.GetDependency('Freesurfer');
            recon_script=fullfile(fileparts(fileparts(mfilename('fullpath'))),'/scripts/importdata_recon-all.sh');
            flatten_script=fullfile(fileparts(fileparts(mfilename('fullpath'))), '/scripts/flatten_symlinks.sh');
            segmentationPath=fullfile(segmentationFolder,'Segmentation');

            %----------------------------------------------------------------------
            % [MODIFIED] Use WSL-local working directory for Freesurfer if on Windows
            %----------------------------------------------------------------------
            if ispc
                subsyspath = obj.GetDependency('UbuntuSubsystemPath');

                % Get WSL user's home directory
                [~, wsl_home] = systemWSL('echo $HOME', '-echo');
                wsl_home = strtrim(wsl_home);

                % Define WSL-local temp directory
                temp_segmentation_dir = sprintf('%s/freesurfer_temp', wsl_home);

                % Ensure directory exists in WSL filesystem
                mkdir_cmd = sprintf('mkdir -p "%s"', temp_segmentation_dir);
                systemWSL(mkdir_cmd, '-echo');

                % Convert MATLAB paths to WSL
                w_recon_script = convertToUbuntuSubsystemPath(recon_script, subsyspath);
                w_flatten_script = convertToUbuntuSubsystemPath(flatten_script, subsyspath);
                w_freesurferPath = convertToUbuntuSubsystemPath(freesurferPath, subsyspath);
                w_mripath = convertToUbuntuSubsystemPath(mri_path, subsyspath);

                % Run segmentation if needed
                if (~exist(segmentationPath, 'dir') || ...
                        (exist(segmentationPath, 'dir') && ...
                        strcmp(questdlg('Found an Existing Segmentation Folder! Do you want to rerun the Segmentation?', ...
                        'Rerun Segmentation?', 'Yes', 'No', 'No'), 'Yes')))
                    disp('Running Freesurfer segmentation in WSL-local temp dir. This might take up to 24h.');

                    % Remove old target segmentation if it exists
                    if exist(segmentationPath, 'dir')
                        rmdir(segmentationPath, 's');
                    end

                    % Clear any previous Segmentation folder inside WSL temp
                    clear_temp_subject = sprintf('rm -rf "%s/Segmentation"', temp_segmentation_dir);
                    systemWSL(clear_temp_subject, '-echo');

                    % Run recon-all script in WSL-local path
                    systemWSL(['chmod +x "' w_recon_script '"'], '-echo');
                    shellcmd = ['"' w_recon_script '" "' w_freesurferPath '" "' ...
                        temp_segmentation_dir '" Segmentation "' w_mripath '"'];
                    systemWSL(shellcmd, '-echo');

                    % Flatten symbolic links in temp_segmentation_dir
                    systemWSL(['chmod +x "' w_flatten_script '"'], '-echo');
                    flatten_cmd = ['"' w_flatten_script '" "' temp_segmentation_dir '"'];
                    systemWSL(flatten_cmd, '-echo');
                    
                    % Remove troublesome average file
                    remove_fsaverage_cmd = sprintf('rm -rf "%s/Segmentation/fsaverage"', temp_segmentation_dir);
                    systemWSL(remove_fsaverage_cmd, '-echo');

                    % Copy output back from WSL-local temp directory to expected path
                    copy_cmd = sprintf('cp -r "%s/Segmentation" "%s/"', ...
                        temp_segmentation_dir, convertToUbuntuSubsystemPath(segmentationFolder, subsyspath));
                    systemWSL(copy_cmd, '-echo');
                end
            else
                if (~exist(segmentationPath, 'dir') || ...
                        (exist(segmentationPath, 'dir') && ...
                        strcmp(questdlg('Found an Existing Segmentation Folder! Do you want to rerun the Segmentation?', ...
                        'Rerun Segmentation?', 'Yes', 'No', 'No'), 'Yes')))
                    disp('Running Freesurfer segmentation, this might take up to 24h, get a coffee...');
                    if exist(segmentationPath, 'dir')
                        rmdir(segmentationPath, 's');
                    end
                    system(['chmod +x "' recon_script '"'], '-echo');
                    shellcmd = [recon_script ' "' freesurferPath '" "' ...
                        segmentationFolder '" Segmentation "' mri_path '"'];
                    system(shellcmd, '-echo');
                end
            end

            [surf_model,lsphere_model,rsphere_model]=loadFSModelFromSubjectDir(freesurferPath,segmentationPath,GetFullPath(obj.ComponentPath),obj.AnnotationType,obj.SurfaceType);
            surf=obj.CreateOutput(obj.SurfaceIdentifier);
            surf.Model=surf_model.Model;
            surf.Annotation=surf_model.Annotation;
            surf.AnnotationLabel=surf_model.AnnotationLabel;

            lsphere=obj.CreateOutput(obj.LeftSphereIdentifier);
            lsphere.Model=lsphere_model.Model;
            lsphere.Annotation=lsphere_model.Annotation;
            lsphere.AnnotationLabel=lsphere_model.AnnotationLabel;

            rsphere=obj.CreateOutput(obj.RightSphereIdentifier);
            rsphere.Model=rsphere_model.Model;
            rsphere.Annotation=rsphere_model.Annotation;
            rsphere.AnnotationLabel=rsphere_model.AnnotationLabel;
            pathInfo=obj.CreateOutput(obj.SegmentationPathIdentifier);
            [~,b]=fileparts(obj.ComponentPath);
            pathInfo.Path=fullfile('./',b,'Segmentation');
        end
    end
end

