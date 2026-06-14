function cmp = comparePercentileMaps(a, b, varargin)
%COMPAREPERCENTILEMAPS Diff two percentile-map cubes (e.g. CTIA 1x6 vs ITU 1x3).
%
%   CMP = comparePercentileMaps(A, B)
%   CMP = comparePercentileMaps(A, B, 'Name', Value, ...)
%
%   Computes a signed, per-(az, el, percentile) difference cube between two
%   percentile maps and reports per-percentile metrics plus a
%   worst-case-per-direction envelope. This is the linchpin for the
%   1x3-vs-1x6 GAIN heatmap comparison and the "run both, take the
%   worst-case zone per direction" request.
%
%   A and B may EACH be either:
%       - a pmaps struct (as returned by eirp_percentile_maps): has fields
%         .values (Naz x Nel x P), .azGrid (1 x Naz), .elGrid (1 x Nel),
%         .percentiles (1 x P), and optionally .binEdges / .units; OR
%       - a full runner output struct from runR23AasEirpCdfGrid, in which
%         case the cube is selected per the 'Field' option below.
%
%   Inputs:
%       A, B    pmaps struct or runR23AasEirpCdfGrid output struct.
%
%   Name-value options:
%       'Field'       'gain' (default) -> out.gainPercentileMaps [dBi],
%                     'eirp'           -> out.percentileMaps [dBm],
%                     'activity'       -> out.activityWeightedPercentileMaps.
%                     Ignored when A/B are already pmaps structs.
%       'ThresholdDb' default 3. Cells with |delta| > ThresholdDb count as
%                     exceedances.
%       'LabelA'      default 'A'.  'LabelB' default 'B'.
%       'Print'       default true. Print the per-percentile table + summary
%                     (mirrors compareR23ScenarioMetadata's 'Print').
%       'GridTolDeg'  default 1e-6. Tolerance for grid-equality checks.
%
%   Sign convention:
%       delta = A.values - B.values, units dB (a dBm or dBi difference is a
%       dB difference). POSITIVE delta = A exceeds B. For the headline use
%       case set 'LabelA','CTIA 1x6' and 'LabelB','ITU 1x3' so that a
%       positive delta means the CTIA 1x6 map is higher than the ITU 1x3 map.
%
%   NaN handling:
%       Clamped / undefined directions may be NaN. Every reduction omits
%       NaNs (never errors on them) and the NaN count is reported. A whole
%       percentile slice that is all-NaN yields NaN metrics for that slice
%       (not an error).
%
%   Outputs:
%       CMP struct with fields:
%         .delta         Naz x Nel x P signed delta cube (A - B), dB
%         .azGrid        1 x Naz   (mirrored)
%         .elGrid        1 x Nel   (mirrored)
%         .percentiles   1 x P     (mirrored)
%         .units         'dB'
%         .perPercentile struct of 1 x P arrays (each reduced over az, el):
%                          percentiles, maxAbs, rms, p95Abs, meanBias,
%                          std, nExceed, nNaN
%         .worstCase     struct of Naz x Nel maps (reduced over p):
%                          maxAbsDelta    = max over p of |delta|
%                          signedAtMaxAbs = signed delta at the p that
%                                           maximizes |delta| (sign preserved)
%                          azGrid, elGrid
%         .summary       struct: overallMaxAbs, overallRms, overallMeanBias,
%                          thresholdDb, totalExceed, totalNaN, worstCell
%                          (az/el/percentile indices + values + signed value
%                          of the global max-|delta|)
%         .labelA, .labelB
%         .meta          struct: fieldUsed
%                          ('gainPercentileMaps'/'percentileMaps'/
%                           'activityWeightedPercentileMaps' or 'pmaps'),
%                          Naz, Nel, P
%
%   Notes:
%       - Base MATLAB only. The 95th percentile of |delta| is computed with
%         a sort-based method (no prctile / quantile / Statistics Toolbox).
%       - Conformability: numel(azGrid), numel(elGrid), numel(percentiles)
%         and the value shapes must match within 'GridTolDeg'; otherwise
%         errors with identifier comparePercentileMaps:gridMismatch naming
%         the axis that differs.
%       - Pure compute: no plotting, no RNG, no file I/O.
%
%   Example:
%       outCtia = runR23AasEirpCdfGrid(...);   % 1x6 panel layout
%       outItu  = runR23AasEirpCdfGrid(...);   % 1x3 panel layout
%       cmp = comparePercentileMaps(outCtia, outItu, ...
%                 'Field', 'gain', 'LabelA', 'CTIA 1x6', 'LabelB', 'ITU 1x3');
%
%   See also: eirp_percentile_maps, runR23AasEirpCdfGrid,
%             compareR23ScenarioMetadata, plotComparePercentileMaps.

    % ---- option defaults / parsing (mirrors compareR23ScenarioMetadata) --
    fieldOpt    = 'gain';
    thresholdDb = 3;
    labelA      = 'A';
    labelB      = 'B';
    doPrint     = true;
    gridTolDeg  = 1e-6;

    if ~isempty(varargin)
        if mod(numel(varargin), 2) ~= 0
            error('comparePercentileMaps:badArgs', ...
                'Optional arguments must be Name, Value pairs.');
        end
        for k = 1:2:numel(varargin)
            name = varargin{k};
            if isstring(name) && isscalar(name); name = char(name); end
            value = varargin{k+1};
            switch lower(name)
                case 'field'
                    if isstring(value) && isscalar(value); value = char(value); end
                    fieldOpt = lower(value);
                case 'thresholddb'
                    validateattributes(value, {'numeric'}, ...
                        {'scalar', 'real', 'nonnegative', 'finite'}, ...
                        mfilename, 'ThresholdDb');
                    thresholdDb = double(value);
                case 'labela'
                    labelA = char(value);
                case 'labelb'
                    labelB = char(value);
                case 'print'
                    doPrint = logical(value);
                case 'gridtoldeg'
                    validateattributes(value, {'numeric'}, ...
                        {'scalar', 'real', 'nonnegative', 'finite'}, ...
                        mfilename, 'GridTolDeg');
                    gridTolDeg = double(value);
                otherwise
                    error('comparePercentileMaps:badArgs', ...
                        'Unknown option "%s".', name);
            end
        end
    end

    if ~ismember(fieldOpt, {'gain', 'eirp', 'activity'})
        error('comparePercentileMaps:badArgs', ...
            'Field must be ''gain'', ''eirp'', or ''activity''.');
    end

    % ---- resolve each input to a pmaps struct --------------------------
    [pmA, fieldUsed] = resolvePmaps(a, fieldOpt, 'A');
    [pmB, ~]         = resolvePmaps(b, fieldOpt, 'B');

    % ---- conformability checks -----------------------------------------
    checkAxis('azGrid',      pmA.azGrid,      pmB.azGrid,      gridTolDeg);
    checkAxis('elGrid',      pmA.elGrid,      pmB.elGrid,      gridTolDeg);
    checkAxis('percentiles', pmA.percentiles, pmB.percentiles, gridTolDeg);

    if ~isequal(size(pmA.values), size(pmB.values))
        error('comparePercentileMaps:gridMismatch', ...
            ['values shape differs: A is [%s], B is [%s].'], ...
            sizeStr(pmA.values), sizeStr(pmB.values));
    end

    valA = double(pmA.values);
    valB = double(pmB.values);
    if isempty(valA)
        error('comparePercentileMaps:gridMismatch', ...
            'values are empty; nothing to compare (was the field computed?).');
    end

    [Naz, Nel, P] = size3(valA);

    % ---- signed delta cube (A - B) -------------------------------------
    delta = valA - valB;

    % ---- per-percentile metrics (reduced over az, el) ------------------
    percentiles = pmA.percentiles(:).';
    maxAbs   = nan(1, P);
    rmsv     = nan(1, P);
    p95Abs   = nan(1, P);
    meanBias = nan(1, P);
    stdv     = nan(1, P);
    nExceed  = zeros(1, P);
    nNaN     = zeros(1, P);

    for j = 1:P
        d  = delta(:, :, j);
        d  = d(:);
        nanMask = isnan(d);
        nNaN(j) = sum(nanMask);
        dv = d(~nanMask);
        if isempty(dv)
            continue;   % leave metrics as NaN / nExceed as 0
        end
        ad          = abs(dv);
        maxAbs(j)   = max(ad);
        rmsv(j)     = sqrt(mean(dv .^ 2));
        p95Abs(j)   = sortedPercentile(ad, 95);
        meanBias(j) = mean(dv);
        stdv(j)     = std(dv);          % base MATLAB std, default normalization
        nExceed(j)  = sum(ad > thresholdDb);
    end

    perPercentile = struct( ...
        'percentiles', percentiles, ...
        'maxAbs',      maxAbs, ...
        'rms',         rmsv, ...
        'p95Abs',      p95Abs, ...
        'meanBias',    meanBias, ...
        'std',         stdv, ...
        'nExceed',     nExceed, ...
        'nNaN',        nNaN);

    % ---- worst-case-per-direction (reduced over p) ---------------------
    absCube       = abs(delta);
    allNanDir     = all(isnan(absCube), 3);            % Naz x Nel
    maxAbsDelta   = max(absCube, [], 3, 'omitnan');    % Naz x Nel (NaN if all-NaN)

    % argmax over p with NaN treated as -Inf, then gather the signed value.
    tmp           = absCube;
    tmp(isnan(tmp)) = -Inf;
    [~, ipMax]    = max(tmp, [], 3);                   % Naz x Nel
    [II, JJ]      = ndgrid(1:Naz, 1:Nel);
    linIdx        = sub2ind([Naz, Nel, P], II, JJ, ipMax);
    signedAtMaxAbs = delta(linIdx);
    signedAtMaxAbs(allNanDir) = NaN;
    maxAbsDelta(allNanDir)    = NaN;

    worstCase = struct( ...
        'maxAbsDelta',    maxAbsDelta, ...
        'signedAtMaxAbs', signedAtMaxAbs, ...
        'azGrid',         pmA.azGrid(:).', ...
        'elGrid',         pmA.elGrid(:).');

    % ---- summary (reduced over everything) -----------------------------
    dall    = delta(:);
    nanAll  = isnan(dall);
    dvAll   = dall(~nanAll);
    totalNaN = sum(nanAll);
    if isempty(dvAll)
        overallMaxAbs   = NaN;
        overallRms      = NaN;
        overallMeanBias = NaN;
        totalExceed     = 0;
        worstCell = struct('azIndex', NaN, 'elIndex', NaN, ...
            'percentileIndex', NaN, 'az', NaN, 'el', NaN, ...
            'percentile', NaN, 'value', NaN, 'absValue', NaN);
    else
        adAll           = abs(dvAll);
        overallMaxAbs   = max(adAll);
        overallRms      = sqrt(mean(dvAll .^ 2));
        overallMeanBias = mean(dvAll);
        totalExceed     = sum(adAll > thresholdDb);

        tmpAll          = absCube;
        tmpAll(isnan(tmpAll)) = -Inf;
        [~, gIdx]       = max(tmpAll(:));
        [ia, ie, ip]    = ind2sub([Naz, Nel, P], gIdx);
        worstCell = struct( ...
            'azIndex',         ia, ...
            'elIndex',         ie, ...
            'percentileIndex', ip, ...
            'az',              pmA.azGrid(ia), ...
            'el',              pmA.elGrid(ie), ...
            'percentile',      percentiles(ip), ...
            'value',           delta(ia, ie, ip), ...
            'absValue',        abs(delta(ia, ie, ip)));
    end

    summary = struct( ...
        'overallMaxAbs',   overallMaxAbs, ...
        'overallRms',      overallRms, ...
        'overallMeanBias', overallMeanBias, ...
        'thresholdDb',     thresholdDb, ...
        'totalExceed',     totalExceed, ...
        'totalNaN',        totalNaN, ...
        'worstCell',       worstCell);

    % ---- assemble output ------------------------------------------------
    cmp = struct();
    cmp.delta         = delta;
    cmp.azGrid        = pmA.azGrid(:).';
    cmp.elGrid        = pmA.elGrid(:).';
    cmp.percentiles   = percentiles;
    cmp.units         = 'dB';
    cmp.perPercentile = perPercentile;
    cmp.worstCase     = worstCase;
    cmp.summary       = summary;
    cmp.labelA        = labelA;
    cmp.labelB        = labelB;
    cmp.meta          = struct('fieldUsed', fieldUsed, ...
        'Naz', Naz, 'Nel', Nel, 'P', P);

    if doPrint
        printComparison(cmp);
    end
end

% =====================================================================

function [pm, fieldUsed] = resolvePmaps(x, fieldOpt, label)
%RESOLVEPMAPS Return a pmaps struct from a pmaps struct or runner output.
    if ~isstruct(x) || ~isscalar(x)
        error('comparePercentileMaps:badInput', ...
            'Input %s must be a scalar struct.', label);
    end

    if isPmaps(x)
        pm = x;
        fieldUsed = 'pmaps';
        validatePmaps(pm, label);
        return;
    end

    switch fieldOpt
        case 'gain'
            fieldUsed = 'gainPercentileMaps';
        case 'eirp'
            fieldUsed = 'percentileMaps';
        case 'activity'
            fieldUsed = 'activityWeightedPercentileMaps';
        otherwise
            error('comparePercentileMaps:badArgs', ...
                'Unknown Field "%s".', fieldOpt);
    end

    if ~isfield(x, fieldUsed) || isempty(x.(fieldUsed))
        error('comparePercentileMaps:missingField', ...
            ['Input %s has no usable "%s" field for Field=''%s''. ', ...
             'Provide a pmaps struct or a runner output that contains it.'], ...
            label, fieldUsed, fieldOpt);
    end

    pm = x.(fieldUsed);
    if ~isPmaps(pm)
        error('comparePercentileMaps:badInput', ...
            'Input %s field "%s" is not a valid pmaps struct.', ...
            label, fieldUsed);
    end
    validatePmaps(pm, label);
end

function tf = isPmaps(s)
%ISPMAPS True for a struct that looks like an eirp_percentile_maps result.
    tf = isstruct(s) && isscalar(s) && ...
         isfield(s, 'values') && isfield(s, 'azGrid') && ...
         isfield(s, 'elGrid') && isfield(s, 'percentiles');
end

function validatePmaps(pm, label)
%VALIDATEPMAPS validateattributes on the pmaps fields used downstream.
    validateattributes(pm.values, {'numeric'}, {'real'}, ...
        mfilename, sprintf('%s.values', label));
    validateattributes(pm.azGrid, {'numeric'}, {'vector', 'real'}, ...
        mfilename, sprintf('%s.azGrid', label));
    validateattributes(pm.elGrid, {'numeric'}, {'vector', 'real'}, ...
        mfilename, sprintf('%s.elGrid', label));
    validateattributes(pm.percentiles, {'numeric'}, {'vector', 'real'}, ...
        mfilename, sprintf('%s.percentiles', label));

    [Naz, Nel, P] = size3(pm.values);
    if ~isempty(pm.values)
        if numel(pm.azGrid) ~= Naz
            error('comparePercentileMaps:gridMismatch', ...
                '%s.azGrid length (%d) does not match values dim 1 (%d).', ...
                label, numel(pm.azGrid), Naz);
        end
        if numel(pm.elGrid) ~= Nel
            error('comparePercentileMaps:gridMismatch', ...
                '%s.elGrid length (%d) does not match values dim 2 (%d).', ...
                label, numel(pm.elGrid), Nel);
        end
        if numel(pm.percentiles) ~= P
            error('comparePercentileMaps:gridMismatch', ...
                '%s.percentiles length (%d) does not match values dim 3 (%d).', ...
                label, numel(pm.percentiles), P);
        end
    end
end

function checkAxis(name, va, vb, tol)
%CHECKAXIS Require equal length and within-tolerance values for one axis.
    if numel(va) ~= numel(vb)
        error('comparePercentileMaps:gridMismatch', ...
            '%s length differs: A has %d, B has %d.', ...
            name, numel(va), numel(vb));
    end
    if ~isempty(va)
        d = max(abs(double(va(:)) - double(vb(:))));
        if d > tol
            error('comparePercentileMaps:gridMismatch', ...
                '%s values differ by up to %.6g (> tol %.6g).', ...
                name, d, tol);
        end
    end
end

function v = sortedPercentile(x, p)
%SORTEDPERCENTILE Sort-based percentile (no prctile / Statistics Toolbox).
%   Matches MATLAB prctile's default algorithm: sorted samples sit at
%   percentile positions 100*((1:n)-0.5)/n, with linear interpolation in
%   between and endpoint clamping outside. X must already be NaN-free.
    x = sort(x(:));
    n = numel(x);
    if n == 0
        v = NaN;
        return;
    end
    if n == 1
        v = x(1);
        return;
    end
    pos = 100 * ((1:n) - 0.5) / n;
    if p <= pos(1)
        v = x(1);
    elseif p >= pos(end)
        v = x(end);
    else
        v = interp1(pos, x, p);
    end
end

function [Naz, Nel, P] = size3(A)
%SIZE3 Size of A padded to three dimensions.
    sz = size(A);
    if numel(sz) < 3
        sz(end+1:3) = 1;
    end
    Naz = sz(1); Nel = sz(2); P = sz(3);
end

function s = sizeStr(A)
    s = strtrim(sprintf('%d ', size(A)));
end

function printComparison(cmp)
%PRINTCOMPARISON Per-percentile table + summary (mirrors the diff helper).
    fprintf('---------- comparePercentileMaps ----------\n');
    fprintf('  A: %s\n', cmp.labelA);
    fprintf('  B: %s\n', cmp.labelB);
    fprintf('  field: %s   grid: %d az x %d el x %d pct   units: %s\n', ...
        cmp.meta.fieldUsed, cmp.meta.Naz, cmp.meta.Nel, cmp.meta.P, cmp.units);
    fprintf('  delta = A - B (positive => A higher)\n');
    fprintf('-------------------------------------------\n');
    fprintf('  %6s  %8s  %8s  %8s  %9s  %8s  %7s  %6s\n', ...
        'pct', 'maxAbs', 'rms', 'p95Abs', 'meanBias', 'std', 'nExc', 'nNaN');
    pp = cmp.perPercentile;
    for j = 1:numel(pp.percentiles)
        fprintf('  %6.4g  %8.3f  %8.3f  %8.3f  %9.3f  %8.3f  %7d  %6d\n', ...
            pp.percentiles(j), pp.maxAbs(j), pp.rms(j), pp.p95Abs(j), ...
            pp.meanBias(j), pp.std(j), pp.nExceed(j), pp.nNaN(j));
    end
    fprintf('-------------------------------------------\n');
    s = cmp.summary;
    fprintf('  overall maxAbs   : %.3f dB\n', s.overallMaxAbs);
    fprintf('  overall rms      : %.3f dB\n', s.overallRms);
    fprintf('  overall meanBias : %.3f dB\n', s.overallMeanBias);
    fprintf('  exceed > %.3g dB  : %d cell(s)\n', s.thresholdDb, s.totalExceed);
    fprintf('  NaN cells        : %d\n', s.totalNaN);
    if ~isnan(s.worstCell.value)
        fprintf(['  worst cell       : az=%.4g el=%.4g pct=%.4g  ' ...
                 'delta=%+.3f dB\n'], ...
            s.worstCell.az, s.worstCell.el, s.worstCell.percentile, ...
            s.worstCell.value);
    end
    fprintf('-------------------------------------------\n');
end
