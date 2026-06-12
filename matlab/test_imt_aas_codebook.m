function results = test_imt_aas_codebook()
%TEST_IMT_AAS_CODEBOOK Self tests for the Type I DFT/PMI codebook option.
%
%   RESULTS = test_imt_aas_codebook()
%
%   Exercises the non-breaking 3GPP TS 38.214 v19.2.0 Sec. 5.2.2.2.1
%   Type I single-panel DFT (PMI) beam-selection option added to the AAS
%   EIRP pipeline (imt_aas_dft_codebook, imt_aas_codebook_select, the
%   imtAasArrayFactor quantization hook, and the runR23AasEirpCdfGrid
%   opts.beamSelection / opts.codebookOversample plumbing).
%
%   Covers (base MATLAB only, fast; fixed seeds throughout):
%       T1.  Disabled == no-op: with the beamCodebook field absent, [] or
%            enable = false, imtAasArrayFactor output is byte-identical
%            (isequal) to the historical path.
%       T2.  Nearest == exhaustive: imt_aas_codebook_select in 'nearest'
%            mode returns the same (kH, kV) as the brute-force max-gain
%            'exhaustive' search for several hundred random panel-frame
%            directions (0 mismatches), i.e. nearest-bin snapping IS the
%            max-gain Type I beam.
%       T3.  On-grid direction -> exact (kH, kV) bins and ~zero scan loss.
%       T4.  Worst-case scan loss < 0.5 dB at O = 4 and strictly monotone
%            decreasing over O in {1, 2, 4, 8}.
%       T5.  Quantization within half a bin: |aiQuant - a_i| <= 1/(2*MV)
%            and |biQuant - b_i| <= 1/(2*MH).
%       T6.  Selector matches AF: the selector's scanLossDb equals the
%            actual outer-AF gain drop measured by running
%            imtAasArrayFactor ideal vs codebook at the same direction
%            (max error < 1e-12 dB).
%       T7.  imt_aas_dft_codebook grid shape: MH = O_H*N_H, MV = O_V*N_V,
%            numel(biBins) = MH, numel(aiBins) = MV, biBins/aiBins equal
%            (0:M-1)/M; checked for default [4 4] and non-default [2 3];
%            unit-modulus weights sanity.
%       T8.  Runner wiring via the flat opts struct: 'ideal' == field
%            omitted (byte-identical stats / percentile maps); 'codebook'
%            runs (finite), is deterministic, differs from 'ideal', and
%            populates out.metadata.beamSelection / .beamCodebook.
%       T9.  Flat-opts == name-value invocation, and scalar oversample ==
%            [O O] (both isequal on the computed outputs).
%       T10. Invalid inputs error cleanly: bad beamSelection throws
%            runR23AasEirpCdfGrid:invalidBeamSelection; a 3-element
%            oversample throws runR23AasEirpCdfGrid:invalidCodebookOversample;
%            non-integer / zero oversample throws.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t1_disabled_is_noop(results);
    results = t2_nearest_equals_exhaustive(results);
    results = t3_on_grid_zero_loss(results);
    results = t4_loss_bounded_and_monotone(results);
    results = t5_quantization_within_half_bin(results);
    results = t6_selector_matches_array_factor(results);
    results = t7_dft_codebook_grid_shape(results);
    results = t8_runner_wiring(results);
    results = t9_flat_opts_and_scalar_oversample(results);
    results = t10_invalid_inputs_error(results);

    fprintf('\n--- test_imt_aas_codebook summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% Shared small Monte Carlo options (fast, fixed seed).
% =====================================================================
function opts = mcOpts()
    opts = struct();
    opts.numMc       = 16;
    opts.seed        = 11;
    opts.azGridDeg   = -60:10:60;     % 13
    opts.elGridDeg   = -20:4:8;       % 8
    opts.binEdgesDbm = -120:1:120;
    opts.percentiles = [5 50 95];
end

% =====================================================================
% T1: disabled codebook is a byte-identical no-op on imtAasArrayFactor.
% =====================================================================
function r = t1_disabled_is_noop(r)
    params0 = imtAasDefaultParams();   % no beamCodebook field (historical)
    azGrid = -120:5:120;
    elGrid = -30:1.5:30;

    % A few steering / observation directions.
    steers = [ 17 -7;  -33 12;  0 0;  55 -20 ];

    ok = true;
    for s = 1:size(steers, 1)
        steerAz = steers(s, 1);
        steerEl = steers(s, 2);

        g0 = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, params0);

        pOff = params0;
        pOff.beamCodebook = struct('enable', false);
        gOff = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, pOff);

        pEmpty = params0;
        pEmpty.beamCodebook = [];
        gEmpty = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, pEmpty);

        ok = ok && isequal(g0, gOff) && isequal(g0, gEmpty);
    end

    r = check(r, ok, ...
        ['T1: beamCodebook absent / [] / enable=false are byte-identical ' ...
         '(isequal) to the historical imtAasArrayFactor path']);
