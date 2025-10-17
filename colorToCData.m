function CData = colorToCData(coloring, annotation)
    % --- Default annotation handling ---
    if ~exist('annotation','var') || isempty(annotation)
        annotation = ones(size(model.vert,1),1);
    end

    % --- Normalize annotation values to [0, 1] ---
    vmin = min(annotation(:));
    vmax = max(annotation(:));
    if vmax == vmin
        normVals = zeros(size(annotation));
    else
        normVals = (annotation - vmin) / (vmax - vmin);
    end

    % --- Map normalized values to RGBs from the provided colormap ---
    nColors = size(coloring, 1);
    idx = max(1, min(nColors, round(normVals * (nColors - 1)) + 1));
    CData = coloring(idx, :);
end