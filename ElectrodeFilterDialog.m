classdef ElectrodeFilterDialog < handle
    % ElectrodeFilterDialog - UI for selecting which contacts to display.
    
    properties
        Subjects        % canonical Subjects struct from Super3DView
        SingleMode = false
    end
    
    properties (Access = private)
        Fig
        Trees
        PreviousSelections  % Map: SubjectID -> selected contact names
    end
    
    methods
        function obj = ElectrodeFilterDialog(subjects, singleMode)
            if nargin > 0
                obj.Subjects = subjects;
                if nargin > 1
                    obj.SingleMode = singleMode;
                end
                obj.PreviousSelections = containers.Map('KeyType','char','ValueType','any');
            end
        end
        
        function subjects = open(obj, subjects)
            obj.Subjects = subjects;
            % Create the dialog
            obj.Fig = uifigure('Name','Electrode Filter',...
                               'Position',[200 200 400 500]);
            mainLayout = uigridlayout(obj.Fig,[2 1]);
            mainLayout.RowHeight = {'1x', 40};   % tree grows, bottom fixed
        
            % Tab group
            tgroup = uitabgroup(mainLayout);
            obj.Trees = gobjects(numel(obj.Subjects),1);
    
            for s = 1:numel(obj.Subjects)
                subjID = obj.Subjects(s).ID;
                t = uitab(tgroup,'Title',subjID);
                tabLayout = uigridlayout(t,[1 1]);
                obj.Trees(s) = uitree(tabLayout,'checkbox');
    
                % Group contacts by electrode name
                [elecNames,~,grpIdx] = unique({obj.Subjects(s).Contacts.Electrode});
                for e = 1:numel(elecNames)
                    elecNode = uitreenode(obj.Trees(s),'Text',elecNames{e});
                    contactIdx = find(grpIdx == e);
                    for c = contactIdx'
                        uitreenode(elecNode,'Text',obj.Subjects(s).Contacts(c).Name,...
                                   'NodeData',struct('subj',s,'idx',c));
                    end
                end
            end
            
            % Restore previous selections after trees are built
            obj.restorePreviousSelections();
    
            % OK button
            uibutton(mainLayout,'Text','OK', ...
                'ButtonPushedFcn', @(~,~) obj.closeDialog());
            
            % Block until user closes
            uiwait(obj.Fig);
            subjects = obj.Subjects;  % return updated struct
        end
    end
    
    methods (Access = private)
        function restorePreviousSelections(obj)
            for s = 1:numel(obj.Subjects)
                subjID = obj.Subjects(s).ID;
                tree = obj.Trees(s);

                % Flatten all contact nodes
                channelNodes = [];
                for e = 1:numel(tree.Children)
                    channelNodes = [channelNodes; tree.Children(e).Children(:)]; %#ok<AGROW>
                end

                if isKey(obj.PreviousSelections, subjID)
                    selNames = obj.PreviousSelections(subjID);
                    matchNodes = channelNodes(ismember({channelNodes.Text}, selNames));
                    tree.CheckedNodes = matchNodes;
                end
            end
        end
        
        function closeDialog(obj)
            % Update Subjects visibility based on checked nodes
            for s = 1:numel(obj.Subjects)
                subjID = obj.Subjects(s).ID;
                checked = obj.Trees(s).CheckedNodes;
                selNames = {};
                if ~isempty(checked)
                    selNames = {checked.Text};
                end

                % Store selection for restoration next time
                obj.PreviousSelections(subjID) = selNames;

                % Update visibility in Subjects struct
                for c = 1:numel(obj.Subjects(s).Contacts)
                    ct = obj.Subjects(s).Contacts(c);
                    obj.Subjects(s).Contacts(c).Visible = ismember(ct.Name, selNames);
                end
            end

            delete(obj.Fig);
            uiresume;
        end
    end
end
