classdef ElectrodeFilterDialog < handle
    % ElectrodeFilterDialog - Persistent UI for selecting which contacts to display.

    properties
        Subjects        % canonical Subjects struct from Super3DView
        SingleMode = false
        Fig
    end

    properties (Access = private)
        Trees
        TabGroup
        PreviousSelections  % Map: SubjectID -> selected contact names
        BtnSelectAll
        BtnDeselectAll
    end

    methods
        function obj = ElectrodeFilterDialog(subjects, singleMode)
            if nargin > 0
                obj.Subjects = subjects;
            end
            if nargin > 1
                obj.SingleMode = singleMode;
            end
            obj.PreviousSelections = containers.Map('KeyType','char','ValueType','any');

            obj.buildUI();
        end

        % ---------------- PUBLIC API ----------------
        function show(obj)
            if isempty(obj.Fig) || ~isvalid(obj.Fig)
                obj.buildUI();
            else
                obj.refreshTrees();
                obj.Fig.Visible = 'on';
            end
        end
        function closeDialog(obj)
            obj.hide()
            uiresume(obj.fig)
        end

        function hide(obj)
            if isvalid(obj.Fig)
                obj.Fig.Visible = 'off';
            end
        end

        function subjects = getData(obj)
            % Updates Subjects struct with visibility states
            for s = 1:numel(obj.Subjects)
                subjID = obj.Subjects(s).ID;
                tree = obj.Trees(s);
                checked = tree.CheckedNodes;
                checkedNames = {checked.Text};

                % Store previous selections
                obj.PreviousSelections(subjID) = checkedNames;

                for c = 1:numel(obj.Subjects(s).Contacts)
                    ctName = obj.Subjects(s).Contacts(c).Name;
                    obj.Subjects(s).Contacts(c).Visible = ismember(ctName, checkedNames);
                end
            end
            subjects = obj.Subjects;
        end
    end

    % ---------------- PRIVATE HELPERS ----------------
    methods (Access = private)
        function buildUI(obj)
            % Create figure and layout
            obj.Fig = uifigure('Name', 'Electrode Filter', ...
                               'Visible', 'off', ...
                               'Position', [200 200 400 520]);
            mainLayout = uigridlayout(obj.Fig, [3 1]);
            mainLayout.RowHeight = {'5x', '1x', 'fit'};
            mainLayout.Padding = [10 10 10 10];

            % Tab group for subjects
            obj.TabGroup = uitabgroup(mainLayout);

            % Button row (select/deselect all)
            btnLayout = uigridlayout(mainLayout);
            btnLayout.ColumnWidth = {'1x', '1x'};
            obj.BtnSelectAll = uibutton(btnLayout, 'Text', 'Select All', ...
                'ButtonPushedFcn', @(~,~) obj.selectAllInCurrentTab());
            obj.BtnDeselectAll = uibutton(btnLayout, 'Text', 'Deselect All', ...
                'ButtonPushedFcn', @(~,~) obj.deselectAllInCurrentTab());

            % OK button
            uibutton(mainLayout, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~, ~) obj.onOK());

            % Build subject trees
            obj.Trees = gobjects(numel(obj.Subjects), 1);
            for s = 1:numel(obj.Subjects)
                subj = obj.Subjects(s);
                tab = uitab(obj.TabGroup, 'Title', subj.ID);
                tabLayout = uigridlayout(tab, [1 1]);
                tree = uitree(tabLayout, 'checkbox');
                obj.Trees(s) = tree;

                % Group contacts by electrode name
                [elecNames, ~, grpIdx] = unique({subj.Contacts.Electrode});
                for e = 1:numel(elecNames)
                    elecNode = uitreenode(tree, 'Text', elecNames{e});
                    contactIdx = find(grpIdx == e);
                    for c = contactIdx'
                        uitreenode(elecNode, ...
                                   'Text', subj.Contacts(c).Name, ...
                                   'NodeData', struct('subj', s, 'idx', c));
                    end
                end
            end

            % Restore selections (if any)
            obj.restorePreviousSelections();
        end

        function refreshTrees(obj)
            % Reloads current visibility states into trees
            for s = 1:numel(obj.Subjects)
                subj = obj.Subjects(s);
                tree = obj.Trees(s);

                % Flatten nodes
                channelNodes = [];
                for e = 1:numel(tree.Children)
                    channelNodes = [channelNodes; tree.Children(e).Children(:)]; %#ok<AGROW>
                end

                % Check visible ones
                visibleNames = {subj.Contacts([subj.Contacts.Visible]).Name};
                matchNodes = channelNodes(ismember({channelNodes.Text}, visibleNames));
                tree.CheckedNodes = matchNodes;
            end
        end

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
                else
                    % Initialize from .Visible
                    visibleNames = {obj.Subjects(s).Contacts([obj.Subjects(s).Contacts.Visible]).Name};
                    matchNodes = channelNodes(ismember({channelNodes.Text}, visibleNames));
                    tree.CheckedNodes = matchNodes;
                end
            end
        end

        function selectAllInCurrentTab(obj)
            % Get current tab and find its uitree
            tree = obj.TabGroup.SelectedTab.Children.Children;
            if isempty(tree), return; end
        
            % Select all nodes
            tree.CheckedNodes = findall(tree, 'Type', 'uitreenode');
        end
        
        function deselectAllInCurrentTab(obj)
            tree = obj.TabGroup.SelectedTab.Children.Children;
            if isempty(tree), return; end
        
            % Deselect all
            tree.CheckedNodes = [];
        end


        function onOK(obj)
            uiresume(obj.Fig);
            obj.getData();  % sync visibility
            obj.hide();     % hide instead of destroy
        end
    end
end
