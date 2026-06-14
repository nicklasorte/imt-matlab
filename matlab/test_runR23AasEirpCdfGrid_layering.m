function results = test_runR23AasEirpCdfGrid_layering()
%TEST_RUNR23AASEIRPCDFGRID_LAYERING opts.layering rank/MU-MIMO integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_layering()
%
%   Covers the opts.layering wiring on runR23AasEirpCdfGrid:
%       T1.  DEFAULT-OFF invariant: opts.layering = struct('enable',false)
%            (and absent) -> stats / percentileMaps / selfCheck are
%            byte-identical to a no-layering run with the same seed, and
%            out.layering == [] / includesLayering == false.
%       T2.  IDENTITY: opts.layering with rank 1 + layerSpreadDeg 0 ->
%            byte-identical stats / percentileMaps to OFF (zero extra RNG).
%       T3.  Fixed rank r -> realized totalLayers == r*numUesPerSector and
%            realized per-layer peak == sectorEirp - 10*log10(L).
%       T4.  Power conservation / self-check: with layering + spread on, the
%            observed aggregate max stays <= sector peak and the band-
%            integrated self-check does not FAIL.
%       T5.  Clipping: sum(r_u) > maxTotalLayers -> realized totalLayers ==
%            maxTotalLayers and clipCount > 0.
%       T6.  Combos: opts.layering + opts.epre both on, and opts.layering +
%            opts.ssb both on -> each layer still attaches and behaves.
%       T7.  resolveLayeringOpts error path: a non-struct, non-empty
%            opts.layering is rejected with
%            'runR23AasEirpCdfGrid:badLayeringOpts'.
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

    % ---- T1: default-off invariant ----------------------------------
    offOpts = baseOpts;
    offOpts.layering = struct('enable', false);
    offRun = runR23AasEirpCdfGrid(offOpts);
    ok1 = isfield(base, 'layering') && isempty(base.layering) && ...
          isfield(base.metadata, 'includesLayering') && ...
          ~base.metadata.includesLayering && ...
          isempty(offRun.layering) && ~offRun.metadata.includesLayering && ...
          isequal(offRun.stats.counts,           base.stats.counts) && ...
          isequaln(offRun.stats.sum_lin_mW,      base.stats.sum_lin_mW) && ...
          isequaln(offRun.stats.max_dBm,         base.stats.max_dBm) && ...
          isequaln(offRun.percentileMaps.values, base.percentileMaps.values) && ...
          isequaln(offRun.selfCheck,             base.selfCheck);
    results = check(results, ok1, ...
        'T1: opts.layering off -> byte-identical stats/maps/selfCheck, layering==[]');

    % ---- T2: identity expansion (rank 1, spread 0) == OFF -----------
    idOpts = baseOpts;
    idOpts.layering = struct('rank', 1, 'layerSpreadDeg', 0);
    idRun = runR23AasEirpCdfGrid(idOpts);
    ok2 = isequal(idRun.stats.counts,            base.stats.counts) && ...
          isequaln(idRun.stats.sum_lin_mW,       base.stats.sum_lin_mW) && ...
          isequaln(idRun.stats.min_dBm,          base.stats.min_dBm) && ...
          isequaln(idRun.stats.max_dBm,          base.stats.max_dBm) && ...
          isequaln(idRun.percentileMaps.values,  base.percentileMaps.values) && ...
          idRun.metadata.includesLayering == true && ...
          isstruct(idRun.layering) && ...
          idRun.layering.realizedTotalLayers.max == baseOpts.numBeams;
    results = check(results, ok2, ...
        'T2: rank1+spread0 identity -> stats/maps byte-identical to OFF');

    % ---- T3: fixed rank count + per-layer power ---------------------
    r = 2;
    rOpts = baseOpts;
    rOpts.layering = struct('rank', r, 'layerSpreadDeg', 0);
    rRun = runR23AasEirpCdfGrid(rOpts);
    L = r * baseOpts.numBeams;
    expPerLayer = rRun.metadata.sectorEirpDbm - 10 * log10(L);
    ok3 = rRun.layering.realizedTotalLayers.min == L && ...
          rRun.layering.realizedTotalLayers.max == L && ...
          abs(rRun.layering.perLayerPeakEirpDbm.max - expPerLayer) <= 1e-9 && ...
          abs(rRun.layering.perLayerPeakEirpDbm.min - expPerLayer) <= 1e-9 && ...
          rRun.layering.clipCount == 0;
    results = check(results, ok3, sprintf( ...
        'T3: fixed rank %d -> L==%d, perLayer==%.3f dBm', r, L, expPerLayer));

    % ---- T4: power conservation / self-check ------------------------
    spreadOpts = baseOpts;
    spreadOpts.layering = struct('rank', 2, 'layerSpreadDeg', 3);
    spreadRun = runR23AasEirpCdfGrid(spreadOpts);
    sectorPeak = spreadRun.metadata.sectorEirpDbm;
    observedMax = spreadRun.selfCheck.powerSemantics.observedMaxGridEirp_dBm;
    ok4 = observedMax <= sectorPeak + 1e-6 && ...
          ~strcmp(spreadRun.selfCheck.powerSemantics.status, 'fail') && ...
          spreadRun.metadata.includesLayering == true;
    results = check(results, ok4, sprintf( ...
        ['T4: layering+spread power-conserving (observed max %.2f <= sector ', ...
         'peak %.2f) and self-check not FAIL'], observedMax, sectorPeak));

    % ---- T5: clipping to maxTotalLayers -----------------------------
    clipOpts = baseOpts;
    clipOpts.layering = struct('rank', 3, 'maxTotalLayers', 8, 'layerSpreadDeg', 0);
    clipRun = runR23AasEirpCdfGrid(clipOpts);
    ok5 = clipRun.layering.realizedTotalLayers.max == 8 && ...
          clipRun.layering.realizedTotalLayers.min == 8 && ...
          clipRun.layering.clipCount > 0;
    results = check(results, ok5, ...
        'T5: sum(r_u) > maxTotalLayers -> totalLayers==8, clipCount>0');

    % ---- T6: combos with opts.epre and opts.ssb ---------------------
    epreCombo = baseOpts;
    epreCombo.layering = struct('rank', 2, 'layerSpreadDeg', 2);
    epreCombo.epre     = struct('dmrsCdmGroupsNoData', 2);   % 3 dB
    epreRun = runR23AasEirpCdfGrid(epreCombo);
    okEpre = epreRun.metadata.includesLayering == true && ...
             epreRun.metadata.includesEpre == true && ...
             isstruct(epreRun.layering) && isstruct(epreRun.epre) && ...
             isfield(epreRun.epre, 'perRePeakEnvelope_dBm');

    ssbCombo = baseOpts;
    ssbCombo.layering = struct('rank', 2, 'layerSpreadDeg', 2);
    ssbCombo.ssb      = struct();
    ssbRun = runR23AasEirpCdfGrid(ssbCombo);
    okSsb = ssbRun.metadata.includesLayering == true && ...
            ssbRun.metadata.includesSsbSweep == true && ...
            isstruct(ssbRun.layering) && isfield(ssbRun, 'ssb') && ...
            isstruct(ssbRun.ssb) && isfield(ssbRun, 'timeWeighted');
    ok6 = okEpre && okSsb;
    results = check(results, ok6, ...
        'T6: opts.layering + opts.epre and opts.layering + opts.ssb both attach');

    % ---- T7: non-struct opts.layering rejected ----------------------
    badOpts = baseOpts;
    badOpts.layering = 5;   % non-struct, non-empty
    ok7 = throwsId(@() runR23AasEirpCdfGrid(badOpts), ...
        'runR23AasEirpCdfGrid:badLayeringOpts');
    results = check(results, ok7, ...
        'T7: non-struct opts.layering throws runR23AasEirpCdfGrid:badLayeringOpts');

    fprintf('\n--- test_runR23AasEirpCdfGrid_layering summary ---\n');
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
