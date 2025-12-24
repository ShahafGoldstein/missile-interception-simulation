function plotKalmanGainOverTime(K_history)
% plotKalmanGainOverTime - Plots the evolution over time of the Kalman Gain's
%                          Frobenius norm for each missile.
%
% USAGE:
%   plotKalmanGainOverTime(K_history)
%
% INPUT:
%   K_history : A cell array with length equal to the number of missiles.
%               For each missile j, K_history{j} is a cell array that contains 
%               the Kalman Gain matrix K at each simulation time step.
%
% The function computes the Frobenius norm of the Kalman Gain matrix (i.e. norm(K, 'fro'))
% at each time step and then plots these values versus the simulation step.
%
% This plot helps you investigate how the filter's gain evolves during the flight.
%
% Example:
%   plotKalmanGainOverTime(K_history);

    num_missiles = length(K_history);

    figure('Name','Kalman Gain Over Time','NumberTitle','off');
    hold on; grid on;
    xlabel('Simulation Step');
    ylabel('Frobenius Norm of Kalman Gain');
    title('Evolution of Kalman Gain Over Time');

    for j = 1:num_missiles
        nSteps = length(K_history{j});
        gain_norms = nan(1, nSteps);
        for t = 1:nSteps
            % Retrieve the Kalman Gain matrix at time step t for missile j.
            K = K_history{j}{t};
            if isempty(K)
                continue;
            end
            gain_norms(t) = norm(K, 'fro'); % Frobenius norm of K.
        end
        plot(1:nSteps, gain_norms, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Missile %d', j));
    end

    legend('Location', 'best');
    hold off;
end
