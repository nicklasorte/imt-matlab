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
%   Covers (base MATLAB only, fast):
%       T1.  Disabled == no-op: with the beamCodebook field absent, [] or
%            enable = false, imtAasArrayFactor output is byte-identical
%            to the historical path.
%       T2.  Nearest == exhaustive: imt_aas_codebook_select in 'nearest'
%            mode returns the same (kH, kV) as the brute-force max-gain
%            'exhaustive' search for a few hundred random panel-frame
%            directions (0 mismatches), i.e. nearest-bin snapping IS the
%            max-gain Type I beam.
%       T3.  On-grid direction -> exact bins + ~zero scan loss; codebook
%            struct sizes / unit-modulus weights sanity.
%       T4.  Worst-case scan loss < 0.5 dB at O = 4 and monotone
%            decreasing over O in {1, 2, 4, 8}.
%       T5.  Quantization within half a bin: |aiQuant - a_i| <= 1/(2*MV)
%            and |biQuant - b_i| <= 1/(2*MH).
%       T6.  Selector matches AF: the selector's scanLossDb equals the
%            actual outer-AF gain drop measured by running
%            imtAasArrayFactor ideal vs codebook at the same direction
%            (max error < 1e-12 dB).
%       T7.  Runner wiring via the flat opts struct: 'ideal' == field
%            omitted (byte-identical stats / percentile maps);
%            'codebook' runs, is deterministic, differs from 'ideal',
%            populates out.metadata.beamSelection / .beamCodebook;
%            flat-opts == name-value invocation; scalar oversample ==
%            [O O]; invalid beamSelection throws the documented id.
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
    results = t7_runner_wiring(results);

    fprintf('\n--- test_imt_aas_codebook summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% Shared small Monte Carlo options (fast).
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
    steerAz = 17;
    steerEl = -7;

    g0 = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, params0);

    pOff = params0;
    pOff.beamCodebook = struct('enable', false);
    gOff = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, pOff);

    pEmpty = params0;
    pEmpty.beamCodebook = [];
    gEmpty = imtAasArrayFactor(azGrid, elGrid, steerAz, steerEl, pEmpty);

    ok = isequal(g0, gOff) && isequal(g0, gEmpty);
    r = check(r, ok, ...
        ['T1: beamCodebook absent / [] / enable=false are byte-identical ' ...
         'to the historical imtAasArrayFactor path']);
end

% =====================================================================
% T2: nearest-bin snapping == exhaustive max-gain search.
% =====================================================================
function r = t2_nearest_equals_exhaustive(r)
    params = imtAasDefaultParams();
    rng(42);
    N = 300;
    azList = -80 + 160 .* rand(N, 1);
    elList = -50 + 100 .* rand(N, 1);

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
% T3: on-grid direction -> exact bins, ~zero loss; codebook struct sanity.
% =====================================================================
function r = t3_on_grid_zero_loss(r)
    params = imtAasDefaultParams();

    cbDesc = imt_aas_dft_codebook(params, struct('returnWeights', true));
    MH = cbDesc.MH;
    MV = cbDesc.MV;
    okCb = MH == 4 * params.numColumns && MV == 4 * params.numRows && ...
           numel(cbDesc.biBins) == MH && numel(cbDesc.aiBins) == MV && ...
           cbDesc.biBins(1) == 0 && cbDesc.aiBins(1) == 0 && ...
           isequal(cbDesc.kHRange, [0, MH - 1]) && ...
           isequal(cbDesc.kVRange, [0, MV - 1]) && ...
           isequal(size(cbDesc.weights), ...
               [params.numColumns * params.numRows, MH, MV]) && ...
           max(abs(abs(cbDesc.weights(:)) - 1)) < 1e-12;

    % Construct a steering direction that lands exactly on bin (kH0, kV0).
    d_H = params.hSpacingWavelengths;
    d_V = params.vSubarraySpacingWavelengths;
    kV0 = 3;
    kH0 = 5;
    el = -asind((kV0 / MV) / d_V);                    % a_i = kV0/MV exactly
    az = asind((kH0 / MH) / (d_H * cosd(-el)));       % b_i = kH0/MH exactly

    sel = imt_aas_codebook_select(az, el, params, struct());
    okSel = sel.kV == kV0 && sel.kH == kH0 && abs(sel.scanLossDb) < 1e-9;
    okEff = abs(sel.effSteerElDeg - el) < 1e-9 && ...
            abs(sel.effSteerAzDeg - az) < 1e-9 && ~sel.isAliased;

    r = check(r, okCb && okSel && okEff, sprintf( ...
        ['T3: on-grid direction maps to exact bins (kH=%d, kV=%d), scan ' ...
         'loss %.3g dB ~ 0, effective pointing recovered; codebook ' ...
         'struct / unit-modulus weights OK'], sel.kH, sel.kV, sel.scanLossDb));
end

