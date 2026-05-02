function out = estimate_aas_mc_memory(numAz, numEl, numBins, countType, opts)
%ESTIMATE_AAS_MC_MEMORY Memory and storage estimates for an AAS MC run.
%
%   OUT = estimate_aas_mc_memory(NUMAZ, NUMEL, NUMBINS)
%   OUT = estimate_aas_mc_memory(NUMAZ, NUMEL, NUMBINS, COUNTTYPE)
%   OUT = estimate_aas_mc_memory(NUMAZ, NUMEL, NUMBINS, COUNTTYPE, OPTS)
%
%   Inputs:
%       numAz     number of azimuth grid points
%       numEl    number of elevation grid points
%       numBins  number of histogram bins
%       countType (default 'uint32') element type used by stats.counts.
%                 Supported: uint8, uint16, uint32, int32, single, uint64,
%                 int64, double.
%       opts     optional struct:
%           .numMc            scalar, used to compute the (avoided) raw
%                             EIRP cube memory estimate.
%           .numPercentileCols default 101 (p000..p100).
%           .verbose          logical, if true prints a human-readable
%                             summary (default false).
%
%   Outputs (all sizes in bytes unless noted):
%       .numAz, .numEl, .numBins, .numCells, .countType
%       .histCountsBytes        bytes for stats.counts
%       .streamingSumsBytes     bytes for sum_lin_mW + min_dBm + max_dBm
%       .perCellExtrasBytes     bytes for derived per-cell maps
%                               (mean_lin_mW + mean_dBm) computed at the
%                               end of the MC loop
%       .totalRunningBytes      total RAM held by the streaming aggregator
%                               during a run
%       .percentileTableBytes   bytes for the in-memory percentile table
%                               (numCells x (2 + numPercentileCols) doubles)
%       .csvBytes               rough estimate of the CSV file size on disk
%       .rawCubeBytesPerDraw    bytes for ONE EIRP slice (Naz x Nel doubles)
%       .rawCubeBytesAtNumMc    bytes for the full Naz x Nel x numMc EIRP
%                               cube (only computed when opts.numMc given);
%                               this is the value users should NOT allocate
%       .rawCubeWarning         logical, true if rawCubeBytesAtNumMc exceeds
%                               .rawCubeWarnThresholdBytes (default 1 GiB)
%       .rawCubeWarnThresholdBytes
%       .warning                short user-facing reminder string
%       .summary                human-readable multiline summary
%
%   Use this BEFORE launching a full-grid run to confirm the histogram and
%   percentile table fit in memory. The function never allocates the
%   structures it sizes - it is a pure arithmetic estimator.

    if nargin < 3
        error('estimate_aas_mc_memory:missingInputs', ...
            'numAz, numEl, numBins are required.');
    end
    if nargin < 4 || isempty(countType)
        countType = 'uint32';
    end
    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'numPercentileCols') || isempty(opts.numPercentileCols)
        opts.numPercentileCols = 101;
    end
    if ~isfield(opts, 'verbose') || isempty(opts.verbose)
        opts.verbose = false;
    end
    if ~isfield(opts, 'rawCubeWarnThresholdBytes') || ...
            isempty(opts.rawCubeWarnThresholdBytes)
        opts.rawCubeWarnThresholdBytes = 1 * 1024^3;   % 1 GiB
    end

    validateScalarPositive(numAz,   'numAz');
    validateScalarPositive(numEl,   'numEl');
    validateScalarPositive(numBins, 'numBins');

    bytesCount = bytesPerElement(countType);
    bytesDouble = 8;

    nCells = double(numAz) * double(numEl);

    out = struct();
    out.numAz     = numAz;
    out.numEl     = numEl;
    out.numBins   = numBins;
    out.numCells  = nCells;
    out.countType = countType;

    % stats.counts is Naz x Nel x Nbin
    out.histCountsBytes = nCells * double(numBins) * bytesCount;

    % streaming sums + min + max are double per cell -> 3 doubles / cell
    out.streamingSumsBytes = nCells * 3 * bytesDouble;

    % After the run mean_lin_mW + mean_dBm are computed -> 2 more doubles
    out.perCellExtrasBytes = nCells * 2 * bytesDouble;

    out.totalRunningBytes = out.histCountsBytes ...
                          + out.streamingSumsBytes ...
                          + out.perCellExtrasBytes;

    % percentile table: rows = numCells, cols = 2 (az,el) + numPercentileCols
    numCols = 2 + opts.numPercentileCols;
    out.percentileTableBytes = nCells * numCols * bytesDouble;

    % CSV size: rough estimate, ~12 chars per numeric field + comma/newline
    bytesPerField = 12;
    out.csvBytes = nCells * numCols * bytesPerField;

    % Raw cube (the thing we *avoid* by streaming)
    out.rawCubeBytesPerDraw = nCells * bytesDouble;
    out.rawCubeWarnThresholdBytes = opts.rawCubeWarnThresholdBytes;
    if isfield(opts, 'numMc') && ~isempty(opts.numMc) && opts.numMc > 0
        out.rawCubeBytesAtNumMc = out.rawCubeBytesPerDraw * double(opts.numMc);
        out.rawCubeWarning = ...
            out.rawCubeBytesAtNumMc > opts.rawCubeWarnThresholdBytes;
    else
        out.rawCubeBytesAtNumMc = NaN;
        % With unknown numMc we still warn whenever a single EIRP cube
        % over the default 65,341-cell grid would already be > 0.5 GiB.
        out.rawCubeWarning = ...
            out.rawCubeBytesPerDraw > 0.5 * opts.rawCubeWarnThresholdBytes;
    end

    out.warning = ...
        'Do not store raw eirpCube for large runs - use the streaming histogram.';

    out.summary = buildSummary(out);

    if opts.verbose
        fprintf('%s\n', out.summary);
    end
