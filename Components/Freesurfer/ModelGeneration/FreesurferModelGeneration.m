classdef FreesurferModelGeneration < AComponent
    %FreesurferModelGeneration Run Freesurfer segmentation 
    
    properties
        MRIIdentifier %Input MRI Data Identifier
        SurfaceIdentifier %Output Surface Data Identifier
        SphereIdentifier %Output Sphere Surface Volume Identifier (will start with L_ and R_ )
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
        
        function [surf,lsphere,rsphere] = Process(obj,mri)
                 segmentationFolder=obj.ComponentPath;
                 mri_path=GetFullPath(mri.Path);
                freesurferPath=obj.GetDependency('Freesurfer');
                recon_script=fullfile(fileparts(fileparts(mfilename('fullpath'))),'/scripts/importdata_recon-all.sh');
                segmentationPath=fullfile(segmentationFolder,'Segmentation');
                if(~exist(segmentationPath,'dir') || (exist(segmentationPath,'dir') && strcmp(questdlg('Found an Existing Segmentation Folder! Do you want to rerun the Segmentation?','Rerun Segmentation?','Yes','No','No'),'Yes')))
                    disp('Running Freesurfer segmentation, this might take up to 24h, get a coffee...');
                    if(exist(segmentationPath,'dir')) 
                        rmdir(segmentationPath,'s'); 
                    end
                    if(ispc)
                        subsyspath=obj.GetDependency('UbuntuSubsystemPath');
                        w_recon_script=convertToUbuntuSubsystemPath(recon_script,subsyspath);
                        w_freesurferPath=convertToUbuntuSubsystemPath(freesurferPath,subsyspath);
                        w_segmentationFolder=convertToUbuntuSubsystemPath(segmentationFolder,subsyspath);
                        w_mripath=convertToUbuntuSubsystemPath(mri_path,subsyspath);
                        systemWSL(['chmod +x ''' w_recon_script ''''],'-echo');
                        shellcmd=['''' w_recon_script ''' ''' w_freesurferPath ''' ''' ...
                        w_segmentationFolder ''' ' ...
                        'Segmentation ''' w_mripath ''''];
                        systemWSL(shellcmd,'-echo');
                    else
                        system(['chmod +x ''' recon_script ''''],'-echo');
                        shellcmd=[recon_script ' ''' freesurferPath ''' ''' ...
                        segmentationFolder ''' ' ...
                        'Segmentation ''' mri_path ''''];
                        system(shellcmd,'-echo');
                    end
                end
                

                surf=obj.CreateOutput(obj.SurfaceIdentifier);
                freesurferPath=obj.GetDependency('Freesurfer');
                xfrm_matrix_path=[fileparts(fileparts(mfilename('fullpath'))) '/scripts/get_xfrm_matrices.sh'];
                xfrm_matrix_out_path=GetFullPath(obj.ComponentPath);
                mri_path=fullfile(segmentationPath,'mri/orig.mgz');
                if(ismac || isunix)
                    system(['chmod +x ''' xfrm_matrix_path ''''],'-echo');
                    system([xfrm_matrix_path ' ''' freesurferPath ''' ''' ...
                    mri_path ''' ''' ...
                    xfrm_matrix_out_path ''''],'-echo');
                elseif(ispc)
                    subsyspath=obj.GetDependency('UbuntuSubsystemPath');
                    w_xfrm_matrix_path=convertToUbuntuSubsystemPath(xfrm_matrix_path,subsyspath);
                    w_freesurferPath=convertToUbuntuSubsystemPath(freesurferPath,subsyspath);
                    w_mri_path=convertToUbuntuSubsystemPath(mri_path,subsyspath);
                    w_xfrm_matrix_out_path=convertToUbuntuSubsystemPath(xfrm_matrix_out_path,subsyspath);
                    systemWSL(['chmod +x ''' w_xfrm_matrix_path ''''],'-echo');
                    systemWSL(['''' w_xfrm_matrix_path ''' ''' w_freesurferPath ''' ''' ...
                    w_mri_path ''' ''' ...
                    w_xfrm_matrix_out_path ''''],'-echo'); 
                else
                    error('Couldnt determine operating system');
                end

                xfrm_matrices=importdata(fullfile(xfrm_matrix_out_path,'xfrm_matrices'));
                vox2ras = xfrm_matrices(1:4, :);
                vox2rastkr = xfrm_matrices(5:8, :);

                %freesurfer 7 works with symlinks which cannot be resolved
                %under windows so we need to get the correct target
                if(ispc)
                    pathToLhPial=resolveWSLSymlink(fullfile(segmentationPath,'surf/lh.pial'),subsyspath);
                    pathToRhPial=resolveWSLSymlink(fullfile(segmentationPath,'surf/rh.pial'),subsyspath);
                    pathToLhSphere=resolveWSLSymlink(fullfile(segmentationPath,'surf/lh.sphere.reg'),subsyspath);
                    pathToRhSphere=resolveWSLSymlink(fullfile(segmentationPath,'surf/rh.sphere.reg'),subsyspath);
                else
                    pathToLhPial=fullfile(segmentationPath,'surf/lh.pial');
                    pathToRhPial=fullfile(segmentationPath,'surf/rh.pial');
                    pathToLhSphere=fullfile(segmentationPath,'surf/lh.sphere.reg');
                    pathToRhSphere=fullfile(segmentationPath,'surf/rh.sphere.reg');
                end
               % [~,vox2ras]=system(['mri_info --vox2ras ' fullfile(segmentationFolder,'SUBJECT','')] );
               % [~,vox2rastkr]=system(['mri_info --vox2ras-tkr ' fullfile(segmentationFolder,'SUBJECT','')] );%3d model is in ras-tkr format, we want RAS coordinates

                tkr2ras=vox2ras*inv(vox2rastkr);
                cortex=getCortexFromPath(pathToLhPial,pathToRhPial,tkr2ras);

                surf.Model=cortex;
                [~,llabel,lct]=read_annotation(fullfile(segmentationPath,'label/lh.aparc.annot'));
                [~,rlabel,rct]=read_annotation(fullfile(segmentationPath,'label/rh.aparc.annot'));
                %lhtri=lhtri+1; 
                %rhtri=rhtri+1+size(lhtri,1);
                names={lct.struct_names{:} rct.struct_names{:}};
                identifiers=[lct.table(:,5); rct.table(:,5)];
                u_identifiers=unique(identifiers);
                colortable=[lct.table(:,1:3); rct.table(:,1:3)]/255;
                u_colortable=zeros(numel(u_identifiers),3);
                for i=1:length(u_identifiers)
                    u_colortable(i,:)=colortable(find(identifiers == u_identifiers(i),1),:);
                end

                surf.Annotation=[llabel; rlabel];
                surf.AnnotationLabel=struct('Name',uniqueStrCell(names)','Identifier',num2cell(u_identifiers),'PreferredColor',num2cell(u_colortable,2));
            
                lsphere=obj.CreateOutput(obj.LeftSphereIdentifier);
                rsphere=obj.CreateOutput(obj.RightSphereIdentifier);


                [LHtempvert, LHtemptri] = read_surf(pathToLhSphere);
                [RHtempvert, RHtemptri] = read_surf(pathToRhSphere);
                lsph.vert=LHtempvert;
                lsph.tri=LHtemptri+1;
                lsph.vertId=ones(size(LHtempvert,1),1);
                lsph.triId=ones(size(LHtemptri,1),1);
                
                rsph.vert=RHtempvert;
                rsph.tri=RHtemptri+1;
                rsph.triId=2*ones(size(RHtemptri,1),1);
                rsph.vertId=2*ones(size(RHtempvert,1),1);

                lsphere.Annotation=llabel;
                lsphere.AnnotationLabel=surf.AnnotationLabel;
                lsphere.Model=lsph;



                rsphere.Annotation=rlabel;
                rsphere.AnnotationLabel=surf.AnnotationLabel;
                rsphere.Model=rsph;
        end
    end
end
