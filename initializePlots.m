function [missile_plots, kf_plots, interceptor_plots, explosion_plots, ...
          trail_plots, statusHandle] = initializePlots(missiles, interceptors, ...
                                                       redTargets, openAreas)
    figure('Name','Missile Interception','NumberTitle','off');
    hold on; grid on;
    xlabel('Horizontal Distance (m)');
    ylabel('Height (m)');
    title('Missile Interception Simulation (Ballistic Model)');

    num_missiles     = numel(missiles);
    num_interceptors = numel(interceptors);

    missile_plots     = gobjects(1, num_missiles);
    kf_plots          = gobjects(1, num_missiles);
    interceptor_plots = gobjects(1, num_interceptors);
    explosion_plots   = gobjects(1, num_missiles);
    trail_plots       = gobjects(1, num_interceptors);

    % ---------- Plot missiles ----------
    for i = 1:num_missiles
        plot(missiles(i).x_real, missiles(i).y_real, '--', ...
            'Color', missiles(i).color, 'LineWidth', 1.5, ...
            'HandleVisibility','off');

        missile_plots(i) = plot(nan, nan, '.', ...
            'Color', missiles(i).color, ...
            'HandleVisibility','off');

        kf_plots(i) = plot(nan, nan, 'o', ...
            'MarkerSize', 6, ...
            'Color', missiles(i).color, ...
            'DisplayName', ['KF (Missile ', num2str(i), ')']);

        explosion_plots(i) = plot(nan, nan, 'x', ...
            'Color', [0, 0, 0], ...   % שחור כברירת מחדל
            'MarkerSize', 12, ...
            'LineWidth', 2, ...
            'HandleVisibility','off');

    end

    % ---------- Plot interceptors (עם סניטציית צבע) ----------
    cmap = lines(max(1, num_interceptors));
    hasColorField = ~isempty(interceptors) && isfield(interceptors, 'color');

    for i = 1:num_interceptors
        if hasColorField
            c = pickColor(interceptors(i).color, i, cmap);
        else
            c = pickColor([], i, cmap);
        end

        interceptor_plots(i) = plot(nan, nan, 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', c, ...
            'Color', c, ...
            'DisplayName', ['Interceptor ', num2str(i)]);

        trail_plots(i) = plot(nan, nan, '-', ...
            'Color', c, ...
            'LineWidth', 1.5, ...
            'HandleVisibility', 'off');
    end

    % ---------- Red targets ----------
    for i = 1:size(redTargets,1)
        x_coords = [redTargets(i,1), redTargets(i,2)];
        if i == 1
            plot(x_coords, [0,0], 'r', 'LineWidth', 8, 'DisplayName', 'Red Target');
        else
            plot(x_coords, [0,0], 'r', 'LineWidth', 8, 'HandleVisibility','off');
        end
    end

    % ---------- Green open areas ----------
    for i = 1:size(openAreas,1)
        xMin = openAreas(i,1); xMax = openAreas(i,2);
        if i == 1
            plot([xMin, xMax], [0, 0], 'g', 'LineWidth', 8, 'DisplayName', 'Open Area');
        else
            plot([xMin, xMax], [0, 0], 'g', 'LineWidth', 8, 'HandleVisibility','off');
        end
    end

    % ---------- Dummy plots for single Legend entries ----------
    plot(nan, nan, '--', 'Color','k', 'LineWidth',1.5, 'DisplayName','True Path');
    % הוסר 'Measured' כי לא מציירים מדידות בפועל
    plot(nan, nan, 'x',  'Color','r', 'MarkerSize',12,'LineWidth',2, 'DisplayName','Explosion');

    legend('Location','best');

    % ---------- Status text ----------
    statusHandle = text(0.01, 0.95, '', ...
        'Units','normalized', ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','top', ...
        'FontSize',10, ...
        'Color','k', ...
        'BackgroundColor','w');

    % ===== Nested helpers =====
    function c = pickColor(val, idx, cm)
        default = cm(mod(idx-1, size(cm,1)) + 1, :);
        c = default;
        if nargin < 1 || isempty(val), return; end

        if ischar(val) || (isstring(val) && isscalar(val))
            c = charColorToRGB(char(val), default);
        elseif isnumeric(val) && numel(val) == 3 && all(isfinite(val))
            v = double(val(:))';
            if max(v) > 1
                v = v / 255; % תמיכה ב-[0..255]
            end
            c = max(0, min(1, v)); % גזירה ל-[0..1]
        end
    end

    function c = charColorToRGB(ch, default)
        switch lower(ch)
            case 'r', c = [1 0 0];
            case 'g', c = [0 1 0];
            case 'b', c = [0 0 1];
            case 'c', c = [0 1 1];
            case 'm', c = [1 0 1];
            case 'y', c = [1 1 0];
            case 'k', c = [0 0 0];
            case 'w', c = [1 1 1];
            otherwise, c = default;
        end
    end
end
