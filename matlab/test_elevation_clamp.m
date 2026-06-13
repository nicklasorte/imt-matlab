function results = test_elevation_clamp()
%TEST_ELEVATION_CLAMP Self tests for the non-breaking clampElevation toggle.
%
%   RESULTS = test_elevation_clamp()
%
%   Exercises the opts.clampElevation knob threaded through the R23 AAS EIRP
%   pipeline (runR23AasEirpCdfGrid -> imtAasGenerateBeamSet ->
%   imtAasApplyBeamLimits). The elevation clamp gates beam steering to the
%   nominal [-10, 0] deg vertical-coverage envelope; disabling it swaps the
%   elevation limit vector to [-Inf, Inf] so beams may steer below the
%   horizon gate. Azimuth clamping (+-60 deg) is UNAFFECTED in both modes,
%   and the default MUST stay TRUE so today's results are reproduced
%   byte-for-byte.
%
%   Covers (driver level, base MATLAB only, fast):
%       T1.  Default contract: omitting clampElevation resolves to true in
%            both out.opts and out.metadata (and metadata reports the
%            nominal elevationLimitsDeg gate).
%       T2.  Toggle propagates: clamp on vs off changes percentileMaps, the
%            no-clamp pointing heatmap points below -10 deg, and the clamped
%            pointing heatmap holds at / above -10 deg.
%       T3.  Back-compat invariant: omitting clampElevation == passing true
%            (same seed) yields byte-identical maps / stats / pointing.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t_default_resolves_true(results);
    results = t_toggle_changes_results(results);
    results = t_backcompat_default_equals_true(results);

    fprintf('\n--- test_elevation_clamp summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% Shared small Monte Carlo options (fast). numUesPerSector is set high
% enough that, with no elevation clamp, the per-cell pointing heatmap
% reliably reaches below the -10 deg vertical-coverage gate: area-uniform
% radial draws put only a small fraction of any single beam below the
% gate, so a larger simultaneous beam set keeps the driver-level
% "points lower" assertion robust without depending on a single draw.
% =====================================================================
function opts = mcOpts()
    opts = struct();
    opts.aasGeometryPreset      = 'r23_1x3_default';
    opts.numMc                  = 50;
    opts.numUesPerSector        = 40;
    opts.seed                   = 3;
    opts.azGridDeg              = -120:10:120;   % 25
    opts.elGridDeg              = -30:2:30;       % 31 (spans below -10 deg)
    opts.binEdgesDbm            = -120:1:120;
    opts.percentiles            = [5 50 95];
    opts.computePointingHeatmap = true;
end

% =====================================================================
% T1: default resolves true (cheap config; only the flag is inspected).
% =====================================================================
function r = t_default_resolves_true(r)
    opts = mcOpts();
    opts.numMc                  = 5;
    opts.numUesPerSector        = 3;
    opts.computePointingHeatmap = false;
    % clampElevation deliberately omitted.

    out = runR23AasEirpCdfGrid(opts);
    ok = isfield(out.opts, 'clampElevation') && ...
         islogical(out.opts.clampElevation) && ...
         out.opts.clampElevation == true && ...
         isfield(out.metadata, 'clampElevation') && ...
         out.metadata.clampElevation == true && ...
         isfield(out.metadata, 'elevationLimitsDeg') && ...
         isequal(out.metadata.elevationLimitsDeg, [-10 0]);
    r = check(r, ok, ...
        'T1: omitting clampElevation resolves true in out.opts + out.metadata');
end

% =====================================================================
% T2: toggle changes maps and lets the pointing heatmap point lower.
% =====================================================================
function r = t_toggle_changes_results(r)
    base = mcOpts();

    optOn = base; optOn.clampElevation = true;
    rOn = runR23AasEirpCdfGrid(optOn);

    optOff = base; optOff.clampElevation = false;
    rOff = runR23AasEirpCdfGrid(optOff);

    okDiffers  = ~isequal(rOn.percentileMaps.values, rOff.percentileMaps.values);
    minOff     = min(rOff.pointing.elevationDegGrid(:));
    minOn      = min(rOn.pointing.elevationDegGrid(:));
    okOffLower = minOff < -10;
    okOnHolds  = minOn >= -10 - 1e-6;

    r = check(r, okDiffers && okOffLower && okOnHolds, sprintf( ...
        ['T2: toggle changes maps; no-clamp pointing min=%.2f deg (<-10), ' ...
         'clamp pointing min=%.2f deg (>=-10)'], minOff, minOn));
end

% =====================================================================
% T3: back-compat invariant (omit == clampElevation=true, same seed).
% =====================================================================
function r = t_backcompat_default_equals_true(r)
    base = mcOpts();
    base.numMc           = 20;
    base.numUesPerSector = 3;

    rDefault = runR23AasEirpCdfGrid(base);            % no clampElevation field

    optTrue = base; optTrue.clampElevation = true;
    rTrue = runR23AasEirpCdfGrid(optTrue);

    ok = isequal(rDefault.percentileMaps.values, rTrue.percentileMaps.values) && ...
         isequal(rDefault.stats.counts, rTrue.stats.counts) && ...
         isequaln(rDefault.stats.sum_lin_mW, rTrue.stats.sum_lin_mW) && ...
         isequaln(rDefault.pointing.elevationDegGrid, rTrue.pointing.elevationDegGrid);
    r = check(r, ok, ...
        'T3: omit clampElevation == clampElevation=true (identical maps/stats/pointing)');
end

% =====================================================================
% Helpers
% =====================================================================
function r = check(r, cond, msg)
    if cond
        r.summary{end+1} = ['PASS  ' msg];
    else
        r.summary{end+1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end
