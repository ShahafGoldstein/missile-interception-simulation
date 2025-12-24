function varargout = interceptors(varargin)
% This file contains all functions related to interceptor creation and target assignment.
%
% Usage examples:
%   1) ictrs = interceptors('generateInterceptors', num_interceptors);
%   2) ictrs = interceptors('assignTargetsToInterceptors', ictrs, missiles);
%
% For backward compatibility, you can also call:
%       ictrs = generateInterceptors(num_interceptors);
%       ictrs = assignTargetsToInterceptors(ictrs, missiles);

    methodName = varargin{1};
    switch methodName
        case 'generateInterceptors'
            % interceptors('generateInterceptors', num_interceptors)
            varargout{1} = generateInterceptors_impl(varargin{2});

        case 'assignTargetsToInterceptors'
            % interceptors('assignTargetsToInterceptors', interceptorsStruct, missiles)
            varargout{1} = assignTargetsToInterceptors_impl(varargin{2}, varargin{3});

        otherwise
            error('interceptors.m: Unknown method name "%s".', methodName);
    end
end

% =====================================================================
function interceptorsStruct = generateInterceptors_impl(num_interceptors)
    % Generates initial positions for interceptors on the x-axis (positive side).

    interceptorsStruct = struct('x', {}, 'y', {}, ...
                                'x_hist', {}, 'y_hist', {}, ...
                                'engaged', {}, 'color', {}, ...
                                'target', {}, 'detonated', {});

    for i = 1:num_interceptors
        xInit = 5000 + 5000 * rand;
        yInit = 0;

        interceptorsStruct(i) = struct( ...
            'x',        xInit, ...
            'y',        yInit, ...
            'x_hist',   xInit, ...
            'y_hist',   yInit, ...
            'engaged',  false, ...
            'color',    [], ...
            'target',   -1, ...
            'detonated', false);
    end
end

% =====================================================================
function interceptorsStruct = assignTargetsToInterceptors_impl(interceptorsStruct, missiles)
    % Sort missiles by descending priority (Inf > positive > -Inf)
    [~, sortIdx] = sort([missiles.priority], 'descend');

    num_interceptors = length(interceptorsStruct);
    num_missiles     = length(missiles);

    iMissile = 1;
    for k = 1:num_interceptors

        % דלג על טילים "ירוקים" (priority = -Inf)
        while iMissile <= num_missiles && isinf(missiles(sortIdx(iMissile)).priority) ...
                                      && missiles(sortIdx(iMissile)).priority < 0
            iMissile = iMissile + 1;
        end

        % אם נשאר טיל מאיים (אדום או רגיל) – הקצה אליו מיירט
        if iMissile <= num_missiles
            targ = sortIdx(iMissile);
            interceptorsStruct(k).target = targ;
            interceptorsStruct(k).color  = missiles(targ).color;
            iMissile = iMissile + 1;
        else
            % אין יותר טילים מאיימים – מיירט נשאר בלי יעד
            interceptorsStruct(k).target = -1;
        end
    end
end




% =====================================================================
% === Compatibility Wrappers (optional) ===
% These allow old code that called generateInterceptors(...) or
% assignTargetsToInterceptors(...) directly to keep working.
% They just redirect to the main interceptors() interface.

function ictrs = generateInterceptors(n)
ictrs = interceptors('generateInterceptors', n);
end

function ictrs = assignTargetsToInterceptors(ictrs, missiles)
ictrs = interceptors('assignTargetsToInterceptors', ictrs, missiles);
end
