function runSimulation(missiles, interceptors, statesCell, P_updateCell, ...
    A_params, B, C, Qf, Rf, Qtrue, Rtrue, ...
    missile_plots, kf_plots, ictr_plots, ...
    explosion_plots, trail_plots, statusHandle, ...
    v_interceptor, explosion_distance, dt, g, ...
    openAreas, redTargets, ui)
% runSimulation - main loop for missile / interceptor / EKF simulation.
% Includes:
%   - Impact point prediction from EKF state (with drag)
%   - Filter stability check based on covariance and impact stability
%   - Launching interceptors only after filter is stable and impact is non-green
%   - Plotting estimated impact point on the ground for each missile
%   - Logging data for RMSE, covariance, Kalman gain, innovation,
%     classification metrics, interception stats, and measured trajectories.

% ==== Argument check ====
if nargin ~= 24
    error('runSimulation:ArgCount','Expected 24 inputs, got %d', nargin);
end

num_missiles     = numel(missiles);
num_interceptors = numel(interceptors);

if numel(statesCell) ~= num_missiles || numel(P_updateCell) ~= num_missiles
    error('runSimulation:SizeMismatch', ...
        'statesCell and P_updateCell must each have %d cells.', num_missiles);
end

% ===== Setup max simulation length =====
maxLen = 0;
for j = 1:num_missiles
    maxLen = max(maxLen, numel(missiles(j).x_real));
end

% ===== Store main axes handle in appdata (for zoom) =====
axMain = [];
if exist('statusHandle','var') && isgraphics(statusHandle)
    axMain = ancestor(statusHandle,'axes');
    if ~isempty(axMain) && ishghandle(axMain)
        if isstruct(ui) && isfield(ui,'fig') && ishandle(ui.fig)
            setappdata(ui.fig,'simAxes', axMain);
        end
    end
end

% ===== Plots for predicted impact points =====
if ~isempty(axMain) && ishghandle(axMain)
    axImpact = axMain;
else
    axImpact = gca;
end
impact_est_plots = gobjects(1, num_missiles);
for j = 1:num_missiles
    if j == 1
        impact_est_plots(j) = plot(axImpact, nan, nan, 'v', ...
            'MarkerFaceColor', missiles(j).color, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerSize', 8, ...
            'LineStyle', 'none', ...
            'DisplayName', sprintf('Impact est M%d', j));
    else
        impact_est_plots(j) = plot(axImpact, nan, nan, 'v', ...
            'MarkerFaceColor', missiles(j).color, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerSize', 8, ...
            'LineStyle','none', ...
            'HandleVisibility','off');
    end
end

% ===== Initialize explosions list in appdata =====
if isstruct(ui) && isfield(ui,'fig') && ishandle(ui.fig)
    emptyEx = struct('x',{},'y',{},'step',{},'missile',{},'interceptor',{},'hit',{});
    setappdata(ui.fig,'explosions', emptyEx);
end

% ===== Histories =====
P_history          = cell(1,num_missiles);
K_history          = cell(1,num_missiles);
innovation_history = cell(1,num_missiles);
sqErrorsX          = cell(1,num_missiles);
sqErrorsY          = cell(1,num_missiles);
measX              = cell(1,num_missiles);   % measured X (before filter)
measY              = cell(1,num_missiles);   % measured Y

% impact and covariance traces history for stability checks
impactHistory      = cell(1,num_missiles);   % estimated impact X over time
traceHistory       = cell(1,num_missiles);   % trace of position covariance
launchAuthorized   = false(1, num_missiles); % per-missile launch flag

exploded_count = 0;

% parameters for stability checks
minStepsBeforeLaunch   = 20;     % do not launch before we have some measurements
impactWindow           = 6;      % number of steps for impact stability window
impactTol              = 150;    % [m] max change in predicted impact within window
traceWindow            = 10;     % number of steps for covariance stability window
traceAbsTol            = 1e3;    % absolute tolerance on trace variation (pos)
traceRelTol            = 0.2;    % relative tolerance on trace variation

