classdef MatOutputNoElectrodes < AComponent
    %MatOutputNoElectrodes Creates a .mat file as Output of VERA similar to neuralact
    %but with no additional information about electrode locations
    properties
        SurfaceIdentifier
        SavePathIdentifier char
    end
    
    methods
        function obj = MatOutputNoElectrodes()
            obj.SurfaceIdentifier  = 'Surface';
            obj.SavePathIdentifier = 'default';
        end
        
        function Publish(obj)
            obj.AddInput(obj.SurfaceIdentifier, 'Surface');
        end
        
        function Initialize(obj)
        end
        
        function []= Process(obj, surf)
            
            % create output file in DataOutput folder with ProjectName_ComponentName.mat (default behavior)
            if strcmp(obj.SavePathIdentifier,'default')
                ProjectPath      = fileparts(obj.ComponentPath);
                [~, ProjectName] = fileparts(ProjectPath);

                path = fullfile(obj.ComponentPath,'..','DataOutput');
                file = [ProjectName, '_', obj.Name,'.mat'];

            % if empty, use dialog
            elseif isempty(obj.SavePathIdentifier)
                [file, path] = uiputfile('*.mat');
                if isequal(file, 0) || isequal(path, 0)
                    error('Selection aborted');
                end

            % Otherwise, save with specified file name
            else
                [path, file, ext] = fileparts(obj.SavePathIdentifier);
                file = [file,ext];
                path = fullfile(obj.ComponentPath,'..',path);

                if ~strcmp(ext,'.mat')
                    path = fullfile(obj.ComponentPath,'..',obj.SavePathIdentifier);
                    file = [obj.Name,'.mat'];
                end
            end

            % convert spaces to underscores
            file = replace(file,' ','_');

            % create save folder if it doesn't exist
            if ~isfolder(path)
                mkdir(path)
            end

            surfaceModel.Model           = surf.Model;           % Contains vert (x,y,z points) and tri (triangle triangulation vector) to create the 3D model
                                                                 % specified through SurfaceIdentifier in VERA. Additionally, it also contains triId and vertId,
                                                                 % which allows you to distinguish between the left (1) and right (2) hemisphere if your data 
                                                                 % comes from a freesurfer Surface.
            surfaceModel.Annotation      = surf.Annotation;      % Identifier number associating each vertice of a surface with a given annotation
            surfaceModel.AnnotationLabel = surf.AnnotationLabel; % Surface annotation map connecting identifier values with annotation
            
            save(fullfile(path,file),'surfaceModel');

            % Popup stating where file was saved
            msgbox(['File saved as: ',GetFullPath(fullfile(path,file))],['"',obj.Name,'" file saved'])
        end
       
    end
end

