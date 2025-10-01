classdef ElectrodeFilterDialog < handle
    % ElectrodeFilterDialog - UI for selecting which electrodes to display.
    
    properties
        SubjectIDs
        SubjectDataMap
        SingleMode = false
    end
    
    properties (Access = private)
        Fig
        Trees
        Selections
        PreviousSelections  % Map: SubjectID -> selected indices
    end
    
    methods
        function obj = ElectrodeFilterDialog(subjectIDs, subjectDataMap, singleMode)
            if nargin > 0
                obj.SubjectIDs = subjectIDs;
                obj.SubjectDataMap = subjectDataMap;
                if nargin > 2
                    obj.SingleMode = singleMode;
                end
                obj.PreviousSelections = containers.Map('KeyType','char','ValueType','any');
            end
        end
        
        function selections = open(obj)
            % Create the dialog
            obj.Fig = uifigure('Name','Channel Selection');
            mainLayout = uigridlayout(obj.Fig,[2 1]);
            mainLayout.RowHeight = {'1x', 40};   % top grows, bottom fixed
        
            % Tab group
            tgroup = uitabgroup(mainLayout);
            obj.Trees = gobjects(numel(obj.SubjectIDs),1);
    
            for s = 1:numel(obj.SubjectIDs)
                subj = obj.SubjectIDs{s};
                t = uitab(tgroup,'Title',subj);
                tabLayout = uigridlayout(t,[1 1]);
                obj.Trees(s) = uitree(tabLayout,'checkbox');
    
                subjData = obj.SubjectDataMap(subj);
                elNames = {subjData.ElectrodeDefinitions.Definition.Name};
                chNames = subjData.ElectrodePositions.Name;
                chDefs  = subjData.ElectrodePositions.DefinitionIdentifier;
    
                % Build electrode → channel hierarchy
                for e = 1:numel(elNames)
                    elecNode = uitreenode(obj.Trees(s),'Text',elNames{e});
                    matchChIdx = find(chDefs == e);
                    for c = 1:numel(matchChIdx)
                        uitreenode(elecNode,'Text',chNames{matchChIdx(c)});
                    end
                end
            end
            
            % Restore previous selections after all trees are built
            obj.restorePreviousSelections();
    
            % OK button
            uibutton(mainLayout,'Text','OK', ...
                'ButtonPushedFcn', @(~,~) obj.closeDialog());
            
            % Block until user closes
            uiwait(obj.Fig);
            selections = obj.Selections;
        end
    end
    
    methods (Access = private)
        function restorePreviousSelections(obj)
            for s = 1:numel(obj.SubjectIDs)
                subj = obj.SubjectIDs{s};
                tree = obj.Trees(s);
                subjData = obj.SubjectDataMap(subj);

                allPos = subjData.ElectrodePositions;
                allIds = allPos.DefinitionIdentifier;
                allDef = subjData.ElectrodeDefinitions;
                allNames = {allDef.Definition.Name};

                % Flatten all channel nodes (grandchildren)
                channelNodes = [];
                for e = 1:numel(tree.Children)
                    channelNodes = [channelNodes; tree.Children(e).Children(:)]; %#ok<AGROW>
                end

                nodesToCheck = matlab.ui.container.TreeNode.empty;

                if isKey(obj.PreviousSelections, subj)
                    selIdx = obj.PreviousSelections(subj);  % indices for this subject
                    for n = 1:numel(channelNodes)
                        node = channelNodes(n);
                        name = node.Text;
                        idxs = find(strcmp(allPos.Name, name));

                        % Check if any index is in selIdx
                        for k = 1:numel(idxs)
                            idx = idxs(k);
                            if ismember(idx,selIdx)
                                nodesToCheck(end+1,1) = node;
                            end
                        end
                    end
                end

                if ~isempty(nodesToCheck)
                    tree.CheckedNodes = nodesToCheck;
                end
            end
        end
        
        function closeDialog(obj)
            obj.Selections = [];
            
            for s = 1:numel(obj.SubjectIDs)
                subj = obj.SubjectIDs{s};
                subjData = obj.SubjectDataMap(subj);
                allPos = subjData.ElectrodePositions;
                allIds = allPos.DefinitionIdentifier;
                allDef = subjData.ElectrodeDefinitions;
                allNames = {allDef.Definition.Name};

                checked = obj.Trees(s).CheckedNodes;
                selIdx = [];

                % Map checked nodes to ElectrodePositions indices
                for ch = 1:numel(checked)
                    node = checked(ch);
                    name = node.Text;
                    idxs = find(strcmp(allPos.Name, name));

                    for k = 1:numel(idxs)
                        idx = idxs(k);
                        selIdx(end+1) = idx;
                        break;
                    end
                end

                obj.Selections = [obj.Selections, selIdx];
                obj.PreviousSelections(subj) = selIdx;   % store per subject
            end

            delete(obj.Fig);
            uiresume;
        end
    end
end
