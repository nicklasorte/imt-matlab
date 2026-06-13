function varargout = imtAasHeatmapStyle(ax, cmap, clim)
%IMTAASHEATMAPSTYLE Standardized IMT-AAS heatmap colormap + color-axis path.
%
%   imtAasHeatmapStyle(AX)
%   imtAasHeatmapStyle(AX, CMAP)
%   imtAasHeatmapStyle(AX, CMAP, CLIM)
%   CMAP = imtAasHeatmapStyle()
%
%   Single shared styling path for every IMT-AAS heatmap (the EIRP CDF-grid
%   plotter, the UE-driven sector EIRP plotter, and the gain-heatmap plotter)
%   so figures rendered for different morphologies are directly comparable.
%   The DEFAULT colormap constant lives here and nowhere else.
%
%   Inputs:
%       AX     target axes handle.
%       CMAP   colormap name (char/string) or N-by-3 RGB matrix. [] or
%              omitted -> the standard default colormap (see below).
%       CLIM   1-by-2 [lo hi] color-axis limits applied to AX so multiple
%              heatmaps share an identical scale. [] or omitted -> leave the
%              color-axis on auto (the historical behavior).
%
%   With no input arguments the function returns the default colormap name so
%   callers can expose it as a Name-Value default without duplicating the
%   constant:
%       cmap = imtAasHeatmapStyle();   % -> 'turbo'
%
%   See also: plotR23AasEirpCdfGrid, plotImtAasSectorEirpGrid,
%             plotR23AasGainHeatmap.

    % The one and only place the standard IMT-AAS colormap is named.
    DEFAULT_COLORMAP = 'turbo';

    if nargin == 0
        varargout{1} = DEFAULT_COLORMAP;
        return;
    end

    if isempty(ax) || ~isscalar(ax) || ~isgraphics(ax, 'axes')
        error('imtAasHeatmapStyle:invalidAxes', ...
            'AX must be a scalar axes handle.');
    end
    if nargin < 2 || isempty(cmap)
        cmap = DEFAULT_COLORMAP;
    end
    if nargin < 3
        clim = [];
    end

    % ---- colormap (always applied) ----------------------------------
    if isstring(cmap) && isscalar(cmap)
        cmap = char(cmap);
    end
    if ~(ischar(cmap) || (isnumeric(cmap) && ismatrix(cmap) && size(cmap, 2) == 3))
        error('imtAasHeatmapStyle:invalidColormap', ...
            'CMAP must be a colormap name or an N-by-3 RGB matrix.');
    end
    colormap(ax, cmap);

    % ---- fixed color-axis (only when requested) ---------------------
    % set(ax, 'CLim', ...) is used (rather than clim/caxis) so the local
    % variable name CLIM never shadows a builtin.
    if ~isempty(clim)
        climVec = double(clim(:).');
        if numel(climVec) ~= 2 || ~all(isfinite(climVec)) || climVec(2) <= climVec(1)
            error('imtAasHeatmapStyle:invalidCLim', ...
                'CLIM must be a finite 1-by-2 [lo hi] vector with hi > lo.');
        end
        set(ax, 'CLim', climVec);
    end
end
