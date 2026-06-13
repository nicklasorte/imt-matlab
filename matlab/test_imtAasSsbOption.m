function results = test_imtAasSsbOption()
%TEST_IMTAASSSBOPTION Self tests for the SSB broadcast sweep builder.
%
%   RESULTS = test_imtAasSsbOption()
%
%   Covers (default sweep geometry coarseConf [3 3 2], elTiers [6 0 -3]):
%       T1.  coarseConf [3 3 2] -> 8 sweep beams.
%       T2.  azimuth centres lie inside the sweep span (sector az limits).
%       T3.  the beam elevation tiers equal elTiersDeg ([6 0 -3]).
%       T4.  envelope_dBm <= params.sectorEirpDbm + tol (splitSectorPower
%            false -> each beam peaks at the full sector EIRP).
%       T5.  returns ssb + timeWeighted + config; config echoes geometry.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    params = imtAasDefaultParams();
    sector = imtAasSingleSectorParams('macroUrban', params);
    az = -60:5:60;     % 25
    el = -12:1:6;       % 19
    stats = makeStubStats(az, el, 3);

    res = imtAasSsbOption(az, el, params, sector, stats, struct());

    % ---- T1: 8 beams ----
    results = check(results, res.ssb.numBeams == 8, ...
        'T1: coarseConf [3 3 2] -> 8 sweep beams');

    % ---- T2: az centres inside sweep span ----
    lo = sector.azLimitsDeg(1); hi = sector.azLimitsDeg(2);
    okAz = all(res.ssb.beamAzDeg >= lo - 1e-9) && all(res.ssb.beamAzDeg <= hi + 1e-9);
    results = check(results, okAz, ...
        sprintf('T2: az centres inside azRange [%g, %g]', lo, hi));

    % ---- T3: el tiers ----
    okEl = isequal(unique(res.ssb.beamElDeg(:)).', [-3 0 6]);
    results = check(results, okEl, 'T3: beam elevation tiers == elTiersDeg [6 0 -3]');

    % ---- T4: envelope below sector peak ----
    okEnv = max(res.ssb.envelope_dBm(:)) <= params.sectorEirpDbm + 1e-6;
    results = check(results, okEnv, sprintf( ...
        'T4: max envelope_dBm (%.4f) <= sectorEirpDbm (%.4f) + tol', ...
        max(res.ssb.envelope_dBm(:)), params.sectorEirpDbm));

    % ---- T5: output shape + config echo ----
    okStruct = isfield(res, 'ssb') && isstruct(res.ssb) && ...
               isfield(res, 'timeWeighted') && isstruct(res.timeWeighted) && ...
               isfield(res, 'config') && isstruct(res.config);
    okShape  = isequal(size(res.ssb.envelope_dBm), [numel(az), numel(el)]) && ...
               isequal(size(res.ssb.timeAvg_dBm),  [numel(az), numel(el)]) && ...
               size(res.ssb.perBeamEirpDbm, 3) == 8;
    okCfg    = isequal(res.config.coarseConf, [3 3 2]) && ...
               isequal(res.config.elTiersDeg, [6 0 -3]) && ...
               res.config.numBeams == 8 && ...
               isequal(res.config.azRangeDeg, double(sector.azLimitsDeg(:).'));
    results = check(results, okStruct && okShape && okCfg, ...
        'T5: returns ssb + timeWeighted + config; config echoes geometry');

    fprintf('\n--- test_imtAasSsbOption summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function stats = makeStubStats(az, el, nUe)
%MAKESTUBSTATS Minimal traffic aggregator stub on the (az, el) grid.
    Naz = numel(az); Nel = numel(el);
    rng(7);
    stats = struct();
    stats.azGrid          = az;
    stats.elGrid          = el;
    stats.numUesPerSector = nUe;
    stats.mean_lin_mW     = 1 + rand(Naz, Nel);
    stats.max_dBm         = 70 + 5 .* rand(Naz, Nel);
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