end

% =====================================================================
% T2: nearest-bin snapping == exhaustive max-gain search.
% =====================================================================
function r = t2_nearest_equals_exhaustive(r)
    params = imtAasDefaultParams();
    rng(42);
    N = 400;
    azList = -60 + 120 .* rand(N, 1);   % steerAz in [-60, 60]
    elList = -30 +  60 .* rand(N, 1);   % steerEl in [-30, 30]

    mismatches = 0;
    for i = 1:N
        sN = imt_aas_codebook_select(azList(i), elList(i), params, ...
            struct('mode', 'nearest'));
        sE = imt_aas_codebook_select(azList(i), elList(i), params, ...
            struct('mode', 'exhaustive'));
        if sN.kH ~= sE.kH || sN.kV ~= sE.kV
            mismatches = mismatches + 1;
        end
    end
    r = check(r, mismatches == 0, sprintf( ...
        ['T2: nearest == exhaustive max-gain (kH, kV) over %d random ' ...
         'panel-frame directions (%d mismatches)'], N, mismatches));
end

% =====================================================================
% T3: on-grid direction -> exact bins, ~zero scan loss.
% =====================================================================
function r = t3_on_grid_zero_loss(r)
    params = imtAasDefaultParams();
    cb = imt_aas_dft_codebook(params, struct());
    MH = cb.MH;
    MV = cb.MV;
    d_H = params.hSpacingWavelengths;
    d_V = params.vSubarraySpacingWavelengths;

    % Construct a steering direction that lands exactly on bin (kH0, kV0):
    %   a_i = d_V*sin(-el) = kV0/MV  ->  el = -asind((kV0/MV)/d_V)
    %   b_i = d_H*cos(-el)*sin(az) = kH0/MH  ->  az = asind((kH0/MH)/(d_H*cos(-el)))
    kV0 = 3;
    kH0 = 5;
    el = -asind((kV0 / MV) / d_V);
    az =  asind((kH0 / MH) / (d_H * cosd(-el)));

    sel = imt_aas_codebook_select(az, el, params, struct());
    okBins = sel.kV == kV0 && sel.kH == kH0;
    okLoss = abs(sel.scanLossDb) < 1e-9;
    okEff  = abs(sel.effSteerElDeg - el) < 1e-9 && ...
             abs(sel.effSteerAzDeg - az) < 1e-9 && ~sel.isAliased;

    r = check(r, okBins && okLoss && okEff, sprintf( ...
        ['T3: on-grid direction maps to exact bins (kH=%d, kV=%d), scan ' ...
         'loss %.3g dB ~ 0, effective pointing recovered'], ...
        sel.kH, sel.kV, sel.scanLossDb));
end

