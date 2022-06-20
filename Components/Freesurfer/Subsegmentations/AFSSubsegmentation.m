classdef (Abstract) AFSSubsegmentation < AComponent
    %A Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        VolumeIdentifier
        SegmentationPathIdentifier
    end

    properties (Access=protected, Abstract)
        ShellScriptName
        LVolumeName %Volume of left hemisphere segmentation
        RVolumeName %Volume of right hemisphere segmentation, if both have the same name it is assumed to be single volume
    end
    
    methods
        function obj = AFSSubsegmentation()
            obj.SegmentationPathIdentifier='SegmentationPath';
        end
        
        function Publish(obj)
            obj.AddOptionalInput(obj.SegmentationPathIdentifier,'PathInformation',true);
            if(strcmp(obj.LVolumeName,obj.RVolumeName))
                obj.AddOutput(obj.VolumeIdentifier,'Volume');
            else
                obj.AddOutput(['L' obj.VolumeIdentifier],'Volume');
                obj.AddOutput(['R' obj.VolumeIdentifier],'Volume');
            end

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
               end
            end
        end

        function varargout=Process(obj,optInp)
            if(nargin > 1) %segmentation path exists
                segmentationPath=optInp.Path;
                comPath=fileparts(obj.ComponentPath);
                segmentationPath=fullfile(comPath,segmentationPath); %create full path
            else
                segmentationPath=uigetdir([],'Please select Freesurfer Segmentation');
                if(isempty(segmentationPath))
                    error('No path selected!');
                end
            end
            LfileName=fullfile(segmentationPath,'mri',obj.LVolumeName);
            RfileName=fullfile(segmentationPath,'mri',obk.RVolumeName);

            freesurferPath=obj.GetDependency('Freesurfer');
            if(~exist(LfileName,'file') || ~exist(RfileName,'file'))
                
                recon_script=fullfile(fileparts(fileparts(mfilename('fullpath'))),'scripts',obj.ShellScriptName);
                [segmentationPath,subj_name]=fileparts(segmentationPath);
                if(ispc)
                    subsyspath=obj.GetDependency('UbuntuSubsystemPath');
                    wsl_segm_path=convertToUbuntuSubsystemPath(segmentationPath,subsyspath);
                    wsl_recon_script=convertToUbuntuSubsystemPath(recon_script,subsyspath);
                    w_freesurferPath=convertToUbuntuSubsystemPath(freesurferPath,subsyspath);
                    systemWSL(['chmod +x ''' wsl_recon_script ''''],'-echo');
                    shellcmd=['''' wsl_recon_script ''' ''' w_freesurferPath ''' ''' ...
                    wsl_segm_path ''' ' ...
                    '''' subj_name ''''];
                    systemWSL(shellcmd,'-echo');
                else
                    system(['chmod +x ''' recon_script ''''],'-echo');
                    shellcmd=['''' recon_script ''' ''' freesurferPath ''' ''' ...
                    segmentationPath ''' ' ...
                    '''' subj_name ''''];
                    system(shellcmd,'-echo');
                end
            end
            if(~exist(LfileName,'file') || ~exist(RfileName,'file'))
                error('Error - no output files generated after running segmentation!');
            end
            if(strcmp(obj.LVolumeName,obj.RVolumeName))
                nii_path=createTempNifti(LfileName,obj.GetDependency('TempPath'),freesurferPath);
                varargout{1}=obj.CreateOutput(obj.VolumeIdentifier);
                varargout{1}.LoadFromFile(nii_path);
                delete(nii_path);
            else
                nii_path=createTempNifti(LfileName,obj.GetDependency('TempPath'),freesurferPath);
                varargout{1}=obj.CreateOutput(['L' obj.VolumeIdentifier]);
                varargout{1}.LoadFromFile(nii_path);
                delete(nii_path);
                nii_path=createTempNifti(RfileName,obj.GetDependency('TempPath'),freesurferPath);
                varargout{2}=obj.CreateOutput(['R' obj.VolumeIdentifier]);
                varargout{2}.LoadFromFile(nii_path);   
                delete(nii_path);
            end
        end
    end
end

