function dirs = selectProjectFolders(varargin)
%SELECTPROJECTFOLDERS Open a dialog to select multiple folders.
%
%   dirs = selectProjectFolders()
%       Opens a folder selection dialog starting in the current directory.
%
%   dirs = selectProjectFolders(startPath)
%       Opens the dialog starting in the specified directory.
%
%   dirs = selectProjectFolders(startPath, dialogTitle)
%       Opens the dialog with a custom title.
%
%   Output:
%       dirs - cell array of absolute folder paths ({} if cancelled).

    import javax.swing.JFileChooser
    import javax.swing.filechooser.FileSystemView

    % Handle input arguments
    if nargin < 1 || isempty(varargin{1})
        startPath = pwd;
    else
        startPath = varargin{1};
    end

    if nargin < 2
        dialogTitle = 'Select project folders';
    else
        dialogTitle = varargin{2};
    end

    % Create file chooser
    chooser = JFileChooser(FileSystemView.getFileSystemView);
    chooser.setDialogTitle(dialogTitle);
    chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
    chooser.setMultiSelectionEnabled(true);

    % Set starting path
    if exist(startPath, 'dir')
        chooser.setCurrentDirectory(java.io.File(startPath));
    end

    % Show dialog
    status = chooser.showOpenDialog([]);

    % Get results
    if status == JFileChooser.APPROVE_OPTION
        files = chooser.getSelectedFiles();
        dirs = arrayfun(@(f) char(f.getAbsolutePath()), files, 'UniformOutput', false);
    else
        dirs = {};
    end
end
