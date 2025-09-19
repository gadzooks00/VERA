function multiFlag = modeDialog()
    %CHOOSEMODEDIALOG Open a dialog with Multi, Single, and Cancel options.
    %
    %   multiFlag = chooseModeDialog()
    %       Returns true if "Multi" was selected,
    %       false if "Single" was selected,
    %       and ends the program if "Cancel" was selected.

    % Create the dialog
    d = dialog('Name','Choose Mode', ...
               'Position',[500 500 250 150]);

    % Store output flag
    multiFlag = [];

    % --- Create buttons ---
    uicontrol('Parent',d, ...
              'Style','pushbutton', ...
              'String','Multi', ...
              'Position',[30 60 60 40], ...
              'Callback',@(src,evt) setFlag(true));

    uicontrol('Parent',d, ...
              'Style','pushbutton', ...
              'String','Single', ...
              'Position',[95 60 60 40], ...
              'Callback',@(src,evt) setFlag(false));

    uicontrol('Parent',d, ...
              'Style','pushbutton', ...
              'String','Cancel', ...
              'Position',[160 60 60 40], ...
              'Callback',@(src,evt) cancelProgram());

    % Wait for the user to choose
    uiwait(d);

    % --- Nested callback functions ---
    function setFlag(val)
        multiFlag = val;
        delete(d); % close dialog
    end

    function cancelProgram()
        delete(d); % close dialog
        error('User canceled. Program terminated.');
    end
end
