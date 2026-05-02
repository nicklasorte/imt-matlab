function cmp = imtAasComparePatternCut(angleDeg, actualDbm, ...
        refAngleDeg, refDbm, opts)
%IMTAASCOMPAREPATTERNCUT Compare a MATLAB-generated EIRP cut to a reference.
%
%   CMP = imtAasComparePatternCut(ANGLEDEG, ACTUALDBM, ...
%                                 REFANGLEDEG, REFDBM, OPTS)
%
%   Compares one 1-D pattern cut (EIRP vs angle) against a reference cut
%   and returns max / RMS / main-lobe error metrics together with a
%   pass/fail flag and a list of fail reasons.
%
%   Inputs:
%       angleDeg       1xN actual angle vector [deg]
%       actualDbm      1xN actual EIRP vector [dBm/100 MHz]
%       refAngleDeg    1xM reference angle vector [deg]
%       refDbm         1xM reference EIRP vector [dBm/100 MHz]
%       opts           optional struct with fields (defaults shown):
%                        .interpolateReference    true
%                        .ignoreBelowDbm          -80
%                        .maxAbsErrorDb           1.0
%                        .rmsErrorDb              0.5
%                        .mainLobeWindowDeg       20
%                        .mainLobeMaxAbsErrorDb   0.5
%
%   Behavior:
%   * If the reference angle grid differs from the actual grid and
%     opts.interpolateReference is true, the reference is linearly
%     interpolated onto the actual grid. If interpolateReference is
%     false the two grids must match exactly.
%   * Points where BOTH actual and reference are below
%     opts.ignoreBelowDbm are excluded from all metrics, because deep
%     pattern nulls and numeric floor handling can vary across
%     implementations.
%   * The main-lobe window is centered on the actual peak angle and is
%     opts.mainLobeWindowDeg wide (i.e. peakAngle +/- window/2).
%   * The pass flag is true only if all three thresholds are met. The
%     failReasons cell array contains a human-readable line per failure.
%
%   Output struct fields:
%       cmp.angleDeg
%       cmp.actualDbm
%       cmp.referenceDbm           reference, aligned to actual grid
%       cmp.errorDb                actualDbm - referenceDbm (per-point)
%       cmp.maxAbsErrorDb
%       cmp.rmsErrorDb
%       cmp.meanErrorDb
%       cmp.maxAbsErrorMainLobeDb
%       cmp.rmsErrorMainLobeDb
%       cmp.numCompared            points that contributed to metrics
%       cmp.numIgnored             points dropped via ignoreBelowDbm
%       cmp.numMainLobe            points inside the main-lobe window
%       cmp.peakAngleDeg           argmax of actualDbm
%       cmp.peakActualDbm
%       cmp.mainLobeWindowDeg
%       cmp.opts                   resolved options (post-default)
%       cmp.pass                   logical
%       cmp.failReasons            cell array of human-readable strings
%
%   See also imtAasLoadReferenceCutCsv, plotImtAasReferenceComparison.

    if nargin < 4
        error('imtAasComparePatternCut:notEnoughInputs', ...
            ['imtAasComparePatternCut requires 4 inputs: ', ...
             'angleDeg, actualDbm, refAngleDeg, refDbm.']);
    end
    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts) || ~isscalar(opts)
        error('imtAasComparePatternCut:invalidOpts', ...
            'opts must be a scalar struct (or [] for defaults).');
    end

    opts = applyDefaults(opts);

    % ---- validate vectors --------------------------------------------
    angleDeg    = validateVector(angleDeg,    'angleDeg');
    actualDbm   = validateVector(actualDbm,   'actualDbm');
    refAngleDeg = validateVector(refAngleDeg, 'refAngleDeg');
    refDbm      = validateVector(refDbm,      'refDbm');

    if numel(angleDeg) ~= numel(actualDbm)
        error('imtAasComparePatternCut:lengthMismatch', ...
            ['angleDeg (%d) and actualDbm (%d) must have the same ', ...
             'number of elements.'], numel(angleDeg), numel(actualDbm));
    end
    if numel(refAngleDeg) ~= numel(refDbm)
        error('imtAasComparePatternCut:lengthMismatch', ...
            ['refAngleDeg (%d) and refDbm (%d) must have the same ', ...
             'number of elements.'], numel(refAngleDeg), numel(refDbm));
    end
    if any(~isfinite(angleDeg)) || any(~isfinite(refAngleDeg))
        error('imtAasComparePatternCut:nonFiniteAngle', ...
            'angleDeg / refAngleDeg must be finite.');
    end
    if any(isnan(actualDbm)) || any(isnan(refDbm))
        error('imtAasComparePatternCut:nanEirp', ...
            'actualDbm / refDbm must not contain NaN.');
    end

    % ---- align reference to actual grid -------------------------------
    if isequal(size(refAngleDeg), size(angleDeg)) && ...
            all(refAngleDeg == angleDeg)
        refAligned = refDbm;
    elseif opts.interpolateReference
        refAligned = linearInterpReference(refAngleDeg, refDbm, angleDeg);
    else
        error('imtAasComparePatternCut:gridMismatch', ...
            ['Reference grid does not match actual grid and ', ...
             'opts.interpolateReference is false.']);
    end

    % ---- per-point error and ignore mask -----------------------------
    errorDb = actualDbm - refAligned;

    keepMask = ~(actualDbm < opts.ignoreBelowDbm & ...
                 refAligned < opts.ignoreBelowDbm);
    keepMask = keepMask & isfinite(errorDb);
    numIgnored = numel(angleDeg) - sum(keepMask);

    % ---- peak / main-lobe window (based on actual cut) ---------------
    [peakActual, peakIdx] = max(actualDbm);
    peakAngle = angleDeg(peakIdx);
    halfWin   = opts.mainLobeWindowDeg / 2;
    mainMask  = abs(angleDeg - peakAngle) <= halfWin + 1e-12;
    mainKeep  = keepMask & mainMask;

    % ---- aggregate metrics -------------------------------------------
    if any(keepMask)
        keptErr           = errorDb(keepMask);
        maxAbsErrorDb     = max(abs(keptErr));
        rmsErrorDb        = sqrt(mean(keptErr .^ 2));
        meanErrorDb       = mean(keptErr);
    else
        maxAbsErrorDb     = 0;
        rmsErrorDb        = 0;
        meanErrorDb       = 0;
    end

    if any(mainKeep)
        mainErr                = errorDb(mainKeep);
        maxAbsErrorMainLobeDb  = max(abs(mainErr));
        rmsErrorMainLobeDb     = sqrt(mean(mainErr .^ 2));
    else
        maxAbsErrorMainLobeDb  = 0;
        rmsErrorMainLobeDb     = 0;
    end

    % ---- pass/fail ----------------------------------------------------
    failReasons = {};
    if maxAbsErrorDb > opts.maxAbsErrorDb
        failReasons{end + 1} = sprintf( ...
            'maxAbsErrorDb %.4f exceeds threshold %.4f', ...
            maxAbsErrorDb, opts.maxAbsErrorDb);
    end
    if rmsErrorDb > opts.rmsErrorDb
        failReasons{end + 1} = sprintf( ...
            'rmsErrorDb %.4f exceeds threshold %.4f', ...
            rmsErrorDb, opts.rmsErrorDb);
    end
    if maxAbsErrorMainLobeDb > opts.mainLobeMaxAbsErrorDb
        failReasons{end + 1} = sprintf( ...
            'maxAbsErrorMainLobeDb %.4f exceeds threshold %.4f', ...
            maxAbsErrorMainLobeDb, opts.mainLobeMaxAbsErrorDb);
    end
    if ~any(keepMask)
        failReasons{end + 1} = ...
            'no points contributed (all below ignoreBelowDbm)';
    end

    cmp = struct();
    cmp.angleDeg               = angleDeg;
    cmp.actualDbm              = actualDbm;
    cmp.referenceDbm           = refAligned;
    cmp.errorDb                = errorDb;
    cmp.maxAbsErrorDb          = maxAbsErrorDb;
    cmp.rmsErrorDb             = rmsErrorDb;
    cmp.meanErrorDb            = meanErrorDb;
    cmp.maxAbsErrorMainLobeDb  = maxAbsErrorMainLobeDb;
    cmp.rmsErrorMainLobeDb     = rmsErrorMainLobeDb;
    cmp.numCompared            = sum(keepMask);
    cmp.numIgnored             = numIgnored;
    cmp.numMainLobe            = sum(mainKeep);
    cmp.peakAngleDeg           = peakAngle;
    cmp.peakActualDbm          = peakActual;
    cmp.mainLobeWindowDeg      = opts.mainLobeWindowDeg;
    cmp.opts                   = opts;
    cmp.pass                   = isempty(failReasons);
    cmp.failReasons            = failReasons;
