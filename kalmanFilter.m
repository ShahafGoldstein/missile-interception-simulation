function varargout = kalmanFilter(varargin)
% kalmanFilter.m — EKF לתנועה בליסטית עם גרר תלוי-גובה β(h)
% שימוש:
%   [A,B,C,Qf,Rf,P_cell,states_cell] = kalmanFilter('initialize', ...
%       num_missiles, missiles, sigmaQ_filt_var, sigmaR_filt_var, dt, v0, g, m, Aref);
%
%   [x_up,P_up,K,zX,zY,innovation]   = kalmanFilter('update', ...
%       x_cur, P_cur, A_params, B, C, Qf, Rf, Qtrue, Rtrue, g, x_true, y_true);

methodName = varargin{1};
switch methodName
    case 'initialize'
        %  num_missiles, missiles, sigmaQ_filt_var, sigmaR_filt_var, dt, v0, g, m, Aref
        varargout = cell(1,7);
        [varargout{1}, varargout{2}, varargout{3}, ...
         varargout{4}, varargout{5}, varargout{6}, varargout{7}] = ...
            kalmanInitialize(varargin{2}, varargin{3}, varargin{4}, ...
                             varargin{5}, varargin{6}, varargin{7}, varargin{8}, ...
                             varargin{9}, varargin{10});

    case 'update'
        varargout = cell(1,6);
        [varargout{1}, varargout{2}, varargout{3}, ...
         varargout{4}, varargout{5}, varargout{6}] = ...
            kalmanUpdate(varargin{2}, varargin{3}, varargin{4}, varargin{5}, varargin{6}, ...
                         varargin{7}, varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13});

    otherwise
        error('kalmanFilter: Unknown method name "%s".', methodName);
end
end

% -------------------------------------------------------------------------
function [A_params, B, C, Qf, Rf, P_cell, states_cell] = kalmanInitialize( ...
    num_missiles, missiles, sigmaQ_filt_var, sigmaR_filt_var, dt, v0, g, ...
    m_in, Aref_in)
% הערה: sigmaQ_filt_var, sigmaR_filt_var הן VARIANCE (לא סטיית תקן).
% כאן מוסיפים אתחול "חכם" לכל טיל לפי המסלול האמיתי שלו.

% --- פיזיקה (תואם generateMissiles) ---
m    = m_in;
Cd   = 0.5;
Aref = Aref_in;
rho0 = 1.225;
H    = 8500;
beta_scale = 0.3;

A_params = struct('dt', dt, 'm', m, 'Cd', Cd, 'Aref', Aref, ...
                  'rho0', rho0, 'H', H, 'beta_scale', beta_scale);

% מודל מדידה: מודדים X,Y
C = [1 0 0 0;
     0 1 0 0];

% מטריצת קלט לדינמיקה ידועה u=[ax; ay] (כבידה)
B = [0 0;
     0 0;
     dt 0;
     0 dt];

% Qf לא איזוטרופית – חופש גדול יותר למהירויות
qVelScale = 4;
q_pos = 0.1 * (sigmaQ_filt_var);
q_vel = qVelScale * (sigmaQ_filt_var);
Qf = diag([q_pos, q_pos, q_vel, q_vel]);

% Rf איזוטרופית
Rf = sigmaR_filt_var * eye(2);

% --- אתחול מצב/קובאריאנס לכל טיל בנפרד (אתחול חכם) ---
P_cell      = cell(1, num_missiles);
states_cell = cell(1, num_missiles);

for i = 1:num_missiles
    x_traj = missiles(i).x_real;
    y_traj = missiles(i).y_real;

    x0 = x_traj(1);
    y0 = y_traj(1);

    if numel(x_traj) >= 2
        vx0 = (x_traj(2) - x_traj(1)) / dt;
        vy0 = (y_traj(2) - y_traj(1)) / dt;
    else
        theta_rad = deg2rad(missiles(i).theta);
        vx0 = v0 * cos(theta_rad);
        vy0 = v0 * sin(theta_rad);
    end

    states_cell{i} = [x0; y0; vx0; vy0];

    P_pos = 1e2;   % ~1e^3m std
    P_vel = 1e2;   % ~1e^3 m/s std
    P_init = diag([P_pos, P_pos, P_vel, P_vel]);

    P_cell{i} = P_init;
end

end

% -------------------------------------------------------------------------
function [x_update, P_update_new, K, zX, zY, innovation] = kalmanUpdate( ...
    x_current, P_current, A_params, B, C, Qf, Rf, Qtrue, Rtrue, g, x_true, y_true)
% Qtrue/Rtrue משמשים להזרקת רעש "אמיתי". Qf/Rf – בקובאריאנס המסנן.

% פרמטרים
req = {'dt','m','Cd','Aref','rho0','H','beta_scale'};
for rr = 1:numel(req)
    assert(isfield(A_params,req{rr}), 'A_params missing %s', req{rr});
end
dt = A_params.dt;
m  = A_params.m;
Cd = A_params.Cd;
Aref = A_params.Aref;
rho0 = A_params.rho0;
H    = A_params.H;
beta_scale = A_params.beta_scale;

% --- Predict (לא לינארי) ---
x  = x_current;
vx = x(3);
vy = x(4);
y  = max(x(2),0);

rho_h  = rho0 * exp(-y / H);
beta_h = 0.5 * rho_h * Cd * Aref / m * beta_scale;

v       = sqrt(vx^2 + vy^2) + eps;
ax_drag = -beta_h * v * vx;
ay_drag = -beta_h * v * vy;
f       = [vx; vy; ax_drag; ay_drag];

% רעש מדידה אמיתי בלבד (לייצר Z)
if exist('mvnrnd','file')
    v_true = mvnrnd(zeros(2,1), Rtrue)';     
else
    v_true = chol(Rtrue,'lower') * randn(2,1);
end
w_true = zeros(4,1);  %#ok<NASGU>

u      = [0; -g];
x_pred = x + dt*f + B*u;   % בלי רעש אמת (המסנן לא יודע על w_true)

% Jacobian
s = v;
dbeta_dy = -(beta_h/H);

d_ax_d_vx = -beta_h * ((2*vx^2 + vy^2) / s);
d_ax_d_vy = -beta_h * ((vx*vy) / s);
d_ay_d_vx = -beta_h * ((vx*vy) / s);
d_ay_d_vy = -beta_h * ((vx^2 + 2*vy^2) / s);

d_ax_d_y  = +(beta_h/H) * v * vx;
d_ay_d_y  = +(beta_h/H) * v * vy; %#ok<NASGU> % (dbeta_dy כבר הובלע כאן)

J = [0 0 1 0;
     0 0 0 1;
     0 d_ax_d_y d_ax_d_vx d_ax_d_vy;
     0 d_ay_d_y d_ay_d_vx d_ay_d_vy];

Fd     = eye(4) + dt*J;
P_pred = Fd * P_current * Fd' + Qf;   % קובאריאנס עם Qf (של המסנן)

% מדידה אמיתית
Z  = [x_true; y_true] + v_true; 
zX = Z(1); 
zY = Z(2);
if any(isnan(Z))
    x_update     = x_pred;
    P_update_new = P_pred;
    K            = [];
    innovation   = [];
    return;
end

% Update עם Rf (של המסנן)
S = C*P_pred*C' + Rf;
K = P_pred*C'/S;
innovation = Z - C*x_pred;

x_update     = x_pred + K*innovation;
P_update_new = (eye(4)-K*C)*P_pred;
end