% ===== Main loop over time =====
for i = 1:maxLen

    % --- EKF step for each missile ---
    for j = 1:num_missiles
        if isfield(missiles(j),'exploded') && missiles(j).exploded
            continue;
        end
        if i > numel(missiles(j).x_real)
            continue;
        end

        x_true = missiles(j).x_real(i);
        y_true = missiles(j).y_real(i);

        x_current = statesCell{j};
        P_current = P_updateCell{j};

        [x_updated, P_updated, K, zX, zY, innovation] = kalmanFilter('update', ...
            x_current, P_current, A_params, B, C, Qf, Rf, Qtrue, Rtrue, g, x_true, y_true);

        statesCell{j}   = x_updated;
        P_updateCell{j} = P_updated;

        % store histories
        if isempty(P_history{j}), P_history{j} = {}; end
        if isempty(K_history{j}), K_history{j} = {}; end
        if isempty(innovation_history{j}), innovation_history{j} = {}; end

        P_history{j}{end+1}          = P_updated;
        K_history{j}{end+1}          = K;
        innovation_history{j}{end+1} = innovation;

        % squared errors
        sqErrorsX{j}(end+1) = (x_updated(1) - x_true)^2;
        sqErrorsY{j}(end+1) = (x_updated(2) - y_true)^2;

        % store measured positions (before filter)
        measX{j}(end+1) = zX;
        measY{j}(end+1) = zY;

        % update true path plot
        set(missile_plots(j), ...
            'XData', missiles(j).x_real(1:i), ...
            'YData', missiles(j).y_real(1:i));

        % update KF track plot (append point)
        xd = get(kf_plots(j),'XData');
        yd = get(kf_plots(j),'YData');
        if isempty(xd), xd = []; yd = []; end
        set(kf_plots(j), ...
            'XData',[xd, x_updated(1)], ...
            'YData',[yd, x_updated(2)]);

        % === predict impact point from current filter state ===
        x_impact_est = predictImpactX(x_updated, A_params, dt, g);
        impactHistory{j}(end+1) = x_impact_est;

        % update predicted impact point plot (on ground y=0)
        set(impact_est_plots(j), 'XData', x_impact_est, 'YData', 0);

        % === track covariance trace for position (x,y) ===
        Ppos = P_updated(1:2, 1:2);
        tracePos = trace(Ppos);
        traceHistory{j}(end+1) = tracePos;

        % === decide if filter is "stable enough" and impact is non-green ===
        if ~launchAuthorized(j) && i >= minStepsBeforeLaunch
            stable = isFilterStable(traceHistory{j}, traceWindow, traceAbsTol, traceRelTol, ...
                                    impactHistory{j}, impactWindow, impactTol);

            % classify impact using estimated impact point
            inRed   = areas('isInAnyRedTarget', x_impact_est, redTargets);
            inGreen = areas('isInOpenArea',     x_impact_est, openAreas);

            % we want to intercept if impact is NOT green
            wantsIntercept = ~inGreen;

            if stable && wantsIntercept
                launchAuthorized(j) = true;
            end
        end
    end

    % --- Interceptor motion and interception checks ---
    for k = 1:num_interceptors
        targ = interceptors(k).target;
        if targ < 1 || targ > num_missiles
            continue;
        end
        if i > numel(missiles(targ).x_real)
            continue;
        end
        if isfield(missiles(targ),'exploded') && missiles(targ).exploded
            continue;
        end

        % do not move this interceptor until launchAuthorized for its target
        if ~launchAuthorized(targ)
            % keep interceptor at initial position until launch is authorized
            set(ictr_plots(k), ...
                'XData',interceptors(k).x, ...
                'YData',interceptors(k).y);
            continue;
        end

        % ===== move interceptor towards estimated target state (with step clamping) =====
        dx   = statesCell{targ}(1) - interceptors(k).x;
        dy   = statesCell{targ}(2) - interceptors(k).y;
        dist_pre = hypot(dx, dy);   % distance before move

        if dist_pre > 0
            stepLen = v_interceptor * dt;        % how far it can move this step
            moveLen = min(stepLen, dist_pre);    % do not overshoot

            ux = dx / dist_pre;
            uy = dy / dist_pre;

            interceptors(k).x = interceptors(k).x + moveLen * ux;
            interceptors(k).y = interceptors(k).y + moveLen * uy;
        end

        % update interceptor trail
        interceptors(k).x_hist(end+1) = interceptors(k).x;
        interceptors(k).y_hist(end+1) = interceptors(k).y;
        set(trail_plots(k), ...
            'XData',interceptors(k).x_hist, ...
            'YData',interceptors(k).y_hist);

        % ===== check explosion condition in estimated space (after move) =====
        dx_est    = statesCell{targ}(1) - interceptors(k).x;
        dy_est    = statesCell{targ}(2) - interceptors(k).y;
        dist_after = hypot(dx_est, dy_est);   % distance after move

        if dist_after < explosion_distance
            interceptors(k).engaged   = true;
            interceptors(k).detonated = true;

            % 1) black X at interceptor location (explosion marker always)
            set(explosion_plots(targ), ...
                'XData', interceptors(k).x, ...
                'YData', interceptors(k).y, ...
                'Color', [0 0 0]);  % black for generic explosion

            % 2) compute true distance to missile
            dx_true = missiles(targ).x_real(i) - interceptors(k).x;
            dy_true = missiles(targ).y_real(i) - interceptors(k).y;
            d_true  = hypot(dx_true, dy_true);

            fprintf('Step %d | Missile %d | Interceptor %d | dist(est)=%.3f m | d_true=%.3f m\n', ...
                i, targ, k, dist_after, d_true);

            hit = (d_true <= 6);   % success condition

            if hit
                missiles(targ).exploded = true;
                exploded_count = exploded_count + 1;

                % explosion marker turns red on successful kill
                set(explosion_plots(targ), 'Color', [1 0 0]);

                if isstruct(ui) && isfield(ui,'successText') && isgraphics(ui.successText)
                    pct_now = 100 * exploded_count / max(1, num_missiles);
                    set(ui.successText,'String', ...
                        sprintf('Success: %.1f%% (%d/%d)', pct_now, exploded_count, num_missiles));
                end
            end

            % 3) save explosion info for zoom
            if isstruct(ui) && isfield(ui,'fig') && ishandle(ui.fig)
                ex = getappdata(ui.fig,'explosions');
                if ~isstruct(ex) || isempty(ex)
                    ex = struct('x',{},'y',{},'step',{},'missile',{},'interceptor',{},'hit',{});
                end
                ex(end+1) = struct( ...
                    'x',interceptors(k).x, ...
                    'y',interceptors(k).y, ...
                    'step',i, ...
                    'missile',targ, ...
                    'interceptor',k, ...
                    'hit',hit); %#ok<AGROW>
                setappdata(ui.fig,'explosions', ex);
            end

            % 4) interceptor is done
            interceptors(k).target = -1;
        end

        % update interceptor marker
        set(ictr_plots(k), ...
            'XData',interceptors(k).x, ...
            'YData',interceptors(k).y);
    end

    % --- Status text and GUI update ---
    pct = 100 * exploded_count / max(1, num_missiles);
    if exist('statusHandle','var') && isgraphics(statusHandle)
        set(statusHandle,'String', ...
            sprintf('Step %d/%d | Successful kills: %d (%.1f%%)', ...
            i, maxLen, exploded_count, pct));
    end
    if isstruct(ui) && isfield(ui,'successText') && isgraphics(ui.successText)
        set(ui.successText,'String', ...
            sprintf('Success: %.1f%% (%d/%d)', pct, exploded_count, num_missiles));
    end

    drawnow limitrate;
