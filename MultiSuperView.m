% TODO: electrode saving when switching between subjects is broken
classdef MultiSuperView < Abstract3DView
    % MultiSuperViewer - Viewer for multiple subjects simultaneously
    % Uses Abstract3DView plotting logic, but concatenates subject data

    properties (Access = private)
        SubjectIDs   % Cell array of subject identifiers
        SubjectDataMap
    end
    methods
        function obj = MultiSuperView(surface, subjectDataMap, varargin)
            % Call abstract constructor (creates shared controls)
            obj@Abstract3DView(surface,varargin{:});
        
            if nargin > 1 && isa(subjectDataMap,'containers.Map')
                obj.SubjectIDs = subjectDataMap.keys;
                obj.SubjectDataMap = subjectDataMap;
                obj.combineSubjectData(subjectDataMap);
            else
                obj.SubjectIDs = {};
                obj.SubjectDataMap = containers.Map;
            end

            obj.updateView();
        end

        function electrodeFilterCallback(obj)
            % Override abstract method: use MultiViewer popup
            obj.openFilterPopup();
        end
    end
    methods (Access = private)
        function openFilterPopup(obj)
            % --- Create dialog ---
            d = uifigure('Name','Channel Selection');

            mainLayout = uigridlayout(d,[2 1]);
            mainLayout.RowHeight = {'1x', 40};   % top grows, bottom fixed height
        
            % --- Create tab group ---
            tgroup = uitabgroup(mainLayout);
        
            % Store one tree per subject
            trees = gobjects(numel(obj.SubjectIDs),1);

            for s = 1:numel(obj.SubjectIDs)
                % Create tab for each subject
                subj = obj.SubjectIDs{s};
                t = uitab(tgroup,'Title',subj);
                tabLayout = uigridlayout(t,[1 1]);
                trees(s) = uitree(tabLayout,'checkbox');

                subjData = obj.SubjectDataMap(subj);
                % I am maintaining this convention because that's how it is
                % in VERA, but idk why they are kept separately, it seems
                % like the Definition could just be instead of the def ID.
                % Electodes names (eg LAMY)
                elNames = {subjData.ElectrodeDefinitions.Definition.Name};

                % Struct containing info for all channels
                % (should really not be called positions but c'est la vie
                chNames = subjData.ElectrodePositions.Name;
                chDefs = subjData.ElectrodePositions.DefinitionIdentifier;

                % Build electrode→channel hierarchy
                for e = 1:numel(elNames)
                    elecNode = uitreenode(trees(s),'Text',elNames{e});
                    matchChIdx = find(chDefs == e);
                    for c = 1:numel(matchChIdx)
                        uitreenode(elecNode,'Text',chNames{matchChIdx(c)});
                    end
                end
            end

            % --- OK button (use uibutton in uifigure) ---
            uibutton(mainLayout,'Text','OK', ...
                'Position',[180 10 140 30], ...
                'ButtonPushedFcn',@(src,evt) closeDialog());
        
            % --- Nested: collect selections ---
            function closeDialog()
                selections = [];
                allPos = obj.ElectrodePositions;
                allIds = allPos.DefinitionIdentifier;
                allDef = obj.ElectrodeDefinitions;
                allNames = {allDef.Definition.Name};
                for s = 1:numel(obj.SubjectIDs)
                    subj = obj.SubjectIDs(s);
                    subjNameIdx = contains(allNames, subj);
                    tree = trees(s);
                    checked = tree.CheckedNodes;
                    for ch = 1:numel(checked)
                        node = checked(ch);
                        name = node.Text;
                        % find all names that match
                        % multiple subjects may have same channels
                        rightNamesIdx = find(strcmp(allPos.Name, name) > 0);
                        for r = 1:numel(rightNamesIdx)
                            idx = rightNamesIdx(r);
                            defName = allNames(allIds(idx));
                            if contains(defName,subj)
                                selections(end+1) = idx;
                                break
                            end
                        end
                    end
                end
                obj.setElectrodeFilter('ByIndex',selections);
                delete(d);
            end
        end

        function combineSubjectData(obj, subjectDataMap)
            % Flatten multiple subjects into single Surface + Electrode sets
            % (Superclass will plot them as if they were one subject)
            
            % Concatenate electrode positions + defs, tagging with subject ID
            allPos = [];
            allDef = [];
            subjLabels = {};
            
            defCounter = 0; % counts definitions (ie., electode name
                            % so that each channel is given electrode
                            % from correct subj
            
            for k = 1:numel(obj.SubjectIDs)
                subj = obj.SubjectIDs{k};
                data = subjectDataMap(subj);
                if isempty(data.ElectrodePositions), continue; end
                
                pos = data.ElectrodePositions;
                def = data.ElectrodeDefinitions;

                pos.DefinitionIdentifier = pos.DefinitionIdentifier + defCounter;
                defCounter = defCounter + numel(data.ElectrodeDefinitions.Definition);

                if isempty(allPos)
                    allPos = pos;
                else
                    allPos.Location = [allPos.Location;...
                            pos.Location];
                    allPos.DefinitionIdentifier = ...
                        [allPos.DefinitionIdentifier; 
                            pos.DefinitionIdentifier];
                    allPos.Name = [allPos.Name; ...
                        pos.Name];
                end
                for d = 1:numel(def.Definition) 
                    def.Definition(d).Name = sprintf('%s_%s', ...
                        subj, def.Definition(d).Name); 
                end 
                if isempty(allDef) 
                    allDef = def; 
                else 
                    allDef.Definition = [allDef.Definition; def.Definition];
                end 
            end

            obj.ElectrodePositions = allPos;
            obj.ElectrodeDefinitions = allDef;
            
            if ~isempty(allPos)
                allPos.SubjectLabel = subjLabels;
            end
        end
        
    end
end
