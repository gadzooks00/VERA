classdef ANTCoregistration < AComponent
    %ANTCOREGISTRATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ReferenceIdentifier
        CoregistrationIdentifier
        SurfaceIdentifier
        Type
        ElectrodeLocationIdentifier
    end
    properties (Constant, Access = private)
        RegistrationAlgorithms = {'Rigid','Affine','SyN'}
    end
    
    methods
        function obj = ANTCoregistration()
            obj.ReferenceIdentifier='MNI';
            obj.CoregistrationIdentifier='MRI';
            obj.Type='SyN';
            obj.ElectrodeLocationIdentifier='ElectrodeLocation';
            obj.SurfaceIdentifier='Surface';
        end
        
        function Publish(obj)
            obj.AddInput(obj.ReferenceIdentifier,'Volume');
            obj.AddInput(obj.CoregistrationIdentifier,'Volume');
            obj.AddInput(obj.SurfaceIdentifier,'Surface');
            obj.AddOutput(obj.CoregistrationIdentifier,'Volume');
            obj.AddOutput(obj.SurfaceIdentifier,'Surface');
            if(~isempty(obj.ElectrodeLocationIdentifier))
                obj.AddInput(obj.ElectrodeLocationIdentifier,'ElectrodeLocation');
                obj.AddOutput(obj.ElectrodeLocationIdentifier,'ElectrodeLocation');
            end
            obj.RequestDependency('ANT','folder');
        end

        function Initialize(obj)
            ant_dep=obj.GetDependency('ANT');
            if(~any(strcmp(obj.Type,obj.RegistrationAlgorithms)))
                error('Invalid Registration algorithm selected; Choose from: Rigid, Affine or SyN');
            end

        end

        function varargout=Process(obj,refVol,coregVol,surf,varargin)
            csvM=surf.Model.vert;
            if(~isempty(varargin))
                elLocs=varargin{1};
                csvM=[csvM; elLocs.Location];
                %write elLocs to csv
            end
            %add T and comment to match csv specs
            csvM=[csvM zeros(size(csvM,1),1)];

            ant_path=obj.GetDependency('ANT');
            tmpPath=obj.GetTempPath();
            tmpPathcsv=fullfile(tmpPath,'pointset.csv');
            
            T = array2table(csvM);
            T.Properties.VariableNames = {'x','y','z','t'};
            T.x=-T.x;
            T.y=-T.y;
            
            writetable(T,tmpPathcsv);
            ref_path=GetFullPath(refVol.Path);
            coreg_path=GetFullPath(coregVol.Path);
            ant_script_image=fullfile(fileparts((mfilename('fullpath'))),'/scripts/ANTS_IMAGE.sh');
            ant_script_rigid=fullfile(fileparts((mfilename('fullpath'))),'/scripts/ANTS_PTS_RIGID.sh');
            ant_script_SyN=fullfile(fileparts((mfilename('fullpath'))),'/scripts/ANTS_PTS_SyN.sh');
            coregType=find(strcmp(obj.Type,obj.RegistrationAlgorithms));
            
            if(ispc)
                subsyspath=obj.GetDependency('UbuntuSubsystemPath');
                ant_script_image_wsl=convertToUbuntuSubsystemPath(ant_script_image,subsyspath);
                ant_script_rigid_wsl=convertToUbuntuSubsystemPath(ant_script_rigid,subsyspath);
                ant_script_SyN_wsl=convertToUbuntuSubsystemPath(ant_script_SyN,subsyspath);
                ant_path_wsl=convertToUbuntuSubsystemPath(ant_path,subsyspath);
                ref_path_wsl=convertToUbuntuSubsystemPath(ref_path,subsyspath);
                tmpPathcsv_wsl=convertToUbuntuSubsystemPath(tmpPathcsv,subsyspath);
                coreg_path_wsl=convertToUbuntuSubsystemPath(coreg_path,subsyspath);
                tmpPath_wsl=convertToUbuntuSubsystemPath(tmpPath,subsyspath);

                systemWSL(['chmod +x ''' ant_script_image_wsl ''''],'-echo');
                shellcmd=[ant_script_image_wsl ...
                ' ''' ant_path_wsl '''' ...
                ' ''' ref_path_wsl '''' ...
                ' ''' coreg_path_wsl '''' ...
                ' ''' tmpPath_wsl  '''' ...
                ' ''' num2str(coregType) ''''];
                systemWSL(shellcmd,'-echo');


                systemWSL(['chmod +x ''' ant_script_rigid_wsl ''''],'-echo');
                shellcmd=[ant_script_rigid_wsl ...
                ' ''' ant_path_wsl '''' ...
                ' ''' tmpPathcsv_wsl '''' ...
                ' ''' tmpPath_wsl  '''' ];
                systemWSL(shellcmd,'-echo');

                if(~exist(fullfile(tmpPath,'reg_out_rigid.csv'),'file'))
                    error('No Rigid/affine point transformation created!');
                end
                V=readtable(fullfile(tmpPath,'reg_out_rigid.csv'));
                
                if(coregType >2) %we first need to transform points into LPS and than back
                    writetable(V,tmpPathcsv);
                    systemWSL(['chmod +x ''' ant_script_SyN_wsl ''''],'-echo');
                    shellcmd=[ant_script_SyN_wsl ...
                    ' ''' ant_path_wsl '''' ...
                    ' ''' tmpPathcsv_wsl '''' ...
                    ' ''' tmpPath_wsl  '''' ];
                    systemWSL(shellcmd,'-echo');  
                    if(~exist(fullfile(tmpPath,'reg_out_syn.csv'),'file'))
                        error('No syn point transformation created!');
                    end
                    V=readtable(fullfile(tmpPath,'reg_out_syn.csv'));
                end
                V.x=-V.x;
                V.y=-V.y;
            else
                system(['chmod +x ''' ant_script_image ''''],'-echo');
                shellcmd=[ant_script_image ...
                ' ''' ant_path '''' ...
                ' ''' ref_path '''' ...
                ' ''' coreg_path '''' ...
                ' ''' tmpPath  '''' ...
                ' ''' num2str(coregType) ''''];
                system(shellcmd,'-echo');


                system(['chmod +x ''' ant_script_rigid ''''],'-echo');
                shellcmd=[ant_script_rigid ...
                ' ''' ant_path '''' ...
                ' ''' tmpPathcsv '''' ...
                ' ''' tmpPath  '''' ];
                system(shellcmd,'-echo');

                if(~exist(fullfile(tmpPath,'reg_out_rigid.csv'),'file'))
                    error('No Rigid/affine point transformation created!');
                end
                V=readtable(fullfile(tmpPath,'reg_out_rigid.csv'));
                
                if(coregType >2) %we first need to transform points into LPS and than back
                    writetable(V,tmpPathcsv);
                    system(['chmod +x ''' ant_script_SyN ''''],'-echo');
                    shellcmd=[ant_script_SyN ...
                    ' ''' ant_path '''' ...
                    ' ''' tmpPathcsv '''' ...
                    ' ''' tmpPath  '''' ];
                    system(shellcmd,'-echo');  
                    if(~exist(fullfile(tmpPath,'reg_out_syn.csv'),'file'))
                        error('No syn point transformation created!');
                    end
                    V=readtable(fullfile(tmpPath,'reg_out_syn.csv'));
                end
                V.x=-V.x;
                V.y=-V.y;
            end
            if(~exist(fullfile(tmpPath,'reg_out_111_ants.nii'),'file'))
                error('ANT script failed to produce all outputs!');
            end
            V=table2array(V);
            coregVol=obj.CreateOutput(obj.CoregistrationIdentifier);
            coregVol.LoadFromFile(fullfile(tmpPath,'reg_out_111_ants.nii'));

            surfOut=obj.CreateOutput(obj.SurfaceIdentifier,surf);

            

            surfOut.Model.vert=V(1:size(surfOut.Model.vert,1),1:3);
            varargout{1}=coregVol;
            varargout{2}=surfOut;
            

            if(~isempty(varargin))
                elOut=obj.CreateOutput(obj.ElectrodeLocationIdentifier,varargin{1});
                elOut.Location=V(size(surfOut.Model.vert,1)+1:end,1:3);
                varargout{3}=elOut;
                 %surfOut=obj.CreateOutput(obj.SurfaceIdentifier);
            end
            

        end
    end
end