% =====================================================================
% T4: scan loss bounded at O=4 and strictly monotone decreasing in O.
% =====================================================================
function r = t4_loss_bounded_and_monotone(r)
    params = imtAasDefaultParams();
    rng(7);
    N = 400;
    azList = -60 + 120 .* rand(N, 1);
    elList = -30 +  60 .* rand(N, 1);

    oList    = [1 2 4 8];
    maxLoss  = zeros(size(oList));
    meanLoss = zeros(size(oList));
    okNonNeg = true;
    for k = 1:numel(oList)
        o = oList(k);
        losses = zeros(N, 1);
        for i = 1:N
            sel = imt_aas_codebook_select(azList(i), elList(i), params, ...
                struct('oversampleH', o, 'oversampleV', o));
            losses(i) = sel.scanLossDb;
        end
        okNonNeg    = okNonNeg && all(losses > -1e-9);
        maxLoss(k)  = max(losses);
        meanLoss(k) = mean(losses);
    end

    okBound    = maxLoss(oList == 4) < 0.5;
    okMonotone = all(diff(maxLoss) < 0);   % w(1) > w(2) > w(4) > w(8)

    r = check(r, okBound && okMonotone && okNonNeg, sprintf( ...
        ['T4: worst-case scan loss at O=4 is %.3f dB (< 0.5) and max ' ...
         'loss is strictly decreasing over O=[1 2 4 8]: ' ...
         '[%.2f %.2f %.2f %.2f] dB (mean at O=4: %.3f dB)'], ...
        maxLoss(oList == 4), maxLoss(1), maxLoss(2), maxLoss(3), ...
        maxLoss(4), meanLoss(oList == 4)));
end

% =====================================================================
% T5: quantized frequencies within half a DFT bin of the ideal ones.
% =====================================================================
function r = t5_quantization_within_half_bin(r)
    params = imtAasDefaultParams();
    rng(21);
    N = 300;
    azList = -90 + 180 .* rand(N, 1);
    elList = -90 + 180 .* rand(N, 1);   % full range, incl. aliased region

    ok = true;
    worstFracA = 0;   % |aiQuant - a_i| as a fraction of half a bin
    worstFracB = 0;
    for i = 1:N
        sel = imt_aas_codebook_select(azList(i), elList(i), params, struct());
        dA = abs(sel.aiQuant - sel.aiIdeal);
        dB = abs(sel.biQuant - sel.biIdeal);
        worstFracA = max(worstFracA, dA * 2 * sel.MV);
        worstFracB = max(worstFracB, dB * 2 * sel.MH);
        if dA > 1 / (2 * sel.MV) + 1e-12 || dB > 1 / (2 * sel.MH) + 1e-12
            ok = false;
        end
    end
    r = check(r, ok, sprintf( ...
        ['T5: |aiQuant - a_i| <= 1/(2*MV) and |biQuant - b_i| <= 1/(2*MH) ' ...
         'over %d directions (worst: %.3f / %.3f of half a bin)'], ...
        N, worstFracA, worstFracB));
end

% =====================================================================
% T6: selector scanLossDb == measured imtAasArrayFactor ideal-vs-codebook
%     gain drop at the same panel-frame direction.
% =====================================================================
function r = t6_selector_matches_array_factor(r)
    params = imtAasDefaultParams();   % rho = 1
    pCb = params;
    pCb.beamCodebook = struct('enable', true, ...
                              'oversampleH', 4, 'oversampleV', 4);
    rng(11);
    N = 60;
    azList = -60 + 120 .* rand(N, 1);
    elList = -40 +  80 .* rand(N, 1);

    maxErr = 0;
    for i = 1:N
        az = azList(i);
        el = elList(i);
        sel = imt_aas_codebook_select(az, el, params, struct());
        % Observe at exactly the requested pointing, panel frame.
        gIdeal = imtAasArrayFactor(az, el, az, el, params);
        gCb    = imtAasArrayFactor(az, el, az, el, pCb);
        measuredLoss = gIdeal - gCb;   % sub-array / element terms cancel
        maxErr = max(maxErr, abs(measuredLoss - sel.scanLossDb));
    end
    r = check(r, maxErr < 1e-12, sprintf( ...
        ['T6: selector scanLossDb matches the measured outer-AF drop ' ...
         'over %d directions (max |err| = %.3g dB < 1e-12)'], N, maxErr));
end

