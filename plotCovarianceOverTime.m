function plotCovarianceOverTime(P_history)
% plotCovarianceOverTime - Plots the evolution of the Kalman Filter covariance trace over time.
%
% USAGE:
%   plotCovarianceOverTime(P_history)
%
% INPUT:
%   P_history : A cell array where each element corresponds to one missile.
%               For missile j, P_history{j} is a cell array containing the covariance
%               matrix (P) at each simulation time step.
%
% The function computes the trace (sum of the diagonal elements) of each covariance matrix
% and plots the results versus the simulation step for each missile.
%
% Example:
%   plotCovarianceOverTime(P_history);
%
% This plot helps you visualize how the uncertainty (as measured by the trace of the covariance)
% evolves as the filter converges during the simulation.

    num_missiles = length(P_history);
    
    % Create a figure for the covariance evolution plot.
    figure('Name', 'Covariance Trace Over Time', 'NumberTitle', 'off');
    hold on; grid on;
    xlabel('Simulation Step');
    ylabel('Trace of Covariance Matrix');
    title('Evolution of Kalman Filter Covariance Trace Over Time');

    % Loop over each missile
    for j = 1:num_missiles
        nSteps = length(P_history{j});
        traceValues = zeros(1, nSteps);
        for t = 1:nSteps
            traceValues(t) = trace(P_history{j}{t});
        end
        plot(1:nSteps, traceValues, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Missile %d', j));
    end
    
    legend('Location', 'best');
    hold off;
end
