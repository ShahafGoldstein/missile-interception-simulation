function plotInterceptionStats(interceptStats)
% plotInterceptionStats - Plots interception success statistics.
%
% INPUT:
%   interceptStats : struct with fields
%       .successPctAll        - success % over all missiles
%       .successPctNonGreen   - success % over non-green (true impact not in open area)
%       .totalMissiles
%       .explodedCount
%       .totalNonGreen
%       .interceptedNonGreen

    if nargin < 1 || isempty(interceptStats)
        error('plotInterceptionStats: no data provided.');
    end

    labels = {'All missiles', 'Non-green missiles'};
    values = [interceptStats.successPctAll, interceptStats.successPctNonGreen];

    figure('Name','Interception Statistics','NumberTitle','off');
    bar(values, 0.5);
    set(gca,'XTick',1:2,'XTickLabel',labels);
    ylabel('Success rate (%)');
    title('Interception Success Rates');

    ylim([0 100]); % אחוזים מ 0 עד 100
    grid on;

    % הצגת נתונים מספריים גם בחלון הפקודות
    fprintf('\n=== Interception Statistics ===\n');
    fprintf('Total missiles: %d\n', interceptStats.totalMissiles);
    fprintf('Successful interceptions (all): %d (%.1f%%)\n', ...
        interceptStats.explodedCount, interceptStats.successPctAll);
    fprintf('Non-green missiles (true impact not in open area): %d\n', ...
        interceptStats.totalNonGreen);
    fprintf('Successful interceptions among non-green: %d (%.1f%%)\n', ...
        interceptStats.interceptedNonGreen, interceptStats.successPctNonGreen);
end
