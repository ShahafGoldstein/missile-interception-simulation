function analyzeParameterSensitivity(sigmaQ_values, sigmaR, dt, v0, g, v_interceptor, explosion_distance)
% analyzeParameterSensitivity - Sweep over sigmaQ and measure final RMSE.
%
% USAGE:
%   analyzeParameterSensitivity(sigmaQ_values, sigmaR, dt, v0, g, v_interceptor, explosion_distance);

    numTests = length(sigmaQ_values);
    rmse_results = zeros(numTests, 1);  % ממוצע RMSE לכל σ_Q

    for i = 1:numTests
        sigmaQ_current = sigmaQ_values(i);
        fprintf('Running simulation for sigmaQ = %.3g...\n', sigmaQ_current);

        % --- פרמטרים קבועים להרצה ---
        num_missiles = 5;
        num_interceptors = 3;

        % אזורים
        openAreas = areas('generateOpenAreas', 3);
        redTargets = areas('generateRedTargets', 3, openAreas);

        % טילים ומיירטים
        missiles = generateMissiles(num_missiles, v0, g, dt, redTargets, openAreas);
        interceptorsStruct = interceptors('generateInterceptors', num_interceptors);
        interceptorsStruct = interceptors('assignTargetsToInterceptors', interceptorsStruct, missiles);

        % EKF
        [A, B, C, Q, R, P_cell, states_cell] = kalmanFilter('initialize', ...
            num_missiles, missiles, sigmaQ_current, sigmaR, dt, v0, g);

        % גרפים
        [missile_plots, kf_plots, ictr_plots, explosion_plots, trail_plots, statusHandle] = ...
            initializePlots(missiles, interceptorsStruct, redTargets, openAreas);

        % --- UI דמי (חלון לא נראה) כדי לאחסן simData ב-appdata ---
        ui.fig = figure('Visible','off','Name','psweep-ui','NumberTitle','off');

        % ריצה (הנתונים נשמרים ב-appdata של ui.fig)
        runSimulation(missiles, interceptorsStruct, states_cell, P_cell, ...
            A, B, C, Q, R, ...
            missile_plots, kf_plots, ictr_plots, ...
            explosion_plots, trail_plots, statusHandle, ...
            v_interceptor, explosion_distance, dt, g, ui);

        % --- חילוץ RMSE מה-appdata ---
        simData = getappdata(ui.fig,'simData');
        if ~isempty(simData) && isfield(simData,'sqErrorsX') && isfield(simData,'sqErrorsY')
            num_m = numel(simData.sqErrorsX);
            final_rmse = nan(1,num_m);
            for j = 1:num_m
                if ~isempty(simData.sqErrorsX{j})
                    mse_xy = mean(simData.sqErrorsX{j} + simData.sqErrorsY{j});
                    final_rmse(j) = sqrt(mse_xy);
                end
            end
            rmse_results(i) = mean(final_rmse(~isnan(final_rmse)));
        else
            warning('No simData/sqErrors available for sigmaQ=%.3g', sigmaQ_current);
            rmse_results(i) = NaN;
        end

        % ניקוי
        try, close(ui.fig); catch, end
        close all;
    end

    % גרף רגישות
    figure('Name','Parameter Sensitivity: RMSE vs sigmaQ','NumberTitle','off');
    plot(sigmaQ_values, rmse_results, '-o', 'LineWidth', 1.5);
    xlabel('sigmaQ (Process Noise Standard Deviation)');
    ylabel('Average Final RMSE (m)');
    title('Sensitivity of Final RMSE to sigmaQ');
    grid on;
end
