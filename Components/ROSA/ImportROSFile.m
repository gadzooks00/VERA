classdef ImportROSFile < AComponent
    %ImportROSFile Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        TrajectoryIdentifier
        ElectrodeDefinitionIdentifier
        VolumeIdentifier
        ElectrodeDefinition
        History
    end
    
    methods
        function obj = ImportROSFile()
            obj.TrajectoryIdentifier='Trajectory';
            obj.VolumeIdentifier='ROSAVolume';
            obj.ElectrodeDefinitionIdentifier='ElectrodeDefinition';
            obj.History={};
        end
        
        function Publish(obj)
            obj.AddOutput(obj.TrajectoryIdentifier,'ElectrodeLocation');
            obj.AddOutput(obj.ElectrodeDefinitionIdentifier,'ElectrodeDefinition');
            obj.AddOutput(obj.VolumeIdentifier,'Volume');
            obj.ignoreList{end+1}='History';
        end
        
        function Initialize(obj)
        end
        
        function [trajectories,definitions,volume]=Process(obj)
            [file,path]=uigetfile('*.ros',['Please select the .ros ROSA file']);
            rosa_parsed=parseROSAfile(fullfile(path,file));
            
            definitions=obj.CreateOutput(obj.ElectrodeDefinitionIdentifier);
            trajectories=obj.CreateOutput(obj.TrajectoryIdentifier);
            volume=obj.CreateOutput(obj.VolumeIdentifier);
            
            
            rot2ras=affine_rotation(deg2rad(0),deg2rad(0),deg2rad(180));
            outpath=obj.GetDependency('TempPath');
            
            for i=1:length(rosa_parsed.displays)
                displays=rosa_parsed.displays(i);
                vol_path=dir(fullfile(path,[displays.volume '.img']));
                if(~isempty(vol_path))
                    % Converting ANALYZE to nifti ----
                    info = load_nii(fullfile(vol_path.folder,vol_path.name));
                    [~,nm]=fileparts(vol_path.name);
                    save_nii(info, fullfile(outpath,['orig_' nm '.nii']));
                    % Moving nifti 0/0/0 to center of image to match ROSA coordinate
                    % space
                    info = load_nii(fullfile(outpath,['orig_' nm '.nii']));
                    img_size=size(info.img)/2;
                    info.hdr.hist.srow_x(4)=-info.hdr.dime.pixdim(2)*img_size(1);
                    info.hdr.hist.srow_y(4)=-info.hdr.dime.pixdim(3)*img_size(2);
                    info.hdr.hist.srow_z(4)=-info.hdr.dime.pixdim(4)*img_size(3);
                    info.hdr.hist.sform_code=1; %set sform 1 so that changes are applied later on
                    %image is not yet in RAS space, so we will delete the orig_ later
                    %to avoid confusion
                    save_nii(info, fullfile(outpath,['orig_' nm '.nii']));
                    %load nii without the resampling restrictions of the nifti package 
                    info = load_untouch_nii(fullfile(outpath,['orig_' nm '.nii']));
                    %calculate the correct transofmration matrix that correspond to the
                    %ROSA coregistration and transform to RAS
                    M=[info.hdr.hist.srow_x;info.hdr.hist.srow_y;info.hdr.hist.srow_z; 0 0 0 1];
                    t_out=rot2ras*displays.ATForm*M;
                    info.hdr.hist.srow_x = t_out(1,:);
                    info.hdr.hist.srow_y = t_out(2,:);
                    info.hdr.hist.srow_z = t_out(3,:);
                    info.hdr.hist.intent_name='ROSATONI';

                    % save the ROSA coregistered and RAS transformed nifti
                    save_untouch_nii(info, fullfile(outpath,[nm '.nii']));
                    ras_projected.displays{i}=fullfile(outpath,[nm '.nii']);
                    delete(fullfile(outpath,['orig_' nm '.nii'])); %lets delete this file since its coordinate system might confuse someone
                end
            end
            %% save trajectories in RAS coordinate system
            % All trajectories are in the coregistration space, so all we need to do is
            % transform the trajectories into RAS space by applying rot2ras

            for ii=1:length(rosa_parsed.Trajectories)
                traj_tosave=[rosa_parsed.Trajectories(ii).start 1;rosa_parsed.Trajectories(ii).end 1];
                traj_tosave=(rot2ras*traj_tosave')';
                traj_tosave=traj_tosave(:,1:3);
                ras_projected.Trajectories(ii).start=traj_tosave(1,:);
                ras_projected.Trajectories(ii).end=traj_tosave(2,:);
                definitions.Definition(ii).Type='Depth';
                definitions.Definition(ii).Volume=30;
                definitions.Definition(ii).Spacing=3.5;
                definitions.Definition(ii).Name=rosa_parsed.Trajectories(ii).name;
                trajectories.DefinitionIdentifier(end+1)=ii;
                trajectories.Location(end+1,:)=ras_projected.Trajectories(ii).start;
                trajectories.DefinitionIdentifier(end+1)=ii;
                trajectories.Location(end+1,:)=ras_projected.Trajectories(ii).end;
                definitions.Definition(ii).NElectrodes=obj.calculateNumContacts([ras_projected.Trajectories(ii).start; ras_projected.Trajectories(ii).end]);
            end
             
            volume.LoadFromFile(ras_projected.displays{1});
            obj.ElectrodeDefinition=definitions.Definition;
            h=figure;
            elView=ElectrodeDefinitionView('Parent',h);
            elView.SetComponent(obj);
            uiwait(h);
            hist=obj.History;
            definitions.Definition=obj.ElectrodeDefinition;
            for i=1:length(hist)
                cmd=hist{i}{1};
                val=hist{i}{2};
                if(strcmp(cmd,'Add'))
                elseif(strcmp(cmd,'Delete'))
                    for i_traj=1:length(val)
                        trajectories.Location(trajectories.DefinitionIdentifier == val(i),:)=[];
                        trajectories.DefinitionIdentifier(trajectories.DefinitionIdentifier == val(i))=[];
                        trajectories.DefinitionIdentifier(trajectories.DefinitionIdentifier > val(i))=trajectories.DefinitionIdentifier(trajectories.DefinitionIdentifier > val(i)) -1;
                    end
                elseif(strcmp(cmd,'Update'))
                else
                    error('unknown ElectrodeDefinitionView history command');
                end
            end
        end
        
        function numC=calculateNumContacts(obj,traj)
            shankLength=pdist(traj)-3;
            if(shankLength <= 12.5)
                numC=4;
            elseif(shankLength <= 19.5)
                numC=6;
            elseif(shankLength <= 26.5)
                numC=8;
            elseif(shankLength <= 33.5)
                numC=10;
            elseif(shankLength <= 40.5)
                numC=12;
            elseif(shankLength <= 47.5)
                numC=14;
            else
                numC=16;
            end
        end
    end
    
    
end

