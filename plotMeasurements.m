function plotMeasurements(measX, measY, missiles)
% plotMeasurements - מציג את המדידות (לפני המסנן) יחד עם המסלולים האמיתיים
% על גרף אחד, עבור כל הטילים.

    num_missiles = numel(measX);

    figure('Name','Measured vs True (All Missiles)','NumberTitle','off');
    hold on; grid on;

    for j = 1:num_missiles
        if isempty(measX{j}) || isempty(measY{j})
            continue;
        end

        zX = measX{j};
        zY = measY{j};

        nMeas = numel(zX);
        nTrue = numel(missiles(j).x_real);
        nMin  = min(nMeas, nTrue);

        c = missiles(j).color;

        % מסלול אמת
        plot(missiles(j).x_real(1:nMin), missiles(j).y_real(1:nMin), ...
            '-', 'Color', c, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('True M%d', j));

        % מדידות (נקודות)
        plot(zX(1:nMin), zY(1:nMin), ...
            'o', 'Color', c, ...
            'MarkerSize', 3, 'MarkerFaceColor','none', ...
            'DisplayName', sprintf('Meas M%d', j));
    end

    xlabel('X [m]');
    ylabel('Y [m]');
    title('True vs Measured Trajectories (All Missiles)');
    legend('Location','bestoutside');
    axis equal;

    % --- השורה שהוספנו: גבול תחתון לציר Y ---
    yMax = ylim;
    ylim([0, yMax(2)]);
    xlim([0, 15000]);
end