% =====================================================================
% T7: imt_aas_dft_codebook grid shape (default [4 4] and non-default [2 3]).
% =====================================================================
function r = t7_dft_codebook_grid_shape(r)
    params = imtAasDefaultParams();
    N_H = params.numColumns;
    N_V = params.numRows;

    % --- default O = [4 4], with weights for the unit-modulus sanity check.
    cbA = imt_aas_dft_codebook(params, struct('returnWeights', true));
    O_HA = 4; O_VA = 4;
    okA = cbA.MH == O_HA * N_H && cbA.MV == O_VA * N_V && ...
          numel(cbA.biBins) == cbA.MH && numel(cbA.aiBins) == cbA.MV && ...
          max(abs(cbA.biBins - (0:(cbA.MH - 1)) ./ cbA.MH)) < 1e-12 && ...
          max(abs(cbA.aiBins - (0:(cbA.MV - 1)) ./ cbA.MV)) < 1e-12 && ...
          isequal(cbA.kHRange, [0, cbA.MH - 1]) && ...
          isequal(cbA.kVRange, [0, cbA.MV - 1]) && ...
          isequal(size(cbA.weights), [N_H * N_V, cbA.MH, cbA.MV]) && ...
          max(abs(abs(cbA.weights(:)) - 1)) < 1e-12;

    % --- non-default O_H = 2, O_V = 3.
    O_HB = 2; O_VB = 3;
    cbB = imt_aas_dft_codebook(params, ...
        struct('oversampleH', O_HB, 'oversampleV', O_VB));
    okB = cbB.MH == O_HB * N_H && cbB.MV == O_VB * N_V && ...
          numel(cbB.biBins) == cbB.MH && numel(cbB.aiBins) == cbB.MV && ...
          max(abs(cbB.biBins - (0:(cbB.MH - 1)) ./ cbB.MH)) < 1e-12 && ...
          max(abs(cbB.aiBins - (0:(cbB.MV - 1)) ./ cbB.MV)) < 1e-12;

    r = check(r, okA && okB, sprintf( ...
        ['T7: dft codebook grid shape OK for [4 4] (MH=%d MV=%d) and ' ...
         '[2 3] (MH=%d MV=%d); biBins/aiBins = (0:M-1)/M; weights ' ...
         'unit-modulus'], cbA.MH, cbA.MV, cbB.MH, cbB.MV));
end

% =====================================================================
% T8: runR23AasEirpCdfGrid wiring via the flat opts struct.
% =====================================================================
function r = t8_runner_wiring(r)
    base = mcOpts();

    outOmit = runR23AasEirpCdfGrid(base);

    optI = base;
    optI.beamSelection = 'ideal';
    outIdeal = runR23AasEirpCdfGrid(optI);

    % 'ideal' == field omitted: byte-identical streaming stats + maps.
    okIdealNoop = isequal(outOmit.stats.counts,     outIdeal.stats.counts) && ...
                  isequal(outOmit.stats.sum_lin_mW, outIdeal.stats.sum_lin_mW) && ...
                  isequal(outOmit.stats.min_dBm,    outIdeal.stats.min_dBm) && ...
                  isequal(outOmit.stats.max_dBm,    outIdeal.stats.max_dBm) && ...
                  isequaln(outOmit.percentileMaps.values, ...
                           outIdeal.percentileMaps.values);

    optC = base;
    optC.beamSelection      = 'codebook';
    optC.codebookOversample = [4 4];
    outCb1 = runR23AasEirpCdfGrid(optC);
    outCb2 = runR23AasEirpCdfGrid(optC);

    v = outCb1.percentileMaps.values;
    % Finite output: real values present, never +/-Inf (NaN is the
    % documented empty-cell sentinel from eirp_percentile_maps and is
    % allowed on this tiny grid where deep-null cells can fall below the
    % bin floor).
    okCbRuns = isstruct(outCb1.percentileMaps) && ~isempty(v) && ...
               any(isfinite(v(:))) && ~any(isinf(v(:)));
    okCbDeterministic = isequaln(v, outCb2.percentileMaps.values) && ...
                        isequal(outCb1.stats.counts, outCb2.stats.counts);
    okCbDiffers = ~isequal(outCb1.stats.sum_lin_mW, outOmit.stats.sum_lin_mW);

    % Metadata is additive (beside outputFrame): beamSelection / beamCodebook.
    okMetaIdeal = isfield(outOmit.metadata, 'beamSelection') && ...
                  strcmp(outOmit.metadata.beamSelection, 'ideal') && ...
                  isfield(outOmit.metadata, 'beamCodebook') && ...
                  isstruct(outOmit.metadata.beamCodebook) && ...
                  ~outOmit.metadata.beamCodebook.enable;
    okMetaCb = strcmp(outCb1.metadata.beamSelection, 'codebook') && ...
               outCb1.metadata.beamCodebook.enable && ...
               outCb1.metadata.beamCodebook.oversampleH == 4 && ...
               outCb1.metadata.beamCodebook.oversampleV == 4;

    ok = okIdealNoop && okCbRuns && okCbDeterministic && okCbDiffers && ...
         okMetaIdeal && okMetaCb;
    r = check(r, ok, sprintf( ...
        ['T8: runner wiring (idealNoop=%d cbRunsFinite=%d deterministic=%d ' ...
         'differsFromIdeal=%d metaIdeal=%d metaCb=%d)'], ...
        okIdealNoop, okCbRuns, okCbDeterministic, okCbDiffers, ...
        okMetaIdeal, okMetaCb));
