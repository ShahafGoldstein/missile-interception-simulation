function missile_interception_simulation_ballistic_rmse()
    clc; close all;

    ui.fig = figure('Name','Controls','NumberTitle','off','Position',[100 100 560 360]);

    % קלטים בסיסיים
    uicontrol(ui.fig,'Style','text','String','Num Missiles:',...
        'Position',[20 315 120 18],'HorizontalAlignment','left','FontWeight','bold');
    ui.mEdit = uicontrol(ui.fig,'Style','edit','String','3','Position',[140 312 60 24]);

    uicontrol(ui.fig,'Style','text','String','Num Interceptors:',...
        'Position',[220 315 130 18],'HorizontalAlignment','left','FontWeight','bold');
    ui.iEdit = uicontrol(ui.fig,'Style','edit','String','2','Position',[355 312 60 24]);

    % --- רעשים (סטיות תקן - אמת בלבד) ---
    uicontrol(ui.fig,'Style','text','String','True process σ_Q (std):',...
        'Position',[20 275 160 18],'HorizontalAlignment','left');
    ui.sQtrue = uicontrol(ui.fig,'Style','edit','String','2','Position',[180 272 60 24]);

    uicontrol(ui.fig,'Style','text','String','True meas. σ_R (std, m):',...
        'Position',[260 275 180 18],'HorizontalAlignment','left');
    ui.sRtrue = uicontrol(ui.fig,'Style','edit','String','10','Position',[440 272 60 24]);

    % --- פרמטרים פיזיקליים מה-GUI ---
    % מהירות הטיל
    uicontrol(ui.fig,'Style','text','String','Missile v0 (m/s):',...
        'Position',[20 245 160 18],'HorizontalAlignment','left');
    ui.vMissile = uicontrol(ui.fig,'Style','edit','String','1000','Position',[180 242 60 24]);

    % מהירות המיירט
    uicontrol(ui.fig,'Style','text','String','Interceptor v (m/s):',...
        'Position',[260 245 180 18],'HorizontalAlignment','left');
    ui.vInterceptor = uicontrol(ui.fig,'Style','edit','String','1000','Position',[440 242 60 24]);

    % מסה
    uicontrol(ui.fig,'Style','text','String','Missile mass m (kg):',...
        'Position',[20 215 160 18],'HorizontalAlignment','left');
    ui.mMass = uicontrol(ui.fig,'Style','edit','String','100','Position',[180 212 60 24]);

    % שטח חתך
    uicontrol(ui.fig,'Style','text','String','Missile A_{ref} (m^2):',...
        'Position',[260 215 180 18],'HorizontalAlignment','left');
    ui.Aref = uicontrol(ui.fig,'Style','edit','String','0.3','Position',[440 212 60 24]);

    % כפתור ריצה
    ui.runBtn = uicontrol(ui.fig,'Style','pushbutton','String','Run Simulation',...
        'Position',[20 185 200 30],'FontWeight','bold','Callback',@runSimCB);

    % כפתורי גרפים
    ui.btnRMSE  = uicontrol(ui.fig,'Style','pushbutton','String','Show RMSE',...
        'Position',[20 145 170 26],'Callback',@rmseCB);
    ui.btnCov   = uicontrol(ui.fig,'Style','pushbutton','String','Covariance Trace',...
        'Position',[210 145 170 26],'Callback',@covCB);
    ui.btnKGain = uicontrol(ui.fig,'Style','pushbutton','String','Kalman Gain',...
        'Position',[400 145 140 26],'Callback',@kgCB);
    ui.btnInnov = uicontrol(ui.fig,'Style','pushbutton','String','Innovation (norm)',...
        'Position',[20 110 170 26],'Callback',@innovCB);

    ui.btnClass = uicontrol(ui.fig,'Style','pushbutton','String','Classification Metrics',...
        'Position',[210 110 170 26],'Callback',@classCB);

    ui.btnMeas = uicontrol(ui.fig,'Style','pushbutton','String','Measured Trajectories',...
        'Position',[400 110 140 26],'Callback',@measCB);

    % כפתור חדש לסטטיסטיקות יירוט
    ui.btnIntercept = uicontrol(ui.fig,'Style','pushbutton','String','Interception Stats',...
        'Position',[20 20 200 26],'Callback',@interceptCB);

    % כפתורי זום לפיצוצים
    ui.zoomNext  = uicontrol(ui.fig,'Style','pushbutton','String','Zoom Next Explosion',...
        'Position',[20 75 200 26],'Callback',@zoomNextCB);
    ui.zoomReset = uicontrol(ui.fig,'Style','pushbutton','String','Reset Zoom',...
        'Position',[230 75 150 26],'Callback',@zoomResetCB);

    ui.zoomIn  = uicontrol(ui.fig,'Style','pushbutton','String','Zoom +',...
        'Position',[400 75 65 26],'Callback',@zoomInCB);
    ui.zoomOut = uicontrol(ui.fig,'Style','pushbutton','String','Zoom -',...
        'Position',[470 75 65 26],'Callback',@zoomOutCB);
    ui.zoomLbl = uicontrol(ui.fig,'Style','text','String','Margin: 100 m',...
        'Position',[20 50 180 18],'HorizontalAlignment','left');

    ui.successText = uicontrol(ui.fig,'Style','text','String','Success: 0% (0/0)',...
        'Position',[210 50 320 18],'HorizontalAlignment','left','FontSize',11,'FontWeight','bold');

    % ---------- Callbacks ----------

    function runSimCB(~,~)
        % קריאת פרמטרים
        num_missiles     = max(0, round(str2double(get(ui.mEdit,'String'))));
        num_interceptors = max(0, round(str2double(get(ui.iEdit,'String'))));

        % רעשים אמת (סטיית תקן -> שונות)
        sigmaQ_true_std = str2double(get(ui.sQtrue,'String'));
        sigmaR_true_std = str2double(get(ui.sRtrue,'String'));

        sigmaQ_true_var = sigmaQ_true_std.^2;
        sigmaR_true_var = sigmaR_true_std.^2;

        % מהירויות ופרמטרים פיזיקליים
        v0            = str2double(get(ui.vMissile,'String'));
        v_interceptor = str2double(get(ui.vInterceptor,'String'));
        m_missile     = str2double(get(ui.mMass,'String'));
        Aref_missile  = str2double(get(ui.Aref,'String'));

        % הפילטר – כמו שקבעת
        sigmaQ_filt_var = sigmaQ_true_var;
        sigmaR_filt_var = sigmaR_true_var.^2;

        if any(isnan([num_missiles num_interceptors ...
                      sigmaQ_true_var sigmaR_true_var ...
                      v0 v_interceptor m_missile Aref_missile])) ...
           || num_missiles==0
            set(ui.successText,'String','Please enter valid numbers.');
            return;
        end
        set(ui.runBtn,'Enable','off'); drawnow;

        % אפס ומרחק זום
        setappdata(ui.fig,'explosions', struct('x',{},'y',{},'step',{},'missile',{},'interceptor',{}));
        setappdata(ui.fig,'explosionIndex', 0);
        setappdata(ui.fig,'zoomMargin', 100);
        set(ui.zoomLbl,'String','Margin: 100 m');

        % פרמטרי סצנה נוספים
        g  = 9.8;
        dt = 0.01;
        explosion_distance = 0.5;

        % אזורים
        openAreas = areas('generateOpenAreas', 3);
        redTargets = areas('generateRedTargets', 3, openAreas);

        % טילים/מיירטים
        missiles = generateMissiles(num_missiles, v0, g, dt, redTargets, openAreas, ...
                                    m_missile, Aref_missile);
        ictrs = interceptors('generateInterceptors', num_interceptors);
        ictrs = interceptors('assignTargetsToInterceptors', ictrs, missiles);

        % EKF (מטריצות המסנן) – עם אותו m,Aref כמו האמת
        [A, B, C, Qf, Rf, P_updateCell, statesCell] = kalmanFilter('initialize', ...
            num_missiles, missiles, sigmaQ_filt_var, sigmaR_filt_var, dt, v0, g, ...
            m_missile, Aref_missile);

        % גרפים
        [missile_plots, kf_plots, ictr_plots, explosion_plots, trail_plots, statusHandle] = ...
            initializePlots(missiles, ictrs, redTargets, openAreas);

        % ריצה – מעבירים גם את Qtrue/Rtrue (ליצירת רעש אמת)
        runSimulation(missiles, ictrs, statesCell, P_updateCell, ...
            A, B, C, Qf, Rf, ...
            diag([sigmaQ_true_var sigmaQ_true_var sigmaQ_true_var sigmaQ_true_var]), ...
            sigmaR_true_var*eye(2), ...
            missile_plots, kf_plots, ictr_plots, ...
            explosion_plots, trail_plots, statusHandle, ...
            v_interceptor, explosion_distance, dt, g, ...
            openAreas, redTargets, ui);

        set(ui.runBtn,'Enable','on');
    end

    % -------- גרפי ניתוח --------

    function rmseCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'sqErrorsX') || isempty(data.sqErrorsX)
            set(ui.successText,'String','Run simulation first.');
            return;
        end

        % בחירת טווח לחישוב RMSE בעזרת listdlg
        options = { ...
            'כל התנועה', ...
            '1000 צעדים אחרונים', ...
            '500 צעדים אחרונים', ...
            '100 צעדים אחרונים'};

        [idx, ok] = listdlg( ...
            'PromptString','בחר טווח לחישוב RMSE:', ...
            'SelectionMode','single', ...
            'ListString',options, ...
            'Name','RMSE Options');

        if ~ok || isempty(idx)
            return; % המשתמש ביטל
        end

        switch idx
            case 1
                mode = 'full';
            case 2
                mode = 'last1000';
            case 3
                mode = 'last500';
            case 4
                mode = 'last100';
            otherwise
                mode = 'full';
        end

        analyzeRMSE(data.sqErrorsX, data.sqErrorsY, mode);
    end

    function covCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'P_history')
            set(ui.successText,'String','Run simulation first.'); return; end
        plotCovarianceOverTime(data.P_history);
    end

    function kgCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'K_history')
            set(ui.successText,'String','Run simulation first.'); return; end
        plotKalmanGainOverTime(data.K_history);
    end

    function innovCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'innovation_history')
            set(ui.successText,'String','Run simulation first.'); return; end
        plotInnovation(data.innovation_history);
    end

    function classCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'classStats')
            set(ui.successText,'String','Run simulation first.');
            return;
        end
        plotClassificationMetrics(data.classStats);
    end

    function measCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'measX') || isempty(data.measX)
            set(ui.successText,'String','Run simulation first.');
            return;
        end
        if ~isfield(data,'missiles')
            set(ui.successText,'String','Missile data not available.');
            return;
        end
        plotMeasurements(data.measX, data.measY, data.missiles);
    end

    function interceptCB(~,~)
        data = getappdata(ui.fig,'simData');
        if isempty(data) || ~isfield(data,'interceptStats')
            set(ui.successText,'String','Run simulation first.');
            return;
        end
        plotInterceptionStats(data.interceptStats);
    end

    % -------- זום --------

    function zoomNextCB(~,~)
        ax = getappdata(ui.fig,'simAxes');
        if isempty(ax) || ~ishandle(ax)
            set(ui.successText,'String','Run simulation first.');
            return;
        end
        ex = getappdata(ui.fig,'explosions');
        if isempty(ex)
            set(ui.successText,'String','No explosions yet.');
            return;
        end
        idx = getappdata(ui.fig,'explosionIndex');
        if isempty(idx) || ~isscalar(idx), idx = 0; end
        idx = idx + 1;
        if idx > numel(ex), idx = 1; end
        setappdata(ui.fig,'explosionIndex', idx);
        e = ex(idx);
        margin = getappdata(ui.fig,'zoomMargin');
        if isempty(margin), margin=100; end
        try
            set(ax,'XLim',[e.x - margin, e.x + margin], ...
                   'YLim',[max(e.y - margin,0), e.y + margin]);
            set(ui.successText,'String',sprintf('Zoomed to explosion %d/%d | Margin: %g m', ...
                idx, numel(ex), margin));
        catch
        end
    end

    function zoomResetCB(~,~)
        ax = getappdata(ui.fig,'simAxes');
        if isempty(ax) || ~ishandle(ax), return; end
        axis(ax,'auto'); grid(ax,'on');
        set(ui.successText,'String','Zoom reset.');
    end

    function zoomInCB(~,~)
        margin = getappdata(ui.fig,'zoomMargin');
        if isempty(margin), margin=100; end
        margin = max(5, margin*0.7);
        setappdata(ui.fig,'zoomMargin',margin);
        set(ui.zoomLbl,'String',sprintf('Margin: %g m', margin));
        applyZoomToCurrent();
    end

    function zoomOutCB(~,~)
        margin = getappdata(ui.fig,'zoomMargin');
        if isempty(margin), margin=100; end
        margin = min(1e5, margin*1.4);
        setappdata(ui.fig,'zoomMargin',margin);
        set(ui.zoomLbl,'String',sprintf('Margin: %g m', margin));
        applyZoomToCurrent();
    end

    function applyZoomToCurrent()
        ax = getappdata(ui.fig,'simAxes');
        ex = getappdata(ui.fig,'explosions');
        idx = getappdata(ui.fig,'explosionIndex');

        if isempty(ax) || ~ishandle(ax) || isempty(ex) || ~isscalar(idx) || idx<1 || idx>numel(ex)
            return;
        end

        e = ex(idx);
        margin = getappdata(ui.fig,'zoomMargin');
        if isempty(margin), margin = 100; end

        try
            set(ax,'XLim',[e.x - margin, e.x + margin], ...
                   'YLim',[max(e.y - margin,0), e.y + margin]);
            set(ui.successText,'String',sprintf( ...
                'Adjusted zoom at explosion %d/%d | Margin: %g m', idx, numel(ex), margin));
        catch
        end
    end

end