end

% ===== Classification metrics (true vs estimated impact region) =====
trueRegion = cell(1,num_missiles);   % 'green' / 'red' / 'neutral'
estRegion  = cell(1,num_missiles);   % same

for j = 1:num_missiles
    % true impact from real trajectory
    x_final_true = missiles(j).x_real(end);

    inGreenTrue = areas('isInOpenArea',      x_final_true, openAreas);
    inRedTrue   = areas('isInAnyRedTarget',  x_final_true, redTargets);

    if inGreenTrue
        trueRegion{j} = 'green';
    elseif inRedTrue
        trueRegion{j} = 'red';
    else
        trueRegion{j} = 'neutral';
    end

    % estimated impact from last EKF-based prediction
    if isempty(impactHistory{j})
        estRegion{j} = 'unknown';
    else
        x_final_est = impactHistory{j}(end);
        inGreenEst = areas('isInOpenArea',     x_final_est, openAreas);
        inRedEst   = areas('isInAnyRedTarget', x_final_est, redTargets);

        if inGreenEst
            estRegion{j} = 'green';
        elseif inRedEst
            estRegion{j} = 'red';
        else
            estRegion{j} = 'neutral';
        end
    end
end

N = num_missiles;
maskRedTrue      = strcmp(trueRegion,'red');
maskNonGreenTrue = ~strcmp(trueRegion,'green');  % red + neutral (אמיתית לא ירוקה)

numCorrectAll = sum(strcmp(trueRegion, estRegion));
numRed        = sum(maskRedTrue);
numNonGreen   = sum(maskNonGreenTrue);

pctCorrectAll = 100 * numCorrectAll / max(1, N);
pctRedCorrect = 100 * sum(maskRedTrue & strcmp(estRegion,'red')) / max(1, numRed);
pctMisGreenAmongNonGreen = 100 * sum(maskNonGreenTrue & strcmp(estRegion,'green')) / max(1, numNonGreen);

classStats = struct( ...
    'pctCorrectAll',            pctCorrectAll, ...
    'pctRedCorrectAmongRed',    pctRedCorrect, ...
    'pctMisGreenAmongNonGreen', pctMisGreenAmongNonGreen, ...
    'trueRegion',               {trueRegion}, ...
    'estRegion',                {estRegion} ...
);

% ===== Interception statistics for non-green missiles (אמיתי) =====
totalNonGreen       = 0;   % missiles whose true impact is NOT in green
interceptedNonGreen = 0;

