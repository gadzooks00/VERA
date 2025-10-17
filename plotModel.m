function [surf] = plotModel(ax, model, annotation, coloring, handle)
% plotModel - Plots a 3D model with vertex-based coloring baked in.
%
% ax         - Target axes
% model      - Surface struct with fields 'vert' (Nx3) and 'tri' (Mx3)
% annotation - Scalar values per vertex (controls color)
% coloring   - Nx3 colormap matrix (e.g. jet(256), turbo(256))
%
% The surface color is baked into RGB values so later calls to
% colormap() won't affect it.

    vertexRGB = colorToCData(coloring,annotation);

    % --- Create the trisurf with per-vertex RGB colors ---
    if isempty(handle)
        surf = trisurf(model.tri, ...
            model.vert(:,1), model.vert(:,2), model.vert(:,3), ...
            'Parent', ax, ...
            'FaceColor', 'interp', ...
            'EdgeColor', 'none', ...
            'FaceVertexCData', vertexRGB, ...
            'FaceLighting', 'gouraud', ...
            'BackFaceLighting', 'unlit', ...
            'AmbientStrength', 1);

        % --- Lighting and appearance ---
        material(ax, 'dull');
        light(ax, 'Position', [1 0 0], 'Style', 'local');
        set(ax, 'AmbientLightColor', [1 1 1]);
        camlight(ax, 'headlight');
    
        % --- Axes cleanup ---
        axis(ax, 'equal');
        axis(ax, 'off');
        set(ax, 'Clipping', 'off', ...
            'XColor', 'none', 'YColor', 'none', 'ZColor', 'none', ...
            'XTick', [], 'YTick', []);

    else
        surf = handle;
        set(handle,'FaceVertexCData', vertexRGB);
    end

end
