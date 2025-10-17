function h = plotBall(ax,loc,color,radius, handle)
    hold(ax,'on');
    % The axes should stay aligned
    
    %original electrode locations:
    xe = loc(1);
    ye = loc(2);
    ze = loc(3);
    %generate sphere coordinates (radius 1, 20-by-20 faces)
    [X, Y, Z] = sphere(100);
    
    %place the sphere into the spot:
    X = radius * X + xe;
    Y = radius * Y + ye;
    Z = radius * Z + ze;

    if ~isempty(handle)
        h = handle;
        set(h, ...
            'XData', X, ...
            'YData', Y, ...
            'ZData', Z, ...
            'Visible', 1, ...
            'FaceColor',color);
    else
        h=surf(ax,X, Y, Z, ...
            'FaceColor', color,'FaceLighting','none',...
            'CDataMapping', 'direct','LineStyle','none');
    end
    hold(ax,'off')
end