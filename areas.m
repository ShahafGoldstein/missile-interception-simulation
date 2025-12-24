function varargout = areas(varargin)
% This file contains all functions related to green open areas and red (strategic) target areas.
%
% Usage (examples):
%   openAreas   = areas('generateOpenAreas', nOpenAreas);
%   redTargets  = areas('generateRedTargets', nRedTargets, openAreas);
%   overlap     = areas('checkOverlap', aMin, aMax, bMin, bMax);
%   inArea      = areas('isInOpenArea', xPos, openAreas);
%   inRed       = areas('isInAnyRedTarget', xPos, redTargets);
%   d           = areas('distanceToNearestRedTarget', xPos, redTargets);

    methodName = varargin{1};

    switch methodName
        case 'generateOpenAreas'
            % areas('generateOpenAreas', nOpenAreas)
            varargout{1} = generateOpenAreas(varargin{2});

        case 'generateRedTargets'
            % areas('generateRedTargets', nRedTargets, openAreas)
            varargout{1} = generateRedTargets(varargin{2}, varargin{3});

        case 'checkOverlap'
            % areas('checkOverlap', aMin, aMax, bMin, bMax)
            varargout{1} = checkOverlap(varargin{2}, varargin{3}, varargin{4}, varargin{5});

        case 'isInOpenArea'
            % areas('isInOpenArea', xPos, openAreas)
            varargout{1} = isInOpenArea(varargin{2}, varargin{3});

        case 'isInAnyRedTarget'
            % areas('isInAnyRedTarget', xPos, redTargets)
            varargout{1} = isInAnyRedTarget(varargin{2}, varargin{3});

        case 'distanceToNearestRedTarget'
            % areas('distanceToNearestRedTarget', xPos, redTargets)
            varargout{1} = distanceToNearestRedTarget(varargin{2}, varargin{3});

        otherwise
            error('areas.m: Unknown method name "%s".', methodName);
    end
end

% =====================================================================
function openAreas = generateOpenAreas(nOpenAreas)
    % Generate 'nOpenAreas' intervals, each representing a green open area.
    % Each area is defined by [start_coordinate, end_coordinate] on the x-axis.

    openAreas = zeros(nOpenAreas, 2);
    for i = 1:nOpenAreas
        while true
            area_min  = 10000 * rand;
            area_size = 300 + 700 * rand;  % each area width is between 300-1000 meters
            area_max  = area_min + area_size;

            % Check that the new area does not overlap with existing ones
            if i == 1
                openAreas(i,:) = [area_min, area_max];
                break;
            else
                isGood = true;
                for j = 1:i-1
                    if checkOverlap(area_min, area_max, openAreas(j,1), openAreas(j,2))
                        isGood = false;
                        break;
                    end
                end
                if isGood
                    openAreas(i,:) = [area_min, area_max];
                    break;
                end
            end
        end
    end
end

% =====================================================================
function redTargets = generateRedTargets(nRedTargets, openAreas)
    % Generate 'nRedTargets' intervals, each representing a red (strategic) target area
    % on the x-axis, ensuring no overlap with green open areas or already-defined red targets.

    redTargets = zeros(nRedTargets, 2);
    for i = 1:nRedTargets
        while true
            target_min  = 10000 * rand;
            target_size = 300 + 700 * rand;
            target_max  = target_min + target_size;

            % Check no overlap with green open areas
            overlapGreen = false;
            for og = 1:size(openAreas,1)
                if checkOverlap(target_min, target_max, openAreas(og,1), openAreas(og,2))
                    overlapGreen = true;
                    break;
                end
            end

            % Check no overlap with previously defined red targets
            overlapRed = false;
            for r = 1:i-1
                if checkOverlap(target_min, target_max, redTargets(r,1), redTargets(r,2))
                    overlapRed = true;
                    break;
                end
            end

            if ~overlapGreen && ~overlapRed
                redTargets(i,:) = [target_min, target_max];
                break;
            end
        end
    end
end

% =====================================================================
function isOverlap = checkOverlap(aMin, aMax, bMin, bMax)
    % Returns true if intervals [aMin, aMax] and [bMin, bMax] overlap.
    isOverlap = ~(aMax < bMin || bMax < aMin);
end

% =====================================================================
function inArea = isInOpenArea(final_x, openAreas)
    % Check if final_x is inside any green open area interval
    inArea = false;
    for idx = 1:size(openAreas,1)
        if (final_x >= openAreas(idx,1)) && (final_x <= openAreas(idx,2))
            inArea = true;
            return;
        end
    end
end

% =====================================================================
function inRed = isInAnyRedTarget(final_x, redTargets)
    % Check if final_x is inside any red target interval
    inRed = false;
    for idx = 1:size(redTargets,1)
        if (final_x >= redTargets(idx,1)) && (final_x <= redTargets(idx,2))
            inRed = true;
            return;
        end
    end
end

% =====================================================================
function d = distanceToNearestRedTarget(final_x, redTargets)
    % Compute distance from final_x to the nearest red target interval
    dArr = zeros(size(redTargets,1),1);
    for idx = 1:size(redTargets,1)
        xMin = redTargets(idx,1);
        xMax = redTargets(idx,2);
        if final_x < xMin
            dArr(idx) = xMin - final_x;
        elseif final_x > xMax
            dArr(idx) = final_x - xMax;
        else
            dArr(idx) = 0; % inside the interval
        end
    end
    d = min(dArr);
end
