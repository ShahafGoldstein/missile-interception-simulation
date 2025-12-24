function analyzeRMSE(sqErrorsX, sqErrorsY, segmentMode)
% analyzeRMSE - Computes the RMSE for each missile over a selected time segment,
%               displays a bar chart, and also plots the instantaneous 2D error
%               over time for each missile.
%
% USAGE:
%   analyzeRMSE(sqErrorsX, sqErrorsY);                % full trajectory (default)
%   analyzeRMSE(sqErrorsX, sqErrorsY, 'full');        % full trajectory
%   analyzeRMSE(sqErrorsX, sqErrorsY, 'last1000');    % last 1000 steps
%   analyzeRMSE(sqErrorsX, sqErrorsY, 'last500');     % last 500 steps
%   analyzeRMSE(sqErrorsX, sqErrorsY, 'last100');     % last 100 steps
%
% INPUTS:
%   sqErrorsX - cell array: sqErrorsX{j}(t) = (x_est - x_true)^2 at step t, missile j
%   sqErrorsY - cell array: sqErrorsY{j}(t) = (y_est - y_true)^2 at step t, missile j
%   segmentMode - optional string: 'full' (default), 'last1000', 'last500', 'last100'
%
% The function:
%   1) Selects the time window according to segmentMode for each missile.
%   2) Computes RMSE for X, Y, and combined 2D over that window.
%   3) Prints the results to the command window.
%   4) Displays a bar chart of the final RMSE for each missile.
%   5) Plots the instantaneous 2D error over the selected time window.

    if nargin < 3 || isempty(segmentMode)
        segmentMode = 'full';
    end

    % Window sizes (in steps) for different modes
    switch lower(segmentMode)
        case 'full'
            winLen = Inf;   % use all steps
            modeName = 'Full trajectory';
            modeNameHeb = 'כל התנועה';
        case 'last1000'
            winLen = 1000;
            modeName = 'Last 1000 steps';
            modeNameHeb = '1000 צעדים אחרונים';
        case 'last500'
            winLen = 500;
            modeName = 'Last 500 steps';
            modeNameHeb = '500 צעדים אחרונים';
        case 'last100'
            winLen = 100;
            modeName = 'Last 100 steps';
            modeNameHeb = '100 צעדים אחרונים';
        otherwise
            warning('Unknown segmentMode "%s". Using full trajectory.', segmentMode);
            winLen = Inf;
            modeName = 'Full trajectory';
            modeNameHeb = 'כל התנועה';
    end

    % Number of missiles
    num_missiles = length(sqErrorsX);
    final_rmse = nan(1, num_missiles);

    fprintf('\n===== RMSE analysis (%s) =====\n', modeName);

    % Loop over missiles to compute RMSE in the selected window
    for j = 1:num_missiles
        if isempty(sqErrorsX{j}) || isempty(sqErrorsY{j})
            fprintf('Missile %d: No valid data for RMSE.\n', j);
            continue;
        end

        nStepsTotal = length(sqErrorsX{j});
        if isinf(winLen) || winLen >= nStepsTotal
            idxStart = 1;
        else
            idxStart = max(1, nStepsTotal - winLen + 1);
        end
        idxEnd = nStepsTotal;

        idxRange = idxStart:idxEnd;

        sx = sqErrorsX{j}(idxRange);
        sy = sqErrorsY{j}(idxRange);

        % Compute RMSE for X and Y in the selected window
        x_rmse = sqrt(mean(sx));
        y_rmse = sqrt(mean(sy));

        % Combined 2D RMSE
        mse_xy = mean(sx + sy);
        final_rmse(j) = sqrt(mse_xy);

        % Print RMSE values to the command window
        fprintf(['Missile %d RMSE (%s): %.2f meters  ', ...
                 '(X RMSE = %.2f, Y RMSE = %.2f), steps [%d .. %d] out of %d\n'], ...
            j, modeName, final_rmse(j), x_rmse, y_rmse, idxStart, idxEnd, nStepsTotal);
    end

    % ------------------ Bar Chart for Final RMSE ------------------
    figure('Name', sprintf('Final RMSE - %s', modeName), 'NumberTitle','off');
    bar(final_rmse, 0.6);
    xlabel('Missile Index');
    ylabel('Final RMSE (m)');
    title(sprintf('Final RMSE of Each Missile (%s)', modeNameHeb));
    grid on;

    % ------------------ Instantaneous RMSE Over Time ------------------
    % Determine the maximum time steps across all missiles (for the selected window).
    maxLen = 0;
    idxRanges = cell(1, num_missiles);
    for j = 1:num_missiles
        if isempty(sqErrorsX{j}) || isempty(sqErrorsY{j})
            idxRanges{j} = [];
            continue;
        end
        nStepsTotal = length(sqErrorsX{j});
        if isinf(winLen) || winLen >= nStepsTotal
            idxStart = 1;
        else
            idxStart = max(1, nStepsTotal - winLen + 1);
        end
        idxEnd = nStepsTotal;
        idxRanges{j} = idxStart:idxEnd;
        maxLen = max(maxLen, length(idxRanges{j}));
    end

    % Create a matrix to hold the instantaneous RMSE values
    rmse_time = nan(num_missiles, maxLen);
    for j = 1:num_missiles
        idxRange = idxRanges{j};
        if isempty(idxRange)
            continue;
        end
        nStepsWin = length(idxRange);
        for t = 1:nStepsWin
            k = idxRange(t);
            rmse_time(j, t) = sqrt(sqErrorsX{j}(k) + sqErrorsY{j}(k));
        end
    end

    % Plot the instantaneous error over time for each missile
    figure('Name', sprintf('RMSE Over Time - %s', modeName), 'NumberTitle','off');
    hold on; grid on;
    for j = 1:num_missiles
        plot(rmse_time(j,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Missile %d', j));
    end
    xlabel('Simulation Step (within selected window)');
    ylabel('Instantaneous 2D RMSE (m)');
    title(sprintf('Instantaneous 2D RMSE Over Time (%s)', modeNameHeb));
    legend('Location','best');
    hold off;
end
