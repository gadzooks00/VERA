function xmlFiles = collectXmls(projects)
    xmlFiles = {};
    for i = 1:numel(projects)
        projPath = projects{i};
        xmlDir   = fullfile(projPath, 'data', 'xml');
        if isfolder(xmlDir)
            d = dir(fullfile(xmlDir, '*.xml'));
            xmlFiles = [xmlFiles, fullfile({d.folder}, {d.name})]; 
        else
            warning('Expected XML folder missing: %s', xmlDir);
        end
    end
end