end

% =====================================================================

function opts = applyDefaults(opts)
    defaults = struct( ...
        'interpolateReference',   true, ...
        'ignoreBelowDbm',         -80, ...
        'maxAbsErrorDb',          1.0, ...
        'rmsErrorDb',             0.5, ...
        'mainLobeWindowDeg',      20, ...
        'mainLobeMaxAbsErrorDb',  0.5);
    f = fieldnames(defaults);
    for i = 1:numel(f)
        if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
            opts.(f{i}) = defaults.(f{i});
        end
    end
end

function v = validateVector(x, name)
    if ~isnumeric(x) || ~isreal(x) || ~isvector(x) || isempty(x)
        error('imtAasComparePatternCut:invalidVector', ...
            '%s must be a non-empty real numeric vector.', name);
    end
    v = double(x(:).');
end

function refOnActual = linearInterpReference(refAngleDeg, refDbm, angleDeg)
%LINEARINTERPREFERENCE Linearly interpolate refDbm(refAngleDeg) onto angleDeg.
%   Sorts the reference by angle (so callers can pass unsorted refs),
%   then uses interp1(..., 'linear', 'extrap') so that points slightly
%   outside the reference range are handled deterministically rather
%   than producing NaN. Out-of-range extrapolation will typically push
%   error metrics up and is the intended signal that the reference does
%   not cover that segment of the actual cut.
    [angleSorted, sortIdx] = sort(refAngleDeg);
    refSorted = refDbm(sortIdx);

    % drop duplicate angles (keep first), since interp1 rejects them
    dupMask = [false, diff(angleSorted) == 0];
    if any(dupMask)
        angleSorted(dupMask) = [];
        refSorted(dupMask)   = [];
    end

    refOnActual = interp1(angleSorted, refSorted, angleDeg, ...
        'linear', 'extrap');
end