end

% ------------------------------------------------------------------------
function n = bytesPerElement(typeName)
    switch lower(typeName)
        case 'logical', n = 1;
        case 'uint8',   n = 1;
        case 'int8',    n = 1;
        case 'uint16',  n = 2;
        case 'int16',   n = 2;
        case 'uint32',  n = 4;
        case 'int32',   n = 4;
        case 'single',  n = 4;
        case 'uint64',  n = 8;
        case 'int64',   n = 8;
        case 'double',  n = 8;
        otherwise
            error('estimate_aas_mc_memory:badCountType', ...
                'Unknown countType "%s".', typeName);
    end
end

% ------------------------------------------------------------------------
function validateScalarPositive(v, name)
    if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
        error('estimate_aas_mc_memory:badInput', ...
            '%s must be a positive finite scalar.', name);
    end
end

% ------------------------------------------------------------------------
function s = buildSummary(out)
    lines = {};
    lines{end+1} = sprintf( ...
        'AAS MC memory estimate: %d az x %d el x %d bins (countType=%s)', ...
        out.numAz, out.numEl, out.numBins, out.countType);
    lines{end+1} = sprintf('  num az/el cells          : %d', out.numCells);
    lines{end+1} = sprintf('  histogram counts         : %s', humanBytes(out.histCountsBytes));
    lines{end+1} = sprintf('  streaming sums/min/max   : %s', humanBytes(out.streamingSumsBytes));
    lines{end+1} = sprintf('  per-cell mean maps       : %s', humanBytes(out.perCellExtrasBytes));
    lines{end+1} = sprintf('  total running RAM        : %s', humanBytes(out.totalRunningBytes));
    lines{end+1} = sprintf('  percentile table (RAM)   : %s', humanBytes(out.percentileTableBytes));
    lines{end+1} = sprintf('  percentile CSV on disk   : %s', humanBytes(out.csvBytes));
    lines{end+1} = sprintf('  raw cube per draw        : %s', humanBytes(out.rawCubeBytesPerDraw));
    if ~isnan(out.rawCubeBytesAtNumMc)
        lines{end+1} = sprintf('  raw cube full numMc      : %s (AVOID)', ...
            humanBytes(out.rawCubeBytesAtNumMc));
    end
    if out.rawCubeWarning
        lines{end+1} = sprintf( ...
            '  WARNING: %s', out.warning);
    end
    s = strjoin(lines, sprintf('\n'));
end

% ------------------------------------------------------------------------
function s = humanBytes(b)
    units = {'B', 'KiB', 'MiB', 'GiB', 'TiB'};
    i = 1;
    v = double(b);
    while v >= 1024 && i < numel(units)
        v = v / 1024;
        i = i + 1;
    end
    if i == 1
        s = sprintf('%d %s', round(v), units{i});
    else
        s = sprintf('%.2f %s', v, units{i});
    end
end