end

% =====================================================================
% T9: flat-opts == name-value, and scalar oversample == [O O].
% =====================================================================
function r = t9_flat_opts_and_scalar_oversample(r)
    base = mcOpts();

    optC = base;
    optC.beamSelection      = 'codebook';
    optC.codebookOversample = [4 4];
    outCb = runR23AasEirpCdfGrid(optC);
    v = outCb.percentileMaps.values;

    % Flat-opts call must be bit-equivalent to the name-value call carrying
    % the same fields.
    flds = fieldnames(optC);
    nv = cell(1, 2 * numel(flds));
    for k = 1:numel(flds)
        nv{2*k - 1} = flds{k};
        nv{2*k}     = optC.(flds{k});
    end
    outNv = runR23AasEirpCdfGrid(nv{:});
    okNvEquiv = isequaln(outNv.percentileMaps.values, v) && ...
                isequal(outNv.stats.counts, outCb.stats.counts);

    % Scalar oversample == [O O].
    optS = optC;
    optS.codebookOversample = 4;
    outS = runR23AasEirpCdfGrid(optS);
    okScalarOversample = isequaln(outS.percentileMaps.values, v) && ...
                         isequal(outS.stats.counts,     outCb.stats.counts) && ...
                         isequal(outS.stats.sum_lin_mW, outCb.stats.sum_lin_mW);

    r = check(r, okNvEquiv && okScalarOversample, sprintf( ...
        ['T9: flat-opts == name-value (nvEquiv=%d) and scalar oversample ' ...
         '== [O O] (scalarOversample=%d)'], okNvEquiv, okScalarOversample));
end

% =====================================================================
% T10: invalid inputs error cleanly with the documented identifiers.
% =====================================================================
function r = t10_invalid_inputs_error(r)
    base = mcOpts();

    % --- bad beamSelection string.
    optBad = base;
    optBad.beamSelection = 'bogus';
    okBadSel = throwsId(@() runR23AasEirpCdfGrid(optBad), ...
        'runR23AasEirpCdfGrid:invalidBeamSelection');

    % --- 3-element oversample.
    optLen = base;
    optLen.beamSelection      = 'codebook';
    optLen.codebookOversample = [1 2 3];
    okBadLen = throwsId(@() runR23AasEirpCdfGrid(optLen), ...
        'runR23AasEirpCdfGrid:invalidCodebookOversample');

    % --- non-integer oversample (with codebook enabled).
    optFrac = base;
    optFrac.beamSelection      = 'codebook';
    optFrac.codebookOversample = 2.5;
    okFrac = throwsAny(@() runR23AasEirpCdfGrid(optFrac));

    % --- zero oversample (with codebook enabled).
    optZero = base;
    optZero.beamSelection      = 'codebook';
    optZero.codebookOversample = 0;
    okZero = throwsAny(@() runR23AasEirpCdfGrid(optZero));

    ok = okBadSel && okBadLen && okFrac && okZero;
    r = check(r, ok, sprintf( ...
        ['T10: invalid inputs throw (badBeamSelection=%d 3-elemOversample=%d ' ...
         'nonInteger=%d zero=%d)'], okBadSel, okBadLen, okFrac, okZero));
end

% =====================================================================
% Helpers
% =====================================================================
function tf = throwsId(fn, id)
%THROWSID True when FN errors with the exact MException identifier ID.
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end

function tf = throwsAny(fn)
%THROWSANY True when FN errors at all (any identifier).
    tf = false;
    try
        fn();
    catch
        tf = true;
    end
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
