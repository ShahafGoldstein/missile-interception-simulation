function missiles = generateMissiles(num_missiles, v0, g, dt, redTargets, openAreas, m, Aref)
% Ballistic missiles with drag + process noise in acceleration ("noisy truth" only).
% המסלול האמיתי היחיד שיש הוא מסלול עם רעש תהליך (אין יותר מסלול נומינלי חלק).
%
% m    – מסה [kg] (מה-GUI)
% Aref – שטח חתך [m^2] (מה-GUI)

    missileColors = lines(num_missiles);

    % ---- Physical parameters (consistent with EKF) ----
    % m ו-Aref באים מבחוץ
    Cd   = 0.5;     % -
    rho0 = 1.225;   % kg/m^3 at sea level
    H    = 8500;    % m
    beta_scale = 0.3;   % optional scale for drag

    % ---- Process noise for "true" trajectory (acceleration noise) ----
    sigma_ax = 5;   % [m/s^2]
    sigma_ay = 5;   % [m/s^2]

    missiles = struct('x_start', {}, 'theta', {}, 't_total', {}, ...
                      't', {}, 'x_real', {}, 'y_real', {}, ...
                      'x_real_noisy', {}, 'y_real_noisy', {}, ...
                      'x_meas', {}, 'y_meas', {}, ...
                      'exploded', {}, 'priority', {}, ...
                      'color', {});

    for i = 1:num_missiles
        % --- Launch angle ---
        theta_min = 15; theta_max = 45;
        theta_deg = theta_min + (theta_max - theta_min)*rand;
        theta_deg = max(theta_min, min(theta_max, theta_deg));
        theta_rad = deg2rad(theta_deg);

        % starting x
        x_start = -5000 + 5000*rand;

        % Initial state
        vx0 = v0 * cos(theta_rad);
        vy0 = v0 * sin(theta_rad);
        x0  = x_start;
        y0  = 0;

        % --- Time integration (explicit Euler) for noisy trajectory only ---
        maxSteps = 200000;

        x_noi = x0;
        y_noi = y0;
        vx_noi = vx0;
        vy_noi = vy0;

        x_traj_noi = zeros(1, 1000);
        y_traj_noi = zeros(1, 1000);
        t_vec      = zeros(1, 1000);

        n = 1;
        x_traj_noi(n) = x_noi;
        y_traj_noi(n) = y_noi;
        t_vec(n)      = 0;

        for step = 1:maxSteps
            % גובה נוכחי
            rho_h_noi  = rho0 * exp(-max(y_noi,0)/H);
            beta_h_noi = 0.5 * rho_h_noi * Cd * Aref / m * beta_scale;

            v_noi  = sqrt(vx_noi^2 + vy_noi^2) + eps;
            ax_noi = -beta_h_noi * v_noi * vx_noi + sigma_ax * randn;
            ay_noi = -g           - beta_h_noi * v_noi * vy_noi + sigma_ay * randn;

            % אינטגרציה קדימה
            x_noi = x_noi + vx_noi * dt;
            y_noi = y_noi + vy_noi * dt;
            if y_noi < 0
                y_noi = 0;
            end
            vx_noi = vx_noi + ax_noi * dt;
            vy_noi = vy_noi + ay_noi * dt;

            % שמירה
            n = n + 1;
            if n > numel(x_traj_noi)
                grow = max(1000, floor(0.2 * n));
                x_traj_noi = [x_traj_noi, zeros(1,grow)];
                y_traj_noi = [y_traj_noi, zeros(1,grow)];
                t_vec      = [t_vec,      zeros(1,grow)];
            end
            x_traj_noi(n) = x_noi;
            y_traj_noi(n) = y_noi;
            t_vec(n)      = (n-1) * dt;

            if y_noi <= 0 && n > 5
                break;
            end
        end

        x_traj_noi = x_traj_noi(1:n);
        y_traj_noi = y_traj_noi(1:n);
        t_vec      = t_vec(1:n);

        t_total = t_vec(end);
        final_x = x_traj_noi(end);

        % Priority logic לפי נקודת הנפילה של המסלול עם הרעש
        if areas('isInAnyRedTarget', final_x, redTargets)
            priority = Inf;
        elseif areas('isInOpenArea', final_x, openAreas)
            priority = -Inf;
        else
            distToNearest = areas('distanceToNearestRedTarget', final_x, redTargets);
            if distToNearest == 0
                priority = Inf;
            else
                priority = 1/distToNearest;
            end
        end

        missiles(i) = struct( ...
            'x_start',       x_start, ...
            'theta',         theta_deg, ...
            't_total',       t_total, ...
            't',             t_vec, ...
            'x_real',        x_traj_noi, ...
            'y_real',        y_traj_noi, ...
            'x_real_noisy',  x_traj_noi, ...
            'y_real_noisy',  y_traj_noi, ...
            'x_meas',        zeros(size(x_traj_noi)), ...
            'y_meas',        zeros(size(y_traj_noi)), ...
            'exploded',      false, ...
            'priority',      priority, ...
            'color',         missileColors(i,:) ...
        );
    end
end