% =====================================================================
% T4: scan loss bounded at O=4 and monotone decreasing in O.
% =====================================================================
function r = t4_loss_bounded_and_monotone(r)
    params = imtAasDefaultParams();
    rng(7);
    N = 400;
    azList = -60 + 120 .* rand(N, 1);
    elList = -45 + 90 .* rand(N, 1);

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
    okMonotone = all(diff(maxLoss) < 0);

    r = check(r, okBound && okMonotone && okNonNeg, sprintf( ...
        ['T4: worst-case scan loss at O=4 is %.3f dB (< 0.5) and max ' ...
         'loss is monotone decreasing over O=[1 2 4 8]: ' ...
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
    elList = -40 + 80 .* rand(N, 1);

    maxErr = 0;
    for i = 1:N
        az = azList(i);
        el = elList(i);
        sel = imt_aas_codebook_select(az, el, params, struct());
        % Observe at exactly the requested pointing, panel frame.
        gIdeal = imtAasArrayFactor(az, el, az, el, params);
        gCb    = imtAasArrayFactor(az, el, az, el, pCb);
        measuredLoss = gIdeal - gCb;   % sub-array term cancels
        maxErr = max(maxErr, abs(measuredLoss - sel.scanLossDb));
    end
    r = check(r, maxErr < 1e-12, sprintf( ...
        ['T6: selector scanLossDb matches the measured outer-AF drop ' ...
         'over %d directions (max |err| = %.3g dB < 1e-12)'], N, maxErr));
end

% =====================================================================
% T7: runR23AasEirpCdfGrid wiring via the flat opts struct.
% =====================================================================
function r = t7_runner_wiring(r)
    base = mcOpts();

    outOmit = runR23AasEirpCdfGrid(base);

    optI = base;
    optI.beamSelection = 'ideal';
    outIdeal = runR23AasEirpCdfGrid(optI);

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
    okCbRuns = isstruct(outCb1.percentileMaps) && ~isempty(v) && ...
               any(isfinite(v(:)));
    okCbDeterministic = isequaln(v, outCb2.percentileMaps.values) && ...
                        isequal(outCb1.stats.counts, outCb2.stats.counts);
    okCbDiffers = ~isequal(outCb1.stats.sum_lin_mW, outOmit.stats.sum_lin_mW);

    okMetaIdeal = isfield(outOmit.metadata, 'beamSelection') && ...
                  strcmp(outOmit.metadata.beamSelection, 'ideal') && ...
                  isfield(outOmit.metadata, 'beamCodebook') && ...
                  isstruct(outOmit.metadata.beamCodebook) && ...
                  ~outOmit.metadata.beamCodebook.enable;
    okMetaCb = strcmp(outCb1.metadata.beamSelection, 'codebook') && ...
               outCb1.metadata.beamCodebook.enable && ...
               outCb1.metadata.beamCodebook.oversampleH == 4 && ...
               outCb1.metadata.beamCodebook.oversampleV == 4;

    % Flat-opts call must be bit-equivalent to the name-value call.
    flds = fieldnames(optC);
    nv = cell(1, 2 * numel(flds));
    for k = 1:numel(flds)
        nv{2*k - 1} = flds{k};
        nv{2*k}     = optC.(flds{k});
    end
    outNv = runR23AasEirpCdfGrid(nv{:});
    okNvEquiv = isequaln(outNv.percentileMaps.values, v) && ...
                isequal(outNv.stats.counts, outCb1.stats.counts);

    % Scalar oversample == [O O].
    optS = optC;
    optS.codebookOversample = 4;
    outS = runR23AasEirpCdfGrid(optS);
    okScalarOversample = isequal(outS.stats.counts, outCb1.stats.counts) && ...
                         isequal(outS.stats.sum_lin_mW, outCb1.stats.sum_lin_mW);

    % Invalid beamSelection throws the documented identifier.
    optBad = base;
    optBad.beamSelection = 'bogus';
    threw   = false;
    rightId = false;
    try
        runR23AasEirpCdfGrid(optBad);
    catch err
        threw   = true;
        rightId = strcmp(err.identifier, ...
            'runR23AasEirpCdfGrid:invalidBeamSelection');
    end

    ok = okIdealNoop && okCbRuns && okCbDeterministic && okCbDiffers && ...
         okMetaIdeal && okMetaCb && okNvEquiv && okScalarOversample && ...
         threw && rightId;
    r = check(r, ok, sprintf( ...
        ['T7: runner wiring (idealNoop=%d cbRuns=%d deterministic=%d ' ...
         'differsFromIdeal=%d metaIdeal=%d metaCb=%d nvEquiv=%d ' ...
         'scalarOversample=%d invalidIdThrows=%d)'], ...
        okIdealNoop, okCbRuns, okCbDeterministic, okCbDiffers, ...
        okMetaIdeal, okMetaCb, okNvEquiv, okScalarOversample, ...
        threw && rightId));
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
