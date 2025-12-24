function plotClassificationMetrics(classStats)
% plotClassificationMetrics - Displays classification performance metrics
% for the predicted impact areas.

    if nargin < 1 || isempty(classStats)
        error('plotClassificationMetrics: no data provided.');
    end

    % === Support both NEW and OLD field names ===
    if isfield(classStats, 'pctCorrectAll')
        overallCorrect   = classStats.pctCorrectAll;
    elseif isfield(classStats, 'overallCorrect')
        overallCorrect   = classStats.overallCorrect;
    else
        error('Missing overallCorrect field.');
    end

    if isfield(classStats, 'pctRedCorrectAmongRed')
        redHitRate       = classStats.pctRedCorrectAmongRed;
    elseif isfield(classStats, 'redHitRate')
        redHitRate       = classStats.redHitRate;
    else
        error('Missing redHitRate field.');
    end

    if isfield(classStats, 'pctMisGreenAmongNonGreen')
        misGreenRate     = classStats.pctMisGreenAmongNonGreen;
    elseif isfield(classStats, 'misGreenRate')
        misGreenRate     = classStats.misGreenRate;
    else
        error('Missing misGreenRate field.');
    end

    % === Labels (English) ===
    labels = { ...
        'Overall Correct Classification', ...
        'Correct Classification of Red Missiles', ...
        'Non-Green Missiles Misclassified as Green'};

    values = [overallCorrect, redHitRate, misGreenRate];

    % === Plot ===
    figure('Name','Classification Metrics','NumberTitle','off');
    bar(values, 0.6);
    set(gca,'XTick',1:3,'XTickLabel',labels, 'XTickLabelRotation',25);
    ylabel('Percentage (%)');
    title('Impact Area Classification Metrics');
    ylim([0 100]);
    grid on;

    % === Print to MATLAB console ===
    fprintf('\n=== Classification Metrics ===\n');
    fprintf('Overall correct classification:             %.1f %%\n', overallCorrect);
    fprintf('Correct classification among red missiles:  %.1f %%\n', redHitRate);
    fprintf('Non-green misclassified as green:          %.1f %%\n', misGreenRate);
end
