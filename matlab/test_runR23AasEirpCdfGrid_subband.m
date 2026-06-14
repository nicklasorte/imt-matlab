function results = test_runR23AasEirpCdfGrid_subband()
%TEST_RUNR23AASEIRPCDFGRID_SUBBAND opts.subband narrowband-density integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_subband()
%
%   Covers the opts.subband wiring on runR23AasEirpCdfGrid. This layer is a
%   SEPARATE OUTPUT (in the style of opts.epre): it never reshapes the
%   band-integrated CDF.
%       T1.  DEFAULT-OFF invariant: opts.subband absent and
%            struct('enable',false) -> stats / percentileMaps / selfCheck are
%            BYTE-IDENTICAL to a no-subband run (same seed); out.subband == []
%            / includesSubband == false. Enabling it leaves stats /
%            percentileMaps / selfCheck byte-identical too (no RNG, no touch).
%       T2.  Headline peak: out.subband.perSubbandPeak_dBmPerMHz ==
%            sectorEirp - 10*log10(bandwidthMHz), within 1e-9.
%       T3.  Single-beam reduction: with numBeams=1, the per-subband density
%            streaming max == band-integrated stats.max_dBm - 10*log10(BW),
%            within 1e-6 dB.
%       T4.  Delta: with numBeams=N equal split, deltaVsBandIntegrated_dB ~
%            10*log10(N) at a beam center, within 0.1 dB; deltaNominal_dB ==
%            10*log10(N) exactly.
%       T5.  Power-split independence: per-subband percentileMaps.values are
%            identical (1e-9) with vs without a NO-RNG opts.prbWeighting
%            (fixed weights), and with vs without a NO-RNG opts.layering
%            (fixed rank 1, spread 0), same seed.
%       T6.  Validity flag: subbandMHz > BW/N sets it; subbandMHz <= BW/N
%            clears it.
%       T7.  Combos: opts.subband + opts.epre / + opts.layering /
%            + opts.prbWeighting / + opts.ssb each attach and do NOT perturb
%            the host layer's stats; non-struct opts.subband errors.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 20;
    baseOpts.azGridDeg   = -60:5:60;       % 25
    baseOpts.elGridDeg   = -12:1:6;         % 19
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 4242;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    base = runR23AasEirpCdfGrid(baseOpts);
    BW      = base.metadata.bandwidthMHz;
    bandOff = 10 * log10(BW);
    sectorEirp = base.metadata.sectorEirpDbm;

    % ---- T1: default-off invariant ----------------------------------
    offOpts = baseOpts;
    offOpts.subband = struct('enable', false);
    offRun = runR23AasEirpCdfGrid(offOpts);

    subOpts = baseOpts;
    subOpts.subband = struct();             % presence -> enabled
    withSub = runR23AasEirpCdfGrid(subOpts);

    ok1 = isfield(base, 'subband') && isempty(base.subband) && ...
          ~base.metadata.includesSubband && ...
          isempty(offRun.subband) && ~offRun.metadata.includesSubband && ...
          isequal(offRun.stats.counts,            base.stats.counts) && ...
          isequaln(offRun.percentileMaps.values,  base.percentileMaps.values) && ...
          isequaln(offRun.selfCheck,              base.selfCheck) && ...
          isequal(withSub.stats.counts,           base.stats.counts) && ...
          isequaln(withSub.stats.sum_lin_mW,      base.stats.sum_lin_mW) && ...
          isequaln(withSub.stats.max_dBm,         base.stats.max_dBm) && ...
          isequaln(withSub.percentileMaps.values, base.percentileMaps.values) && ...
          isequaln(withSub.selfCheck,             base.selfCheck) && ...
          withSub.metadata.includesSubband == true && ...
          isstruct(withSub.subband) && ...
          isfield(withSub.metadata, 'subbandConfig');
    results = check(results, ok1, ...
        'T1: opts.subband off/on never touches stats/maps/selfCheck (byte-identical)');

    % ---- T2: headline peak ------------------------------------------
    ok2 = abs(withSub.subband.perSubbandPeak_dBmPerMHz - (sectorEirp - bandOff)) <= 1e-9 && ...
          isfield(withSub.subband, 'percentileMaps') && ...
          isequal(size(withSub.subband.percentileMaps.values), ...
                  size(withSub.percentileMaps.values)) && ...
          strcmp(withSub.subband.percentileMaps.units, 'dBm/MHz');
    results = check(results, ok2, sprintf( ...
        'T2: perSubbandPeak == sectorEirp - 10log10(BW) (%.4f dBm/MHz)', ...
        withSub.subband.perSubbandPeak_dBmPerMHz));

    % ---- T3: single-beam reduction ----------------------------------
    oneOpts = baseOpts;
    oneOpts.numBeams = 1;
    oneOpts.subband  = struct();
    oneRun = runR23AasEirpCdfGrid(oneOpts);
    sm = oneRun.subband.stats.max_dBm;
    bm = oneRun.stats.max_dBm;
    finite = isfinite(sm) & isfinite(bm);
    d3 = abs(sm(finite) - (bm(finite) - bandOff));
    ok3 = ~isempty(d3) && max(d3) <= 1e-6;
    results = check(results, ok3, ...
        'T3: single-beam per-subband stats.max == band-integrated max - 10log10(BW)');

    % ---- T4: delta ~ 10log10(N) -------------------------------------
    N = baseOpts.numBeams;
    ok4 = abs(withSub.subband.deltaVsBandIntegrated_dB - 10*log10(N)) <= 0.1 && ...
          abs(withSub.subband.deltaNominal_dB - 10*log10(N)) <= 1e-9;
    results = check(results, ok4, sprintf( ...
        'T4: deltaVsBandIntegrated_dB %.3f ~ 10log10(%d)=%.3f (<=0.1 dB)', ...
        withSub.subband.deltaVsBandIntegrated_dB, N, 10*log10(N)));

    % ---- T5: power-split independence --------------------------------
    % (a) NO-RNG prbWeighting (fixed weights) -> beam directions unchanged,
    %     per-subband ignores the power split -> identical per-subband maps.
    prbOpts = baseOpts;
    prbOpts.subband      = struct();
    prbOpts.prbWeighting = struct('mode', 'fixed', 'weights', [0.6 0.3 0.1]);
    prbRun = runR23AasEirpCdfGrid(prbOpts);
    d5a = abs(prbRun.subband.percentileMaps.values - withSub.subband.percentileMaps.values);
    oka = max(d5a(isfinite(d5a))) <= 1e-9 && ...
          prbRun.metadata.includesPrbWeighting == true;
    % (b) NO-RNG layering (fixed rank 1, spread 0) -> identity expansion ->
    %     directions unchanged -> identical per-subband maps.
    layOpts = baseOpts;
    layOpts.subband  = struct();
    layOpts.layering = struct('rank', 1, 'layerSpreadDeg', 0);
    layRun = runR23AasEirpCdfGrid(layOpts);
    d5b = abs(layRun.subband.percentileMaps.values - withSub.subband.percentileMaps.values);
    okb = max(d5b(isfinite(d5b))) <= 1e-9 && ...
          layRun.metadata.includesLayering == true;
    ok5 = oka && okb;
    results = check(results, ok5, ...
        'T5: per-subband maps independent of prbWeighting / layering power split (no-RNG cfgs)');

    % ---- T6: validity flag ------------------------------------------
    spanOpts = baseOpts;
    spanOpts.subband = struct('subbandMHz', 50);   % > 100/3 = 33.3
    spanRun = runR23AasEirpCdfGrid(spanOpts);
    ok6 = withSub.subband.validity.spansMultipleUeAllocations == false && ...
          spanRun.subband.validity.spansMultipleUeAllocations == true && ...
          abs(spanRun.subband.validity.singleBeamPerSubbandBoundMHz - BW/N) <= 1e-9;
    results = check(results, ok6, ...
        'T6: validity flag set when subbandMHz>BW/N, clear when subbandMHz<=BW/N');

    % ---- T7: combos + error path ------------------------------------
    % subband + epre: epre attaches; adding subband must not perturb a
    % matched epre-only run's stats (subband never touches stats).
    epreOnly = baseOpts; epreOnly.epre = struct('dmrsCdmGroupsNoData', 2);
    epreOnlyRun = runR23AasEirpCdfGrid(epreOnly);
    epreSub = epreOnly; epreSub.subband = struct();
    epreSubRun = runR23AasEirpCdfGrid(epreSub);
    okEpre = isstruct(epreSubRun.subband) && isstruct(epreSubRun.epre) && ...
             isequal(epreSubRun.stats.counts, epreOnlyRun.stats.counts) && ...
             isequaln(epreSubRun.epre.perRePeakEnvelope_dBm, epreOnlyRun.epre.perRePeakEnvelope_dBm);

    % subband + layering: layering reshapes stats; subband must not change
    % the layering-only stats.
    layOnly = baseOpts; layOnly.layering = struct('rank', 2, 'layerSpreadDeg', 1.5);
    layOnlyRun = runR23AasEirpCdfGrid(layOnly);
    laySub = layOnly; laySub.subband = struct();
    laySubRun = runR23AasEirpCdfGrid(laySub);
    okLay = isstruct(laySubRun.subband) && isstruct(laySubRun.layering) && ...
            isequal(laySubRun.stats.counts, layOnlyRun.stats.counts);

    % subband + prbWeighting (random): prbWeighting reshapes stats; subband
    % must not change the prbWeighting-only stats.
    prbOnly = baseOpts; prbOnly.prbWeighting = struct('mode', 'random', 'spread', 0.5);
    prbOnlyRun = runR23AasEirpCdfGrid(prbOnly);
    prbSub = prbOnly; prbSub.subband = struct();
    prbSubRun = runR23AasEirpCdfGrid(prbSub);
    okPrb = isstruct(prbSubRun.subband) && isstruct(prbSubRun.prbWeighting) && ...
            isequal(prbSubRun.stats.counts, prbOnlyRun.stats.counts);

    % subband + ssb: ssb attaches; subband must not change ssb outputs.
    ssbOnly = baseOpts; ssbOnly.ssb = struct();
    ssbOnlyRun = runR23AasEirpCdfGrid(ssbOnly);
    ssbSub = ssbOnly; ssbSub.subband = struct();
    ssbSubRun = runR23AasEirpCdfGrid(ssbSub);
    okSsb = isstruct(ssbSubRun.subband) && isstruct(ssbSubRun.ssb) && ...
            isequaln(ssbSubRun.ssb.envelope_dBm, ssbOnlyRun.ssb.envelope_dBm) && ...
            isequal(ssbSubRun.stats.counts, ssbOnlyRun.stats.counts);

    okErr = throwsId(@() runR23AasEirpCdfGrid(setfield(baseOpts, 'subband', 5)), ...
        'runR23AasEirpCdfGrid:badSubbandOpts');

    ok7 = okEpre && okLay && okPrb && okSsb && okErr;
    results = check(results, ok7, ...
        'T7: subband composes with epre/layering/prbWeighting/ssb; non-struct errors');

    fprintf('\n--- test_runR23AasEirpCdfGrid_subband summary ---\n');
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

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
