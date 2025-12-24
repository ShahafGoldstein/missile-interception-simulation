function plotInnovation(innovation_history)
% plotInnovation - Plots the evolution of the innovation norm over time for each missile.
%
% USAGE:
%   plotInnovation(innovation_history)
%
% INPUT:
%   innovation_history : A cell array where each element corresponds to one missile.
%                        For missile j, innovation_history{j} should be either:
%                          - a vector containing the norm of the innovation at each simulation step, or
%                          - a cell array where each cell contains the innovation vector at a particular time step.
%
% The function computes the norm of the innovation at each simulation step and then
% plots these values versus the simulation step for each missile.
%
% Example:
%   plotInnovation(innovation_history);
%
% This plot can help you analyze the convergence behavior of the Kalman Filter.

    num_missiles = length(innovation_history);
    
    figure('Name', 'Innovation Norm Over Time', 'NumberTitle', 'off');
    hold on; grid on;
    xlabel('Simulation Step');
    ylabel('Innovation Norm');
    title('Evolution of Innovation Norm Over Time');
    
    % For each missile, compute and plot the innovation norm over time.
    for j = 1:num_missiles
        % Determine if the innovation history for missile j is stored as a cell array
        % or as a numeric vector.
        if iscell(innovation_history{j})
            nSteps = length(innovation_history{j});
            norm_values = zeros(1, nSteps);
            for t = 1:nSteps
                % Calculate the norm of the innovation vector at this time step
                norm_values(t) = norm(innovation_history{j}{t});
            end
        else
            % If already a numeric vector of norms, use it directly.
            norm_values = innovation_history{j};
            nSteps = length(norm_values);
        end
        
        % Plot the norm over time for missile j.
        plot(1:nSteps, norm_values, 'LineWidth', 1.5, 'DisplayName', sprintf('Missile %d', j));
    end
    
    legend('Location', 'best');
    hold off;
end
