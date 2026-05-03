function out = estimate_r23_mvp_cube_memory(numAz, numEl, numSnapshots, opts)
%ESTIMATE_R23_MVP_CUBE_MEMORY Memory estimate for the R23 MVP EIRP cube.
%
%   OUT = estimate_r23_mvp_cube_memory(NUMAZ, NUMEL, NUMSNAPSHOTS)
%   OUT = estimate_r23_mvp_cube_memory(NUMAZ, NUMEL, NUMSNAPSHOTS, OPTS)
%
%   Pure-arithmetic estimator for the full-cube Monte Carlo path used by
%   run_monte_carlo_snapshots. The MVP returns the per-snapshot EIRP cube
%       eirpGrid : Naz x Nel x numSnapshots  (double precision)
%   so callers can compute a CDF per grid cell directly. This estimator
%   sizes that cube (plus a small per-snapshot metadata overhead) so a
%   guard can fail closed before the cube is allocated.
%
%   Inputs:
%       numAz         number of azimuth grid points
%       numEl         number of elevation grid points
%       numSnapshots  number of Monte Carlo snapshots stored
%       opts          optional struct:
%           .perSnapshotMetadataBytes   bytes attributed to one entry of
%                                       perSnapshotBeams + perSnapshotUes
%                                       (default 4096; covers a small
%                                       struct of beam / UE arrays).
%           .largeThresholdMiB          MiB threshold above which the
%                                       estimate is flagged as "large".
%                                       Default 256.
%           .verbose                    logical, prints summary if true
%                                       (default false).
%
%   Output struct fields:
%       numGridAz                pass-through
%       numGridEl                pass-through
%       numSnapshots             pass-through
%       numCells                 numAz * numEl
%       eirpCubeBytes            bytes for the Naz x Nel x numSnapshots
%                                double cube
%       eirpCubeMiB              eirpCubeBytes / 1024^2
%       perSnapshotMetadataBytes bytes attributed to per-snapshot beam /
%                                UE struct cells (numSnapshots *
%                                opts.perSnapshotMetadataBytes)
%       estimatedTotalBytes      eirpCubeBytes + perSnapshotMetadataBytes
%       estimatedTotalMiB        estimatedTotalBytes / 1024^2
%       largeThresholdMiB        pass-through
%       isLarge                  logical, estimatedTotalMiB > threshold
%       warningMessage           short user-facing reminder string. Empty
%                                when isLarge is false.
%       summary                  human-readable multiline summary
%
%   This estimator never allocates the cube it sizes; it is intended to
%   be called by run_monte_carlo_snapshots before the cube is allocated
%   and by tests that want to assert the guard fires on oversized jobs.
%   For very large grids / numSnapshots combinations, prefer the
%   streaming runR23AasEirpCdfGrid path which never materializes the
%   per-draw EIRP cube.

    if nargin < 3
        error('estimate_r23_mvp_cube_memory:missingInputs', ...
            'numAz, numEl, numSnapshots are required.');
    end
    if nargin < 4 || isempty(opts)
        opts = struct();
    end

    validateScalarPositive(numAz,        'numAz');
    validateScalarPositive(numEl,        'numEl');
    validateScalarPositive(numSnapshots, 'numSnapshots');

    if ~isfield(opts, 'perSnapshotMetadataBytes') || ...
            isempty(opts.perSnapshotMetadataBytes)
        opts.perSnapshotMetadataBytes = 4096;
    end
    if ~isfield(opts, 'largeThresholdMiB') || ...
            isempty(opts.largeThresholdMiB)
        opts.largeThresholdMiB = 256;
    end
    if ~isfield(opts, 'verbose') || isempty(opts.verbose)
        opts.verbose = false;
    end

    bytesDouble = 8;
    nAz   = double(numAz);
    nEl   = double(numEl);
    nSnap = double(numSnapshots);
    nMeta = double(opts.perSnapshotMetadataBytes);

    nCells     = nAz * nEl;
    cubeBytes  = nCells * nSnap * bytesDouble;
    metaBytes  = nSnap * nMeta;
    totalBytes = cubeBytes + metaBytes;

    bytesPerMiB = 1024 * 1024;

    out = struct();
    out.numGridAz                = nAz;
    out.numGridEl                = nEl;
    out.numSnapshots             = nSnap;
    out.numCells                 = nCells;
    out.eirpCubeBytes            = cubeBytes;
    out.eirpCubeMiB              = cubeBytes / bytesPerMiB;
    out.perSnapshotMetadataBytes = metaBytes;
    out.estimatedTotalBytes      = totalBytes;
    out.estimatedTotalMiB        = totalBytes / bytesPerMiB;
    out.largeThresholdMiB        = double(opts.largeThresholdMiB);
    out.isLarge                  = out.estimatedTotalMiB > out.largeThresholdMiB;

    if out.isLarge
        out.warningMessage = sprintf( ...
            ['R23 MVP EIRP cube ~%.2f MiB (Naz=%d * Nel=%d * '...
             'numSnapshots=%d * 8 B) exceeds threshold of %.2f MiB. '...
             'Reduce grid points or numSnapshots, or use the streaming '...
             'runR23AasEirpCdfGrid workflow that never materializes '...
             'the per-draw EIRP cube.'], ...
            out.estimatedTotalMiB, nAz, nEl, nSnap, ...
            out.largeThresholdMiB);
    else
        out.warningMessage = '';
    end

    out.summary = buildSummary(out);

    if opts.verbose
        fprintf('%s\n', out.summary);
    end
end

% ------------------------------------------------------------------------
function validateScalarPositive(v, name)
    if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
        error('estimate_r23_mvp_cube_memory:badInput', ...
            '%s must be a positive finite scalar.', name);
    end
end

% ------------------------------------------------------------------------
function s = buildSummary(out)
    lines = {};
    lines{end+1} = sprintf( ...
        'R23 MVP cube memory estimate: %d az x %d el x %d snapshots', ...
        out.numGridAz, out.numGridEl, out.numSnapshots);
    lines{end+1} = sprintf('  num az/el cells          : %d', out.numCells);
    lines{end+1} = sprintf('  EIRP cube (double)       : %s', humanBytes(out.eirpCubeBytes));
    lines{end+1} = sprintf('  per-snapshot metadata    : %s', humanBytes(out.perSnapshotMetadataBytes));
    lines{end+1} = sprintf('  estimated total          : %s', humanBytes(out.estimatedTotalBytes));
    lines{end+1} = sprintf('  large threshold          : %.2f MiB', out.largeThresholdMiB);
    if out.isLarge
        lines{end+1} = sprintf('  WARNING: %s', out.warningMessage);
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
