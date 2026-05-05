function results = test_r23_parameterized_run()
%TEST_R23_PARAMETERIZED_RUN Self tests for parameterized runR23AasEirpCdfGrid.
%
%   Covers:
%       T1.  default run still works (no opts).
%       T2.  default numUesPerSector = 3.
%       T3.  custom numUesPerSector via flat opts changes numBeams.
%       T4.  custom numUesPerSector via name-value pairs.
%       T5.  invalid numUesPerSector (zero / negative / non-integer)
%            raises a clear error.
%       T6.  default maxEirpPerSector_dBm = 78.3.
%       T7.  custom maxEirpPerSector_dBm reduces sector peak EIRP by
%            exactly the requested delta.
%       T8.  suburban preset via 'environment' name-value carries
%            through to deployment / cellRadius / bsHeight.
%       T9.  suburban preset via nested params struct wires through.
%       T10. pointing heatmap fields exist with correct grid sizes.
%       T11. pointing values are finite (or NaN only where
%            numSamples == 0).
%       T12. pointing azimuth values lie within sector az limits
%            (since steerAzDeg is clamped); elevation values lie
%            within sector el limits.
%       T13. metadata carries environment / numUesPerSector /
%            maxEirpPerSector_dBm / sourceDefault.

    results.summary = {};
    results.passed  = true;

    results = t_default_run_works(results);
    results = t_default_num_ues(results);
    results = t_custom_num_ues_flat(results);
    results = t_custom_num_ues_nv(results);
    results = t_invalid_num_ues_errors(results);
    results = t_default_max_eirp(results);
    results = t_custom_max_eirp_reduces_eirp(results);
    results = t_suburban_via_nv(results);
    results = t_suburban_via_nested(results);
    results = t_pointing_grid_sizes(results);
    results = t_pointing_values_finite(results);
    results = t_pointing_within_limits(results);
    results = t_metadata_carries_run_inputs(results);

    fprintf('\n--- test_r23_parameterized_run summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function r = t_default_run_works(r)
    out = runR23AasEirpCdfGrid(smallOpts());
    ok = isfield(out, 'stats') && isstruct(out.stats) && ...
         isfield(out, 'percentileMaps') && isstruct(out.percentileMaps) && ...
         isfield(out, 'pointing') && isstruct(out.pointing) && ...
         isfield(out, 'metadata') && isstruct(out.metadata);
    r = check(r, ok, 'T1: default run returns stats / percentileMaps / pointing / metadata');
end

function r = t_default_num_ues(r)
    out = runR23AasEirpCdfGrid(smallOpts());
    ok = out.stats.numUesPerSector == 3 && out.stats.numBeams == 3;
    r = check(r, ok, 'T2: default numUesPerSector = 3');
end

function r = t_custom_num_ues_flat(r)
    opts = smallOpts();
    opts.numUesPerSector = 7;
    out = runR23AasEirpCdfGrid(opts);
    ok = out.stats.numUesPerSector == 7 && out.stats.numBeams == 7;
    r = check(r, ok, 'T3: numUesPerSector=7 via flat opts -> numBeams=7');
end

function r = t_custom_num_ues_nv(r)
    out = runR23AasEirpCdfGrid( ...
        'numUesPerSector', 5, ...
        'numMc',           4, ...
        'azGridDeg',       -30:10:30, ...
        'elGridDeg',       -10:5:10, ...
        'binEdgesDbm',     -80:5:120, ...
        'percentiles',     [50 95], ...
        'seed',            123);
    ok = out.stats.numUesPerSector == 5 && out.stats.numBeams == 5;
    r = check(r, ok, 'T4: numUesPerSector=5 via name-value pairs -> numBeams=5');
end

function r = t_invalid_num_ues_errors(r)
    % Empty ([]) is treated as "use default" and should NOT error.
    bad = {0, -1, 2.5, 'abc'};
    allErrored = true;
    for k = 1:numel(bad)
        threw = false;
        try
            opts = smallOpts();
            opts.numUesPerSector = bad{k};
            runR23AasEirpCdfGrid(opts);
        catch
            threw = true;
        end
        if ~threw
            allErrored = false;
            break;
        end
    end
    r = check(r, allErrored, ...
        'T5: invalid numUesPerSector (0, -1, 2.5, non-numeric) -> error');
end

function r = t_default_max_eirp(r)
    out = runR23AasEirpCdfGrid(smallOpts());
    ok = abs(out.stats.sectorEirpDbm - 78.3) < 1e-9 && ...
         abs(out.metadata.maxEirpPerSector_dBm - 78.3) < 1e-9;
    r = check(r, ok, 'T6: default maxEirpPerSector_dBm = 78.3');
end

function r = t_custom_max_eirp_reduces_eirp(r)
    opts = smallOpts();
    opts.maxEirpPerSector_dBm = 75.0;
    out = runR23AasEirpCdfGrid(opts);

    expectedDelta = 78.3 - 75.0;
    okSector = abs(out.stats.sectorEirpDbm - 75.0) < 1e-9;

    % perBeamPeakEirpDbm should be 75.0 - 10*log10(numBeams).
    expectedPerBeam = 75.0 - 10 * log10(double(out.stats.numBeams));
    okPerBeam = abs(out.stats.perBeamPeakEirpDbm - expectedPerBeam) < 1e-9;

    % Mean grid should drop by ~3.3 dB (linear-mW mean shifts by the
    % same dB as the per-direction EIRP, since EIRP is a linear shift in
    % dB). Compare to a 78.3 baseline run with the same seed.
    out0 = runR23AasEirpCdfGrid(smallOpts());
    finiteIdx = isfinite(out.stats.mean_dBm) & isfinite(out0.stats.mean_dBm);
    delta = out0.stats.mean_dBm(finiteIdx) - out.stats.mean_dBm(finiteIdx);
    okDelta = ~isempty(delta) && all(abs(delta - expectedDelta) < 1e-6);

    r = check(r, okSector && okPerBeam && okDelta, ...
        sprintf( ...
        'T7: maxEirpPerSector_dBm=75 reduces sector EIRP by 3.3 dB (got mean shift %.4f dB)', ...
        median(delta)));
end

function r = t_suburban_via_nv(r)
    out = runR23AasEirpCdfGrid( ...
        'environment',     'suburban', ...
        'numMc',           3, ...
        'azGridDeg',       -30:10:30, ...
        'elGridDeg',       -10:5:10, ...
        'binEdgesDbm',     -80:5:120, ...
        'percentiles',     [50 95], ...
        'seed',            7);
    ok = strcmp(out.metadata.environment, 'suburban') && ...
         out.metadata.cellRadius_m == 800 && ...
         out.metadata.bsHeight_m == 20 && ...
         out.sector.cellRadius_m == 800 && ...
         out.sector.bsHeight_m == 20;
    r = check(r, ok, 'T8: environment="suburban" -> cellRadius=800, bsHeight=20');
end

function r = t_suburban_via_nested(r)
    p = r23DefaultParams('suburban');
    p.sim.numSnapshots = 3;
    p.sim.azGrid_deg   = -30:10:30;
    p.sim.elGrid_deg   = -10:5:10;
    p.sim.binEdges_dBm = -80:5:120;
    p.sim.percentiles  = [50 95];
    p.sim.randomSeed   = 11;
    out = runR23AasEirpCdfGrid(p);
    ok = strcmp(out.metadata.environment, 'suburban') && ...
         out.metadata.cellRadius_m == 800 && ...
         out.metadata.bsHeight_m == 20 && ...
         strcmp(out.sector.deployment, 'macroSuburban');
    r = check(r, ok, 'T9: nested suburban params propagate to sector / metadata');
end

function r = t_pointing_grid_sizes(r)
    opts = smallOpts();
    out  = runR23AasEirpCdfGrid(opts);
    Naz = numel(opts.azGridDeg);
    Nel = numel(opts.elGridDeg);
    okAz = isequal(size(out.pointing.azimuthDegGrid),   [Naz, Nel]);
    okEl = isequal(size(out.pointing.elevationDegGrid), [Naz, Nel]);
    okShapeMatchesEirp = isequal(size(out.pointing.azimuthDegGrid), ...
                                 size(out.stats.mean_dBm));
    r = check(r, okAz && okEl && okShapeMatchesEirp, ...
        sprintf('T10: pointing heatmap shapes = [%d %d] match EIRP grid', Naz, Nel));
end

function r = t_pointing_values_finite(r)
    opts = smallOpts();
    out  = runR23AasEirpCdfGrid(opts);
    az = out.pointing.azimuthDegGrid;
    el = out.pointing.elevationDegGrid;
    ns = double(out.pointing.numSamples);
    okAz = all(isfinite(az(ns > 0))) && all(isnan(az(ns == 0))) || ...
           all(isfinite(az(:)));   % when every cell has samples
    okEl = all(isfinite(el(ns > 0))) && all(isnan(el(ns == 0))) || ...
           all(isfinite(el(:)));
    r = check(r, okAz && okEl, ...
        'T11: pointing values finite where numSamples>0 (NaN only where numSamples==0)');
end

function r = t_pointing_within_limits(r)
    opts = smallOpts();
    out  = runR23AasEirpCdfGrid(opts);
    azLim = out.sector.azLimitsDeg;
    elLim = out.sector.elLimitsDeg;
    az = out.pointing.azimuthDegGrid;
    el = out.pointing.elevationDegGrid;
    azFinite = az(isfinite(az));
    elFinite = el(isfinite(el));
    % Allow tiny tolerance for circular-mean rounding.
    tol = 1e-6;
    okAz = isempty(azFinite) || ...
           (min(azFinite) >= azLim(1) - tol && ...
            max(azFinite) <= azLim(2) + tol);
    okEl = isempty(elFinite) || ...
           (min(elFinite) >= elLim(1) - tol && ...
            max(elFinite) <= elLim(2) + tol);
    r = check(r, okAz && okEl, ...
        sprintf('T12: pointing az in [%g,%g], el in [%g,%g] (sector steering limits)', ...
                azLim(1), azLim(2), elLim(1), elLim(2)));
end

function r = t_metadata_carries_run_inputs(r)
    opts = smallOpts();
    opts.numUesPerSector = 4;
    opts.maxEirpPerSector_dBm = 76.0;
    opts.environment = 'suburban';
    out = runR23AasEirpCdfGrid(opts);
    md = out.metadata;
    ok = strcmp(md.environment, 'suburban') && ...
         md.numUesPerSector == 4 && ...
         abs(md.maxEirpPerSector_dBm - 76.0) < 1e-9 && ...
         isfield(md, 'sourceDefault') && ~isempty(md.sourceDefault) && ...
         isfield(md, 'aasModel') && strcmp(char(md.aasModel), 'extended') && ...
         isfield(md, 'numSnapshots') && md.numSnapshots == md.numMc && ...
         isfield(md, 'randomSeed');
    r = check(r, ok, ...
        'T13: metadata carries environment / numUesPerSector / maxEirpPerSector_dBm / sourceDefault / aasModel');
end

% =====================================================================

function opts = smallOpts()
    opts = struct();
    opts.numMc       = 4;
    opts.azGridDeg   = -30:10:30;
    opts.elGridDeg   = -10:5:10;
    opts.binEdgesDbm = -80:5:120;
    opts.percentiles = [50 95];
    opts.seed        = 1;
    opts.deployment  = 'macroUrban';
end

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
