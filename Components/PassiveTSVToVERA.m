classdef PassiveTSVToVERA < AComponent
%--------------------------------------------------------------------------
% PassiveTSVToVERA
%
% Purpose
%   Minimal, dependency-light component that:
%     1) Loads a single TSV (no BIDS or FreeSurfer).
%     2) Converts rows into:
%          • ElectrodeDefinition (struct array → out_def.Definition)
%          • ElectrodeLocation   (fields → out_loc.Location, out_loc.DefinitionIdentifier)
%
% Expected TSV columns
%   name | x | y | z | (others ignored)
%
% Grouping / indexing rules
%   • Group key  = non-digit prefix of `name` (e.g., "LSMAIN1" → "LSMAIN").
%   • Contact #  = trailing digits; if missing, indices assigned by order.
%   • NElectrodes = max index in group (fallback: count if no digits).
%
% Electrode attributes (fixed to match your spec)
%   • Type    = 'Depth'
%   • Spacing = 3.5
%   • Volume  = 30
%
% Output schema
%   out_def.Definition            : 1×G struct array with fields:
%       Type(char), Name(char), NElectrodes(double), Spacing(double), Volume(double)
%   out_loc.Location              : N×3 double  (XYZ)
%   out_loc.DefinitionIdentifier  : N×1 double  (1-based group indices; COLUMN vector)
%
% Notes
%   • No calls to AddDefinition/AddWithIdentifier (direct field assignment).
%   • No obj.Name assignment (some frameworks disallow setting it).
%   • Errors are plain error('...') strings to match the larger codeset.
%--------------------------------------------------------------------------

    properties
        % Output identifiers 
        IdentifierDefinition char = 'ElectrodeDefinition';
        IdentifierLocation   char = 'ElectrodeLocation';

        % File loading configuration 
        InputFilepath    char = '';        % absolute or project-relative path to TSV
        FileTypeWildcard char = '*.tsv';   % dialog filter
    end

    methods
        function Publish(obj)
            obj.AddOutput(obj.IdentifierDefinition, 'ElectrodeDefinition');
            obj.AddOutput(obj.IdentifierLocation,   'ElectrodeLocation');
        end

        function Initialize(~)
        end

        function [out_def, out_loc] = Process(obj)
            [tsv_file, tsv_path] = obj.resolveInputTSV();
            if isequal(tsv_file, 0)
                error('File selection aborted');
            end
            tsv_full_path = fullfile(tsv_path, tsv_file);

            %------------------------------%
            % Read TSV                     %
            %------------------------------%
            try
                opts = detectImportOptions(tsv_full_path, 'FileType','text', 'Delimiter','\t');
                opts.ExtraColumnsRule = 'ignore';
                opts.EmptyLineRule    = 'read';
                t_in = readtable(tsv_full_path, opts);
            catch
                error('Failed to read TSV file');
            end
            if isempty(t_in)
                error('Loaded TSV is empty');
            end

            % Normalize variable names and validate required columns
            t_in.Properties.VariableNames = lower(t_in.Properties.VariableNames);
            required_cols = {'name','x','y','z'};
            for k = 1:numel(required_cols)
                if ~ismember(required_cols{k}, t_in.Properties.VariableNames)
                    error('TSV missing required columns');
                end
            end

            %------------------------------%
            % Extract & sanitize           %
            %------------------------------%
            name_col = string(t_in.name);
            name_col = strtrim(name_col);

            % Coerce numeric XYZ
            try
                x = double(t_in.x); y = double(t_in.y); z = double(t_in.z);
            catch
                error('Coordinate columns must be numeric (x, y, z)');
            end

            % Drop rows with invalid coords
            good_mask = ~(isnan(x) | isnan(y) | isnan(z));
            name_col = name_col(good_mask);
            x = x(good_mask); y = y(good_mask); z = z(good_mask);

            if isempty(name_col)
                error('No valid electrode rows after filtering');
            end

            %------------------------------%
            % Parse groups & contact index %
            %------------------------------%
            % Group = non-digit prefix (trim trailing separators too)
            group_name = regexprep(name_col, '(\d+)$', '');
            group_name = regexprep(group_name, '[_\s]+$', '');
            % Trailing digits → contact index
            tok = regexp(name_col, '(\d+)$', 'tokens', 'once');
            contact_idx = nan(numel(name_col),1);
            for i = 1:numel(name_col)
                if ~isempty(tok{i})
                    contact_idx(i) = str2double(tok{i}{1});
                end
            end

            % Assign sequential indices for groups lacking digits
            [uniq_groups, ~, gidx] = unique(group_name, 'stable');
            for gi = 1:numel(uniq_groups)
                sel = (gidx == gi);
                if all(isnan(contact_idx(sel)))
                    contact_idx(sel) = 1:sum(sel);
                end
            end

            % Stable sort by (group, index)
            [~, ord] = sortrows([gidx, contact_idx], [1 2]);
            group_name  = group_name(ord);
            contact_idx = contact_idx(ord);
            locs_all    = [x(ord), y(ord), z(ord)];

            % Final safety on XYZ
            if size(locs_all,2) ~= 3 || any(~isfinite(locs_all(:)))
                error('Invalid XYZ data after sorting');
            end

            %------------------------------%
            % Build ElectrodeDefinition    %
            %------------------------------%
            fixed_type    = 'Depth';
            fixed_spacing = 3.5;
            fixed_volume  = 30;

            def = struct('Type',{},'Name',{},'NElectrodes',{},'Spacing',{},'Volume',{});
            def(numel(uniq_groups)).Type = '';  % preallocate struct array
            for gi = 1:numel(uniq_groups)
                g = uniq_groups(gi);
                in_group = (group_name == g);

                idx_g = contact_idx(in_group);
                if all(isnan(idx_g))
                    n_elec = sum(in_group);
                else
                    n_elec = max(idx_g);
                end
                if ~isscalar(n_elec) || ~isfinite(n_elec) || n_elec <= 0
                    error('Computed NElectrodes is invalid');
                end

                def(gi).Type        = fixed_type;          % char
                def(gi).Name        = char(g);             % char (avoid string here)
                def(gi).NElectrodes = n_elec;              % double
                def(gi).Spacing     = fixed_spacing;       % double
                def(gi).Volume      = fixed_volume;        % double
            end

            %------------------------------%
            % Build ElectrodeLocation      %
            %------------------------------%
            % DefinitionIdentifier: N×1 double (column)
            [~, def_id_per_row] = ismember(group_name, uniq_groups);
            if any(def_id_per_row == 0)
                error('Group mapping failed while building DefinitionIdentifier');
            end
            def_id_per_row = def_id_per_row(:);   % enforce column vector

            %------------------------------%
            % Create outputs (direct set)  %
            %------------------------------%
            out_def = obj.CreateOutput(obj.IdentifierDefinition);
            out_loc = obj.CreateOutput(obj.IdentifierLocation);

            % Direct assignment (no helper methods; stable for config)
            out_def.Definition           = def;             % 1×G struct
            out_loc.Location             = locs_all;        % N×3 double
            out_loc.DefinitionIdentifier = def_id_per_row;  % N×1 double (column)
        end
    end

    %======================================================================%
    % Helpers                                                              %
    %======================================================================%
    methods (Access = private)
        function [file, path] = resolveInputTSV(obj)
            %------------------------------------------------------------------
            % Resolve InputFilepath with robust fallbacks:
            %   • If absolute and exists → use it.
            %   • If relative → resolve against project (ComponentPath/..).
            %   • Else → open file dialog using FileTypeWildcard.
            %------------------------------------------------------------------
            file = 0; path = 0;

            if ~isempty(obj.InputFilepath)
                try
                    is_abs = false;
                    if exist('isAbsolutePath','file') == 2
                        is_abs = isAbsolutePath(obj.InputFilepath);
                    else
                        is_abs = ~isempty(regexp(obj.InputFilepath, '^[A-Za-z]:[\\/]|^[/\\]', 'once'));
                    end

                    if is_abs
                        candidate = obj.InputFilepath;
                    else
                        candidate = fullfile(obj.ComponentPath, '..', obj.InputFilepath);
                        if exist('GetFullPath','file') == 2
                            candidate = GetFullPath(candidate);
                        end
                    end

                    if exist(candidate, 'file')
                        [p,f,e] = fileparts(candidate);
                        file = [f e]; path = p; return;
                    end
                catch
                    % fall through to dialog
                end
            end

            [file, path] = uigetfile(obj.FileTypeWildcard, ['Please select ' obj.IdentifierDefinition]);
        end
    end
end
