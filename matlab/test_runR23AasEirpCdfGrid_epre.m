function results = test_runR23AasEirpCdfGrid_epre()
%TEST_RUNR23AASEIRPCDFGRID_EPRE opts.epre per-RE EPRE-offset integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_epre()
%
%   Covers the opts.epre wiring on runR23AasEirpCdfGrid:
%       T1.  opts.epre absent -> out.epre == [] and
%            metadata.includesEpre == false.
%       T2a. opts.epre = struct() -> out.epre present with the offset /
%            envelope fields and metadata.includesEpre == true.
%       T2b. DEFAULT-OFF invariant: the traffic streaming aggregator
%            (counts / sum_lin_mW / min_dBm / max_dBm / mean_dBm) and the
%            percentileMaps are byte-identical with EPRE ON vs OFF for a
%            fixed seed -- opts.epre never mutates the band-integrated path.
%       T2c. The baseline band-integrated sector-peak self-check is
%            unchanged and still passes when opts.epre is on.
%       T3.  out.epre.perRePeakEnvelope_dBm == stats.max_dBm +
%            offsets.hottestBoostDb exactly (elementwise).
%       T4.  The per-RE envelope is NOT clamped to the band-integrated
%            sector peak: with a positive boost it strictly exceeds
%            stats.max_dBm where finite, and the self-check is computed
%            from stats.max_dBm (NOT the envelope).
%       T5.  opts.ssb + opts.epre both on -> the opts.ssb outputs
%            (out.ssb / out.timeWeighted) are byte-identical to an
%            opts.ssb-only run with the same seed.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 20;
    baseOpts.azGridDeg   = -60:5:60;      % 25
    baseOpts.elGridDeg   = -12:1:6;        % 19 (spans horizon + steep down)
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 4242;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    base = runR23AasEirpCdfGrid(baseOpts);

    % ---- T1: EPRE absent -> out.epre == [] --------------------------
    ok1 = isfield(base, 'epre') && isempty(base.epre) && ...
          isfield(base.metadata, 'includesEpre') && ...
          ~base.metadata.includesEpre;
    results = check(results, ok1, ...
        'T1: opts.epre absent -> out.epre==[], includesEpre==false');

    % ---- T2a: EPRE present (DM-RS 2 CDM groups + PT-RS 4 layers) -----
    epreOpts = baseOpts;
    epreOpts.epre = struct('dmrsCdmGroupsNoData', 2, ...
        'includePtrs', true, 'pdschLayers', 4);   % hottest = 6 dB (PT-RS)
    withEpre = runR23AasEirpCdfGrid(epreOpts);

    ok2a = isfield(withEpre, 'epre') && isstruct(withEpre.epre) && ...
           isfield(withEpre.epre, 'perRePeakEnvelope_dBm') && ...
           isfield(withEpre.epre, 'hottestBoostDb') && ...
           isfield(withEpre.metadata, 'includesEpre') && ...
           withEpre.metadata.includesEpre == true && ...
           isfield(withEpre.metadata, 'epreConfig');
    results = check(results, ok2a, ...
        'T2a: opts.epre=struct() -> out.epre present, includesEpre==true');

    % ---- T2b: traffic path byte-identical (DEFAULT-OFF invariant) ----
    ok2b = isequal(withEpre.stats.counts,          base.stats.counts) && ...
           isequaln(withEpre.stats.sum_lin_mW,     base.stats.sum_lin_mW) && ...
           isequaln(withEpre.stats.min_dBm,        base.stats.min_dBm) && ...
           isequaln(withEpre.stats.max_dBm,        base.stats.max_dBm) && ...
           isequaln(withEpre.stats.mean_dBm,       base.stats.mean_dBm) && ...
           isequaln(withEpre.percentileMaps.values, base.percentileMaps.values);
    results = check(results, ok2b, ...
        'T2b: traffic stats + percentileMaps byte-identical EPRE ON vs OFF (fixed seed)');

    % ---- T2c: band-integrated self-check unchanged + passes ---------
    ok2c = isequaln(withEpre.selfCheck, base.selfCheck) && ...
           strcmp(withEpre.selfCheck.powerSemantics.status, 'pass');
    results = check(results, ok2c, ...
        'T2c: band-integrated sector-peak self-check unchanged and passes with EPRE on');

    % ---- T3: envelope == stats.max_dBm + hottestBoostDb -------------
    expectEnv = withEpre.stats.max_dBm + withEpre.epre.hottestBoostDb;
    env = withEpre.epre.perRePeakEnvelope_dBm;
    diffEnv = abs(env - expectEnv);
    ok3 = isequal(size(env), size(withEpre.stats.max_dBm)) && ...
          max(diffEnv(isfinite(diffEnv))) <= 1e-9 && ...
          abs(withEpre.epre.hottestBoostDb - 6) <= 1e-12;
    results = check(results, ok3, ...
        'T3: perRePeakEnvelope_dBm == stats.max_dBm + hottestBoostDb (6 dB)');

    % ---- T4: envelope not clamped to band-integrated sector peak ----
    % With a +6 dB boost the envelope strictly exceeds the per-cell
    % traffic peak everywhere it is finite, and may exceed the 78.3 dBm
    % sector peak. The self-check is built from stats.max_dBm, never the
    % envelope, so the observed self-check max stays <= the sector peak.
    finiteMask = isfinite(withEpre.stats.max_dBm);
    strictlyHotter = all(env(finiteMask) > withEpre.stats.max_dBm(finiteMask) + 1e-9);
    sectorPeak = withEpre.metadata.sectorEirpDbm;
    envExceedsSectorPeak = any(env(finiteMask) > sectorPeak);
    selfCheckMaxBelowSector = withEpre.selfCheck.powerSemantics.observedMaxGridEirp_dBm ...
        <= sectorPeak + 1e-6;
    ok4 = strictlyHotter && envExceedsSectorPeak && selfCheckMaxBelowSector;
    results = check(results, ok4, sprintf( ...
        ['T4: per-RE envelope hotter than traffic peak (max env %.2f vs ', ...
         'sector peak %.2f dBm) and excluded from the band-integrated ', ...
         'self-check'], max(env(finiteMask)), sectorPeak));

    % ---- T5: opts.ssb outputs unchanged when opts.epre is also on ----
    ssbOnly = baseOpts;
    ssbOnly.ssb = struct();
    ssbRun = runR23AasEirpCdfGrid(ssbOnly);

    ssbAndEpre = baseOpts;
    ssbAndEpre.ssb  = struct();
    ssbAndEpre.epre = struct('dmrsCdmGroupsNoData', 2);   % DM-RS only, 3 dB
    bothRun = runR23AasEirpCdfGrid(ssbAndEpre);

    ok5 = isequaln(bothRun.ssb.timeAvg_dBm,        ssbRun.ssb.timeAvg_dBm) && ...
          isequaln(bothRun.ssb.envelope_dBm,       ssbRun.ssb.envelope_dBm) && ...
          isequaln(bothRun.timeWeighted.avg_dBm,   ssbRun.timeWeighted.avg_dBm) && ...
          isequaln(bothRun.timeWeighted.peak_dBm,  ssbRun.timeWeighted.peak_dBm) && ...
          isequaln(bothRun.timeWeighted.sweepShareOfAvg, ssbRun.timeWeighted.sweepShareOfAvg) && ...
          isequal(bothRun.stats.counts, ssbRun.stats.counts) && ...
          bothRun.metadata.includesEpre == true && ...
          isstruct(bothRun.epre);
    results = check(results, ok5, ...
        'T5: opts.ssb outputs byte-identical with opts.epre also on (and EPRE attached)');

    fprintf('\n--- test_runR23AasEirpCdfGrid_epre summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

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
