classdef Volume < AData & IFileLoader
    %VOLUME Data class for MRI,CT or similar volumetric data
    %   Volume Data is stored in the nifti format
    %   RAS and voxel axis are assumed to be parallel, if not image will be
    %   resliced accordingly
    % See also AData, load_nii
    properties
         %Volume data as struct
        %  nii structure:
        %
        %	hdr -		struct with NIFTI header fields.
        %
        %	filetype -	Analyze format .hdr/.img (0); 
        %			NIFTI .hdr/.img (1);
        %			NIFTI .nii (2)
        %
        %	fileprefix - 	NIFTI filename without extension.
        %
        %	machine - 	machine string variable.
        %
        %	img - 		3D (or 4D) matrix of NIFTI data.
        %
        %	original -	the original header before any affine transform.
        % See also load_nii
        Image
        Path
    end
    
    properties (Access = private)
        RasVolume
        VoxelSize
    end
    
    methods
        
        function obj=Volume()
            obj.ignoreList{end+1}='Image';
            obj.RasVolume=[];
        end
        
        function coordOut=Vox2Ras(obj,coordIn)
            %Vox2Ras transforms coordinates from Voxel space into RAS sapce
            %Input coordinates are assumed to be in MATLABs 1 index system
            coordOut= [obj.Image.hdr.hist.srow_x;obj.Image.hdr.hist.srow_y;obj.Image.hdr.hist.srow_z;0 0 0 1] *[coordIn(:)-1; 1];
            coordOut=coordOut(1:3);
        end
        
        function coordOut=Ras2Vox(obj,coordIn)
            %Ras2Vox transforms RAS values into Matlab 1 based voxel
            %coordinates
           coordOut=[obj.Image.hdr.hist.srow_x;obj.Image.hdr.hist.srow_y;obj.Image.hdr.hist.srow_z;0 0 0 1]\[coordIn(:)+2; 1];
            coordOut=coordOut(1:3);
        end
        
        function V=GetRasSlicedVolume(obj,voxelSize)
            if(nargin < 2)
                voxelSize=[1 1 1];
            end
            %ras sliced volume 
            if(~isempty(obj.RasVolume) && isequal(voxelSize,obj.VoxelSize))
                V=obj.RasVolume;
            else
                tpath=fullfile(obj.GetDependency('TempPath'),'temp.nii');
                obj.VoxelSize=voxelSize;
                reslice_nii(obj.Path,tpath,voxelSize);
                V=Volume();
                V.LoadFromFile(tpath);
                obj.RasVolume=V;
                rmdir(tpath);
            end
        end

        function [x,y,z]=GetRasAxis(obj)
            % Returns the projection from voxel to RAS coordinate
            if(~isfield(obj.Image.hdr.hist,'originator'))
                error('GetRasAxis is only available for data sliced along the RAS axis');
            end
            x=((1:size(obj.Image.img,1))-obj.Image.hdr.hist.originator(1)).*obj.Image.hdr.dime.pixdim(2);
            y=((1:size(obj.Image.img,2))-obj.Image.hdr.hist.originator(2)).*obj.Image.hdr.dime.pixdim(3);
            z=((1:size(obj.Image.img,3))-obj.Image.hdr.hist.originator(3)).*obj.Image.hdr.dime.pixdim(4);
        end
        
        function LoadFromFile(obj,path)
            % Load nifti file from path
            % This function supports nifit as well as dicom
            % If multiple images are found in the dicom, it will show a
            % selection dialog
            % See also IFileLoader
            tpath=fullfile(obj.GetDependency('TempPath'),'dicom_convert');
            mkdir(tpath);
            try
            [spath,~,ext]=fileparts(path);
            if(any(strcmpi(ext,{'.dcm','.dicom',''})))
                dicm2nii(spath,tpath,0);
                path=dir(fullfile(tpath,'*.nii'));
                if(numel(path) > 1 )
                    warning('Dicom contains multiple Image Containers!');
                    sel_name=cellfun(@(x)x.name,path,'UniformOutput',false);
                    [idx,tf]=listdlg('PromptString','Please Select the correct Dicom for import','SelectionMode','single','ListString',sel_name);
                    if(tf ~= 0)
                        path=path{idx};
                    else
                        error('No Dicom selected!');
                    end
                end
                path=fullfile(path.folder,path.name);
            end
            try
                obj.Image=load_nii(path,[],[],[],[],[],0);
                obj.Path=path;
            catch e
                obj.Image=load_untouch_nii(path,[],[],[],[],[]);
                obj.Path=path;    
            end
            catch
            end
            rmdir(tpath,'s'); %ensure that temp folder is deleted
               % [nii.img,nii.XYZ ]=spm_read_vols(nii);

        end
        
        function Load(obj,path)
            %Load - override of serializer load
            %See also Serializable.Load
            Load@AData(obj,path);
            obj.Path=obj.makeFullPath(obj.Path);
            if(~isempty(obj.Path))
                try
                    obj.Image=load_nii(path,[],[],[],[],[],0);
                catch
                    obj.Image=load_untouch_nii(obj.Path,[],[],[],[],[]);
                end
            end
        end
        
        function savepath=Save(obj,path)
            if(~isempty(obj.Image))
                obj.Path=fullfile(path,[obj.Name '.nii']);
                if(isfield(obj.Image,'untouch') && obj.Image.untouch == 1)
                    save_untouch_nii(obj.Image,obj.Path);
                else
                    save_nii(obj.Image,obj.Path);
                end
            end
            buffPath=obj.Path;
            obj.Path=obj.makeRelativePath(buffPath,true);
            savepath=Save@AData(obj,path);
            obj.Path=buffPath;
        end
    end
end