for j = 1:num_missiles
    x_final = missiles(j).x_real(end);

    inGreen = areas('isInOpenArea', x_final, openAreas);
    inRed   = areas('isInAnyRedTarget', x_final, redTargets); %#ok<NASGU> % לא חובה בהמשך

    if ~inGreen
        totalNonGreen = totalNonGreen + 1;
        if isfield(missiles(j),'exploded') && missiles(j).exploded
            interceptedNonGreen = interceptedNonGreen + 1;
        end
    end
end

successPctAll      = 100 * exploded_count      / max(1, num_missiles);
successPctNonGreen = 100 * interceptedNonGreen / max(1, totalNonGreen);

interceptStats = struct( ...
    'totalMissiles',        num_missiles, ...
    'explodedCount',        exploded_count, ...
    'totalNonGreen',        totalNonGreen, ...
    'interceptedNonGreen',  interceptedNonGreen, ...
    'successPctAll',        successPctAll, ...
    'successPctNonGreen',   successPctNonGreen ...
);

fprintf('\n=== Interception statistics ===\n');
fprintf('Total missiles: %d\n', num_missiles);
fprintf('Total successful interceptions: %d (%.1f%% of all)\n', ...
    exploded_count, successPctAll);
fprintf('Non-green missiles (true impact not in open area): %d\n', totalNonGreen);
fprintf('Successful interceptions among non-green missiles: %d (%.1f%%)\n', ...
    interceptedNonGreen, successPctNonGreen);

% ===== Save data to GUI appdata =====
if isstruct(ui) && isfield(ui,'fig') && ishandle(ui.fig)
    simData = struct( ...
        'P_history',          {P_history}, ...
        'K_history',          {K_history}, ...
        'innovation_history', {innovation_history}, ...
        'sqErrorsX',          {sqErrorsX}, ...
        'sqErrorsY',          {sqErrorsY}, ...
        'measX',              {measX}, ...
        'measY',              {measY}, ...
        'missiles',           missiles, ...
        'classStats',         classStats, ...
        'interceptStats',     interceptStats ...
    );
    setappdata(ui.fig,'simData', simData);
end

if exist('statusHandle','var') && isgraphics(statusHandle)
    set(statusHandle,'String','Simulation complete!');
end
if isstruct(ui) && isfield(ui,'successText') && isgraphics(ui.successText)
    pct_final = 100 * exploded_count / max(1, num_missiles);
    set(ui.successText,'String', ...
        sprintf('Success: %.1f%% (%d/%d)', pct_final, exploded_count, num_missiles));
end
end

% =====================================================================
% Predict impact X position from current EKF state using same ballistic
% model (with drag) as in generateMissiles / kalmanFilter.
function x_impact = predictImpactX(x_state, A_params, dt, g)

x  = x_state(1);
y  = max(x_state(2), 0);
vx = x_state(3);
vy = x_state(4);

m          = A_params.m;
Cd         = A_params.Cd;
Aref       = A_params.Aref;
rho0       = A_params.rho0;
H          = A_params.H;
beta_scale = A_params.beta_scale;

maxSteps = 200000;
for step = 1:maxSteps %#ok<NASGU>
    rho_h  = rho0 * exp(-max(y,0) / H);
    beta_h = 0.5 * rho_h * Cd * Aref / m * beta_scale;

    v  = sqrt(vx^2 + vy^2) + eps;
    ax = -beta_h * v * vx;
    ay = -g      - beta_h * v * vy;

    x  = x  + vx * dt;
    y  = y  + vy * dt;
    vx = vx + ax * dt;
    vy = vy + ay * dt;

    if y <= 0
        break;
    end
end

x_impact = x;
end

% =====================================================================
% Decide if the filter is "stable enough" based on covariance trace and
% impact point stability over recent windows.
function stable = isFilterStable(traceHist, traceWindow, traceAbsTol, traceRelTol, ...
                                 impactHist, impactWindow, impactTol)

stable = false;

% need enough history for both checks
if numel(traceHist) < traceWindow || numel(impactHist) < impactWindow
    return;
end

recentTrace  = traceHist(end-traceWindow+1:end);
recentImpact = impactHist(end-impactWindow+1:end);

tMax = max(recentTrace);
tMin = min(recentTrace);
dTrace = tMax - tMin;

if tMax <= 0
    return;
end

relVar = dTrace / tMax;

% covariance stability condition
if dTrace > traceAbsTol || relVar > traceRelTol
    return;
end

% impact stability condition
iMax = max(recentImpact);
iMin = min(recentImpact);
dImpact = iMax - iMin;

if dImpact > impactTol
    return;
end

stable = true;
end
