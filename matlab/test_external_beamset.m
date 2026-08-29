function results = test_external_beamset()
%TEST_EXTERNAL_BEAMSET External PMI/codebook beam-set option tests.
%
%   RESULTS = test_external_beamset()
%
%   Covers opts.beamSelection = 'external' end to end:
%       T1.  Back-compat: omitting the new fields is isequal() to the
%            pre-change baseline on percentileMaps.values (and the
%            'ideal'/'codebook' paths are unchanged).
%       T2.  A valid fixture runs and returns non-empty percentileMaps.
%       T3.  Determinism: same seed + same file -> identical values.
%       T4.  Metadata round-trip: beamSelection / externalBeamFile /
%            externalBeamsetChecksum / numExternalBeams all populated.
%       T5.  Loader error identifiers.
%       T6.  imtAasExternalBeamGain error identifiers + selection rules.
%       T7.  imtAasCompositeGain external branch + conflict error.
%       T8.  Runner error identifiers.
%       T9.  Works with BOTH outputFrame='global' and 'panel'.
%       T10. 'internal' alias normalizes to 'ideal'.
%       T11. Nothing is shape-hardcoded: loader + gain lookup work on
%            beam sets with DIFFERENT beam counts and grid sizes.
%       T12. Beam-coverage diagnostic is present, correct, and passive.
%
%   All fixtures are SMALL synthetic MAT files built under tempname and
%   removed via onCleanup. This test never touches the proprietary PMI
%   files and adds no measurable time to the suite.
%
%   Base MATLAB only.
%
%   See also imtAasLoadExternalBeamset, imtAasExternalBeamGain,
%   imtAasCompositeGain, runR23AasEirpCdfGrid.

    % run_all_tests expects a SCALAR struct with a .passed field, so the
    % per-check list is kept internal and collapsed into a summary below.
    checks = struct('name', {}, 'passed', {}, 'message', {});

    tmpDir = [tempname '_extbeamset'];
    mkdir(tmpDir);
    cleaner = onCleanup(@() rmdirSafe(tmpDir));

    fx = struct();
    fx.good      = fullfile(tmpDir, 'good_beamset.mat');
    fx.nan       = fullfile(tmpDir, 'nan_beamset.mat');
    fx.badAxis   = fullfile(tmpDir, 'badaxis_beamset.mat');
    fx.badDims   = fullfile(tmpDir, 'baddims_beamset.mat');
    fx.unknown   = fullfile(tmpDir, 'unknown_layout.mat');
    fx.badMeta   = fullfile(tmpDir, 'badmeta_beamset.mat');
    fx.badEnv    = fullfile(tmpDir, 'badenv_beamset.mat');
    fx.geomBad   = fullfile(tmpDir, 'geommismatch_beamset.mat');
    fx.weights   = fullfile(tmpDir, 'weights_beamset.mat');

    writeGoodFixture(fx.good);
    writeVariantFixture(fx.nan,     'nan');
    writeVariantFixture(fx.badAxis, 'badaxis');
    writeVariantFixture(fx.badDims, 'baddims');
    writeVariantFixture(fx.badMeta, 'badmeta');
    writeVariantFixture(fx.badEnv,  'badenv');
    writeVariantFixture(fx.geomBad, 'geombad');
    writeUnknownLayout(fx.unknown);
    writeWeightsFixture(fx.weights);

    fprintf('\n--- test_external_beamset ---\n');
    checks = t1_backcompat(checks);
    checks = t2_runs(checks, fx);
    checks = t3_determinism(checks, fx);
    checks = t4_metadata(checks, fx);
    checks = t5_loader_errors(checks, fx);
    checks = t6_gain_errors(checks, fx);
    checks = t7_composite(checks, fx);
    checks = t8_runner_errors(checks, fx);
    checks = t9_frames(checks, fx);
    checks = t10_internal_alias(checks, fx);
    checks = t11_multi_shape(checks, tmpDir);
    checks = t12_coverage(checks, fx);

    nPass = sum([checks.passed]);
    nTot  = numel(checks);
    fprintf('--- test_external_beamset summary: %d/%d passed ---\n', nPass, nTot);
    if nPass == nTot
        fprintf('  ALL TESTS PASSED\n');
    end

    results = struct( ...
        'name',       'test_external_beamset', ...
        'passed',     nPass == nTot, ...
        'skipped',    false, ...
        'numChecks',  nTot, ...
        'numPassed',  nPass, ...
        'message',    sprintf('%d/%d checks passed', nPass, nTot), ...
        'checks',     checks);
end

% =====================================================================
% T1 - back-compat
% =====================================================================
function r = t1_backcompat(r)
    o = mcOpts();

    outA = runR23AasEirpCdfGrid(o);
    outB = runR23AasEirpCdfGrid(o);
    okRepeat = isequal(outA.percentileMaps.values, outB.percentileMaps.values);

    % The default beamSelection string is an existing regression pin.
    okIdeal = strcmp(outA.metadata.beamSelection, 'ideal');

    % Explicit 'ideal' must equal omitting the field entirely.
    oIdeal = o; oIdeal.beamSelection = 'ideal';
    outI = runR23AasEirpCdfGrid(oIdeal);
    okExplicit = isequal(outA.percentileMaps.values, outI.percentileMaps.values);

    % The codebook path must be untouched by this change.
    oCb = o; oCb.beamSelection = 'codebook';
    outC = runR23AasEirpCdfGrid(oCb);
    okCb = strcmp(outC.metadata.beamSelection, 'codebook') && ...
           ~isequal(outC.percentileMaps.values, outA.percentileMaps.values);

    % The additive metadata fields must be inert when external is off.
    okInert = isfield(outA.metadata, 'externalBeamFile') && ...
              isempty(outA.metadata.externalBeamFile) && ...
              outA.metadata.numExternalBeams == 0 && ...
              isempty(outA.metadata.externalBeamset);

    ok = okRepeat && okIdeal && okExplicit && okCb && okInert;
    r = check(r, ok, sprintf(['T1: back-compat (repeat=%d idealPin=%d ' ...
        'explicit==omitted=%d codebookIntact=%d inertMeta=%d)'], ...
        okRepeat, okIdeal, okExplicit, okCb, okInert));
end

% =====================================================================
% T2 - external run works
% =====================================================================
function r = t2_runs(r, fx)
    o = mcOpts();
    o.beamSelection    = 'external';
    o.externalBeamFile = fx.good;
    out = runR23AasEirpCdfGrid(o);

    v = out.percentileMaps.values;
    ok = ~isempty(v) && all(isfinite(v(:)) | isinf(v(:))) && ~all(isnan(v(:)));
    okSize = isequal(size(v, 1), numel(o.azGridDeg)) && ...
             isequal(size(v, 2), numel(o.elGridDeg));
    okDiff = ~isequal(v, runR23AasEirpCdfGrid(mcOpts()).percentileMaps.values);

    r = check(r, ok && okSize && okDiff, sprintf( ...
        ['T2: external run non-empty (nonEmpty=%d size=%d differsFromIdeal=%d ' ...
         'max=%.3f dBm)'], ok, okSize, okDiff, max(v(isfinite(v)))));
end

% =====================================================================
% T3 - determinism
% =====================================================================
function r = t3_determinism(r, fx)
    o = mcOpts();
    o.beamSelection    = 'external';
    o.externalBeamFile = fx.good;
    o.seed             = 4242;
    out1 = runR23AasEirpCdfGrid(o);
    out2 = runR23AasEirpCdfGrid(o);

    okVals = isequal(out1.percentileMaps.values, out2.percentileMaps.values);

    % stats carries wall-clock (elapsedSeconds) and a params copy whose
    % beam-set descriptor records load timing, so compare the numeric
    % aggregates rather than the whole struct.
    s1 = rmfield(out1.stats, intersect({'elapsedSeconds', 'params'}, ...
        fieldnames(out1.stats)));
    s2 = rmfield(out2.stats, intersect({'elapsedSeconds', 'params'}, ...
        fieldnames(out2.stats)));
    okStats = isequal(s1, s2);

    % The exported params must never carry the beam tensor.
    okLight = ~isfield(out1.params.externalBeamset, 'gainDbi') && ...
              out1.params.externalBeamset.tensorOmitted;

    ok = okVals && okStats && okLight;
    r = check(r, ok, sprintf(['T3: same seed + same file -> identical ' ...
        '(values=%d stats=%d tensorNotExported=%d)'], okVals, okStats, okLight));
end

% =====================================================================
% T4 - metadata round-trip
% =====================================================================
function r = t4_metadata(r, fx)
    o = mcOpts();
    o.beamSelection    = 'external';
    o.externalBeamFile = fx.good;
    out = runR23AasEirpCdfGrid(o);
    m = out.metadata;

    okSel   = strcmp(m.beamSelection, 'external');
    okFile  = strcmp(m.externalBeamFile, fx.good);
    okSum   = ischar(m.externalBeamsetChecksum) && ...
              numel(m.externalBeamsetChecksum) == 32;
    okN     = m.numExternalBeams == 8;
    okLight = isstruct(m.externalBeamset) && ...
              ~isfield(m.externalBeamset, 'gainDbi') && ...
              ~isfield(m.externalBeamset, 'beams');
    okNote  = isfield(m.externalBeamset, 'notes') && ...
              ~isempty(strfind(m.externalBeamset.notes, 'PANEL-FRAME'));

    ok = okSel && okFile && okSum && okN && okLight && okNote;
    r = check(r, ok, sprintf(['T4: metadata round-trip (sel=%d file=%d ' ...
        'checksum=%d numBeams=%d lightweight=%d frameNote=%d)'], ...
        okSel, okFile, okSum, okN, okLight, okNote));
end

% =====================================================================
% T5 - loader error identifiers
% =====================================================================
function r = t5_loader_errors(r, fx)
    missing = fullfile(tempdir, 'definitely_not_here_9f3a2b.mat');

    ok1 = throwsId(@() imtAasLoadExternalBeamset(), ...
        'imtAasLoadExternalBeamset:notEnoughInputs');
    ok2 = throwsId(@() imtAasLoadExternalBeamset(42), ...
        'imtAasLoadExternalBeamset:invalidPath');
    ok3 = throwsId(@() imtAasLoadExternalBeamset(missing), ...
        'imtAasLoadExternalBeamset:fileNotFound');
    ok4 = throwsId(@() imtAasLoadExternalBeamset(fx.good, 'nope'), ...
        'imtAasLoadExternalBeamset:invalidOpts');
    ok5 = throwsId(@() imtAasLoadExternalBeamset(fx.unknown), ...
        'imtAasLoadExternalBeamset:unknownLayout');
    ok6 = throwsId(@() imtAasLoadExternalBeamset(fx.nan), ...
        'imtAasLoadExternalBeamset:nonFiniteData');
    ok7 = throwsId(@() imtAasLoadExternalBeamset(fx.badAxis), ...
        'imtAasLoadExternalBeamset:invalidAxis');
    ok8 = throwsId(@() imtAasLoadExternalBeamset(fx.badDims), ...
        'imtAasLoadExternalBeamset:invalidDimensions');
    ok9 = throwsId(@() imtAasLoadExternalBeamset(fx.badMeta), ...
        'imtAasLoadExternalBeamset:invalidMetadata');
    ok10 = throwsId(@() imtAasLoadExternalBeamset(fx.badEnv), ...
        'imtAasLoadExternalBeamset:envelopeMismatch');
    ok11 = throwsId(@() imtAasLoadExternalBeamset(fx.geomBad, ...
        struct('geometry', aasGeometryPreset('r23_1x3_default'))), ...
        'imtAasLoadExternalBeamset:geometryMismatch');
    ok12 = throwsId(@() imtAasLoadExternalBeamset(fx.weights, ...
        struct('geometry', aasGeometryPreset('r23_1x3_default'))), ...
        'imtAasLoadExternalBeamset:elementCountMismatch');

    ok = ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7 && ok8 && ok9 && ...
         ok10 && ok11 && ok12;
    r = check(r, ok, sprintf(['T5: loader error ids (notEnough=%d path=%d ' ...
        'notFound=%d opts=%d unknown=%d nonFinite=%d axis=%d dims=%d ' ...
        'meta=%d envelope=%d geom=%d elemCount=%d)'], ...
        ok1, ok2, ok3, ok4, ok5, ok6, ok7, ok8, ok9, ok10, ok11, ok12));
end

% =====================================================================
% T6 - gain function
% =====================================================================
function r = t6_gain_errors(r, fx)
    bs = imtAasLoadExternalBeamset(fx.good);

    okFew  = throwsId(@() imtAasExternalBeamGain(0, 0, 0), ...
        'imtAasExternalBeamGain:notEnoughInputs');
    okBs   = throwsId(@() imtAasExternalBeamGain(0, 0, 0, 0, 'nope'), ...
        'imtAasExternalBeamGain:invalidBeamset');
    okMode = throwsId(@() imtAasExternalBeamGain(0, 0, 0, 0, bs, ...
        struct('mode', 'bogus')), 'imtAasExternalBeamGain:invalidMode');
    okSteer = throwsId(@() imtAasExternalBeamGain(0, 0, 999, 0, bs), ...
        'imtAasExternalBeamGain:invalidSteer');

    wbs = struct('type', 'weights', 'numBeams', 2, 'gainFloorDbi', -300);
    okType = throwsId(@() imtAasExternalBeamGain(0, 0, 0, 0, wbs), ...
        'imtAasExternalBeamGain:unsupportedType');

    % Round-trip: at a beam's own recorded peak, selection returns THAT
    % beam and ~its peak gain.
    kk = 5;
    [gPeak, sel] = imtAasExternalBeamGain(bs.peakAzDeg(kk), bs.peakElDeg(kk), ...
        bs.peakAzDeg(kk), bs.peakElDeg(kk), bs);
    okRound = (sel.beamIndex == kk) && ...
        abs(gPeak - bs.peakGainDbi(kk)) < 1e-9;

    % Between two peaks: vectorized selection must agree with a brute-force
    % loop over every beam.
    aq = 0.5 * (bs.peakAzDeg(2) + bs.peakAzDeg(3));
    eq = 0.5 * (bs.peakElDeg(2) + bs.peakElDeg(3));
    [~, selMid] = imtAasExternalBeamGain(aq, eq, aq, eq, bs);
    brute = zeros(bs.numBeams, 1);
    for i = 1:bs.numBeams
        page = bs.gainDbi(:, :, i).';
        brute(i) = interp2(bs.azDeg(:).', bs.elDeg(:).', page, aq, eq, ...
            'linear', bs.gainFloorDbi);
    end
    [~, bruteIdx] = max(brute);
    okBrute = (selMid.beamIndex == bruteIdx);

    % Out-of-domain elevation (beyond the delivered +-90 deg) hits the
    % documented floor, NOT 0 dBi. Note 89.99 would be INSIDE the domain.
    gOut = imtAasExternalBeamGain(0, 95, 0, 0, bs);
    okFloor = (gOut == bs.gainFloorDbi) && (bs.gainFloorDbi ~= 0);

    % Azimuth wraps rather than flooring (delivered az spans 360 deg).
    gWrapA = imtAasExternalBeamGain(-179, 0, 0, 0, bs);
    gWrapB = imtAasExternalBeamGain( 181, 0, 0, 0, bs);
    okWrap = abs(gWrapA - gWrapB) < 1e-9 && gWrapA ~= bs.gainFloorDbi;

    % nearestPeak mode is available and returns a valid beam.
    [~, selNP] = imtAasExternalBeamGain(0, 0, bs.peakAzDeg(kk), ...
        bs.peakElDeg(kk), bs, struct('mode', 'nearestPeak'));
    okNP = (selNP.beamIndex == kk) && strcmp(selNP.mode, 'nearestPeak');

    ok = okFew && okBs && okMode && okSteer && okType && okRound && ...
         okBrute && okFloor && okWrap && okNP;
    r = check(r, ok, sprintf(['T6: gain fn (notEnough=%d beamset=%d mode=%d ' ...
        'steer=%d type=%d peakRoundTrip=%d vsBruteForce=%d floorNotZero=%d ' ...
        'azWrap=%d nearestPeak=%d)'], okFew, okBs, okMode, okSteer, okType, ...
        okRound, okBrute, okFloor, okWrap, okNP));
end

% =====================================================================
% T7 - composite gain branch
% =====================================================================
function r = t7_composite(r, fx)
    bs = imtAasLoadExternalBeamset(fx.good);
    p  = imtAasDefaultParams();
    azq = -60:5:60;
    elq = -20:5:20;

    % Absent field -> byte-identical to the historical analytic path.
    gBase = imtAasCompositeGain(azq, elq, 10, -5, p);
    pEmpty = p; pEmpty.externalBeamset = [];
    gEmpty = imtAasCompositeGain(azq, elq, 10, -5, pEmpty);
    pOff = p; pOff.externalBeamset = struct('enable', false);
    gOff = imtAasCompositeGain(azq, elq, 10, -5, pOff);
    okPin = isequal(gBase, gEmpty) && isequal(gBase, gOff);

    % Enabled -> equals a direct call into imtAasExternalBeamGain.
    pExt = p;
    pExt.externalBeamset = struct('enable', true, 'beamset', bs, ...
        'mode', 'exhaustive');
    gExt = imtAasCompositeGain(azq, elq, 10, -5, pExt);
    tilt = 0;
    if isfield(p, 'mechanicalDowntiltDeg') && ~isempty(p.mechanicalDowntiltDeg)
        tilt = p.mechanicalDowntiltDeg;
    end
    [saP, seP] = imt_aas_mechanical_tilt_transform(10, -5, tilt);
    [AZ, EL] = imtAasNormalizeGrid(azq, elq);
    [AZp, ELp] = imt_aas_mechanical_tilt_transform(AZ, EL, tilt);
    gDirect = imtAasExternalBeamGain(AZp, ELp, saP, seP, bs);
    okMatch = isequal(size(gExt), size(gDirect)) && ...
              max(abs(gExt(:) - gDirect(:))) < 1e-9;
    okDiffers = ~isequal(gExt, gBase);

    % Both selection hooks on at once -> clean error.
    pBoth = pExt;
    pBoth.beamCodebook = struct('enable', true, 'oversampleH', 4, 'oversampleV', 4);
    okConflict = throwsId(@() imtAasCompositeGain(azq, elq, 10, -5, pBoth), ...
        'imtAasCompositeGain:conflictingBeamSelection');

    % Malformed externalBeamset -> clean error.
    pBad = p; pBad.externalBeamset = struct('enable', true);
    okBad = throwsId(@() imtAasCompositeGain(azq, elq, 10, -5, pBad), ...
        'imtAasCompositeGain:invalidExternalBeamset');
    pBad2 = p; pBad2.externalBeamset = 'nope';
    okBad2 = throwsId(@() imtAasCompositeGain(azq, elq, 10, -5, pBad2), ...
        'imtAasCompositeGain:invalidExternalBeamset');

    ok = okPin && okMatch && okDiffers && okConflict && okBad && okBad2;
    r = check(r, ok, sprintf(['T7: composite (regressionPin=%d ' ...
        'matchesDirect=%d differsFromAnalytic=%d conflictErr=%d ' ...
        'badStruct=%d badType=%d)'], okPin, okMatch, okDiffers, ...
        okConflict, okBad, okBad2));
end

% =====================================================================
% T8 - runner error identifiers
% =====================================================================
function r = t8_runner_errors(r, fx)
    o = mcOpts();

    oNoFile = o; oNoFile.beamSelection = 'external';
    okNoFile = throwsId(@() runR23AasEirpCdfGrid(oNoFile), ...
        'runR23AasEirpCdfGrid:missingExternalBeamFile');

    oBadType = o; oBadType.beamSelection = 'external';
    oBadType.externalBeamFile = 42;
    okBadType = throwsId(@() runR23AasEirpCdfGrid(oBadType), ...
        'runR23AasEirpCdfGrid:invalidExternalBeamFile');

    oMissing = o; oMissing.beamSelection = 'external';
    oMissing.externalBeamFile = fullfile(tempdir, 'no_such_beamset_a71f.mat');
    okMissing = throwsId(@() runR23AasEirpCdfGrid(oMissing), ...
        'imtAasLoadExternalBeamset:fileNotFound');

    oNan = o; oNan.beamSelection = 'external'; oNan.externalBeamFile = fx.nan;
    okNan = throwsId(@() runR23AasEirpCdfGrid(oNan), ...
        'imtAasLoadExternalBeamset:nonFiniteData');

    % Element/geometry mismatch vs the ACTIVE preset, wired automatically.
    oGeom = o; oGeom.beamSelection = 'external';
    oGeom.externalBeamFile = fx.geomBad;
    okGeom = throwsId(@() runR23AasEirpCdfGrid(oGeom), ...
        'imtAasLoadExternalBeamset:geometryMismatch');

    oBadSel = o; oBadSel.beamSelection = 'bogus';
    okBadSel = throwsId(@() runR23AasEirpCdfGrid(oBadSel), ...
        'runR23AasEirpCdfGrid:invalidBeamSelection');

    ok = okNoFile && okBadType && okMissing && okNan && okGeom && okBadSel;
    r = check(r, ok, sprintf(['T8: runner error ids (missingFile=%d ' ...
        'badType=%d notFound=%d nan=%d geomMismatch=%d badSelection=%d)'], ...
        okNoFile, okBadType, okMissing, okNan, okGeom, okBadSel));
end

% =====================================================================
% T9 - output frames
% =====================================================================
function r = t9_frames(r, fx)
    o = mcOpts();
    o.beamSelection    = 'external';
    o.externalBeamFile = fx.good;

    oG = o; oG.outputFrame = 'global';
    oP = o; oP.outputFrame = 'panel';
    outG = runR23AasEirpCdfGrid(oG);
    outP = runR23AasEirpCdfGrid(oP);

    vG = outG.percentileMaps.values;
    vP = outP.percentileMaps.values;
    okG = ~isempty(vG) && any(isfinite(vG(:)));
    okP = ~isempty(vP) && any(isfinite(vP(:)));
    okDiff = ~isequal(vG, vP);   % the frames genuinely differ
    okMeta = strcmp(outG.metadata.beamSelection, 'external') && ...
             strcmp(outP.metadata.beamSelection, 'external');

    ok = okG && okP && okDiff && okMeta;
    r = check(r, ok, sprintf(['T9: external x outputFrame (global=%d panel=%d ' ...
        'framesDiffer=%d meta=%d)'], okG, okP, okDiff, okMeta));
end

% =====================================================================
% T10 - 'internal' alias
% =====================================================================
function r = t10_internal_alias(r, ~)
    o = mcOpts();
    outOmit = runR23AasEirpCdfGrid(o);
    oInt = o; oInt.beamSelection = 'internal';
    outInt = runR23AasEirpCdfGrid(oInt);

    okVals = isequal(outOmit.percentileMaps.values, outInt.percentileMaps.values);
    okNorm = strcmp(outInt.metadata.beamSelection, 'ideal');
    ok = okVals && okNorm;
    r = check(r, ok, sprintf( ...
        'T10: ''internal'' alias == ''ideal'' (values=%d normalizedString=%d)', ...
        okVals, okNorm));
end

% =====================================================================
% T11 - shape independence
% =====================================================================
function r = t11_multi_shape(r, tmpDir)
%T11 The six delivered files all happen to carry 256 beams
%   (N1*O1*N2*O2 = 256 in every case), so differing beam counts cannot be
%   exercised with real data. Synthetic fixtures cover it instead: two beam
%   sets with different numBeams AND different az/el grid sizes.
    specs = { struct('nB', 5,  'az', -180:10:180, 'el', -90:10:90), ...
              struct('nB', 12, 'az', -180:4:180,  'el', -60:2:60) };
    ok = true; detail = '';
    for i = 1:numel(specs)
        sp = specs{i};
        pth = fullfile(tmpDir, sprintf('shape%d.mat', i));
        writeShapeFixture(pth, sp.nB, sp.az, sp.el);
        bs = imtAasLoadExternalBeamset(pth, struct('computeChecksum', false));
        okN  = (bs.numBeams == sp.nB);
        okSz = isequal(size(bs.gainDbi), [numel(sp.az), numel(sp.el), sp.nB]);
        okAx = numel(bs.azDeg) == numel(sp.az) && numel(bs.elDeg) == numel(sp.el);
        % every beam's own recorded peak must round-trip through selection
        okRt = true;
        for k = 1:sp.nB
            [g, sel] = imtAasExternalBeamGain(bs.peakAzDeg(k), bs.peakElDeg(k), ...
                bs.peakAzDeg(k), bs.peakElDeg(k), bs);
            okRt = okRt && (sel.beamIndex == k) && ...
                   abs(g - bs.peakGainDbi(k)) < 1e-9;
        end
        ok = ok && okN && okSz && okAx && okRt;
        detail = [detail sprintf('[nB=%d %dx%d N=%d sz=%d ax=%d rt=%d]', ...
            sp.nB, numel(sp.az), numel(sp.el), okN, okSz, okAx, okRt)]; %#ok<AGROW>
    end
    r = check(r, ok, ['T11: shape independence ' detail]);
end

% =====================================================================
% T12 - beam-coverage diagnostic
% =====================================================================
function r = t12_coverage(r, fx)
    o = mcOpts();
    o.beamSelection    = 'external';
    o.externalBeamFile = fx.good;
    o.outputDomain     = 'gain';     % gainStats is absent without this
    out = runR23AasEirpCdfGrid(o);
    eb  = out.metadata.externalBeamset;

    okFields = isfield(eb,'uniqueBeamsSelected') && isfield(eb,'numBeams') && ...
               isfield(eb,'coverageFraction');
    u = eb.uniqueBeamsSelected; n = eb.numBeams;
    okRange = u >= 1 && u <= n && n == 8;
    okFrac  = abs(eb.coverageFraction - u/n) < 1e-12;

    % PASSIVE: the counter must not perturb any numeric output. Same seed
    % twice -> identical maps, and identical to the pre-existing gain path.
    out2 = runR23AasEirpCdfGrid(o);
    okPassive = isequal(out.percentileMaps.values, out2.percentileMaps.values) && ...
                isequal(out.gainStats.max_dBm, out2.gainStats.max_dBm);

    % More draws must not DECREASE coverage (monotone in draws).
    baseOpts = mcOpts();
    oMore = o; oMore.numMc = baseOpts.numMc * 4;
    outMore = runR23AasEirpCdfGrid(oMore);
    okMono = outMore.metadata.externalBeamset.uniqueBeamsSelected >= u;

    % Absent for non-external runs (byte-compat).
    outIdeal = runR23AasEirpCdfGrid(mcOpts());
    okAbsent = isempty(outIdeal.metadata.externalBeamset);

    ok = okFields && okRange && okFrac && okPassive && okMono && okAbsent;
    r = check(r, ok, sprintf(['T12: coverage diagnostic %d/%d beams ' ...
        '(fields=%d range=%d frac=%d passive=%d monotone=%d absentWhenIdeal=%d)'], ...
        u, n, okFields, okRange, okFrac, okPassive, okMono, okAbsent));
end

% =====================================================================
% Fixtures
% =====================================================================
function writeGoodFixture(path)
%WRITEGOODFIXTURE Small synthetic beam set matching the delivered schema.
%   Deliberately spans the full az/el domain so the runner's default grid
%   is covered and the azimuth-wrap path is exercised.
    [beams, az, el, pmi_env, metadata] = buildFixture();
    save(path, 'beams', 'az', 'el', 'pmi_env', 'metadata');
end

function writeVariantFixture(path, kind)
    [beams, az, el, pmi_env, metadata] = buildFixture();
    switch kind
        case 'nan'
            beams(2, 3, 4) = NaN;
        case 'badaxis'
            az(10) = az(9);          % breaks strict monotonicity
        case 'baddims'
            az = az(1:end-1);        % axis/tensor length disagreement
        case 'badmeta'
            metadata = '{not valid json,,';
        case 'badenv'
            pmi_env(1, 1) = pmi_env(1, 1) + 5;
        case 'geombad'
            m = jsondecode(metadata);
            m.physical_grid_horizontal_cols_per_pol = 4;   % preset says 16
            metadata = jsonencode(m);
    end
    save(path, 'beams', 'az', 'el', 'pmi_env', 'metadata');
end

function writeUnknownLayout(path)
    somethingElse = magic(4);
    notes = 'no recognizable beam-set variables here';
    save(path, 'somethingElse', 'notes');
end

function writeWeightsFixture(path)
%WRITEWEIGHTSFIXTURE Complex per-element excitations with a WRONG element
%   count, so the preset cross-check raises :elementCountMismatch.
    weights = complex(randn(64, 4), randn(64, 4));   % preset implies 768
    metadata = '{"antenna_definition": "synthetic_weights_fixture"}';
    save(path, 'weights', 'metadata');
end

function writeShapeFixture(path, nB, az, el)
%WRITESHAPEFIXTURE Beam set of arbitrary beam count / grid size.
    nAz = numel(az); nEl = numel(el);
    % Peaks must sit EXACTLY on grid nodes, or each beam's recorded argmax
    % peak lands on a neighbouring node and the round-trip assertion becomes
    % a coin flip between adjacent beams. Beams are separated in azimuth
    % only, with distinct peak gains, so the argmax is unambiguous.
    azIdx = unique(round(linspace(0.30*nAz, 0.70*nAz, nB)));
    assert(numel(azIdx) == nB, 'shape fixture: az grid too coarse for %d beams', nB);
    elIdx = repmat(round((nEl+1)/2), 1, nB);
    peakAz = az(azIdx); peakEl = el(elIdx);
    peakGain = 30 - 0.1 * (0:nB-1);
    beams = zeros(nB, nEl, nAz);
    [AZ, EL] = meshgrid(az, el);
    for i = 1:nB
        dAz = mod(AZ - peakAz(i) + 180, 360) - 180;
        beams(i,:,:) = max(peakGain(i) - 40*(dAz/45).^2 - 40*((EL-peakEl(i))/45).^2, -25);
    end
    pmi_env = reshape(max(beams, [], 1), [nEl, nAz]);
    metadata = jsonencode(struct('antenna_definition','synthetic_shape_fixture', ...
        'num_beams', nB));
    save(path, 'beams', 'az', 'el', 'pmi_env', 'metadata');
end

function [beams, az, el, pmi_env, metadata] = buildFixture()
%BUILDFIXTURE 8 separable beams on a coarse full-sphere grid.
    az = -180:10:180;      % 37 samples, spans a full 360 deg
    el = -90:10:90;        % 19 samples
    nAz = numel(az); nEl = numel(el);

    % Peaks sit EXACTLY on grid nodes so each beam's recorded argmax peak
    % is unambiguous, and peak gains are made distinct so no two beams can
    % tie at a node (a tie would make argmax order-dependent and the
    % peak round-trip assertion meaningless).
    peakAz = [-30 -20 -10   0  10  20  30  40];
    peakEl = [-20 -10   0  10 -10   0  10   0];
    nB = numel(peakAz);
    peakGain = 32.2 - 0.1 * (0:nB - 1);

    % Broad pattern with a realistic sidelobe floor well ABOVE the null
    % sentinel, mirroring the delivered files (real data everywhere, the
    % -300 sentinel appearing at only a couple of points).
    sidelobeFloorDbi = -25;
    nullSentinelDbi  = -300;

    beams = zeros(nB, nEl, nAz);
    [AZ, EL] = meshgrid(az, el);        % both [nEl x nAz]
    for i = 1:nB
        dAz = wrapTo180(AZ - peakAz(i));
        dEl = EL - peakEl(i);
        g = peakGain(i) - 40 * (dAz / 90).^2 - 40 * (dEl / 90).^2;
        beams(i, :, :) = max(g, sidelobeFloorDbi);
    end
    % Plant the exact null sentinel so gainFloorDbi is unambiguous and
    % distinguishable from the sidelobe floor.
    beams(1, 1, 1) = nullSentinelDbi;
    pmi_env = reshape(max(beams, [], 1), [nEl, nAz]);

    md = struct( ...
        'aas_subarray_cols', 1, ...
        'aas_subarray_rows', 3, ...
        'antenna_definition', 'synthetic_test_fixture', ...
        'array_electrical_tilt_deg', 0, ...
        'carrier_frequency_hz', 3.7e9, ...
        'element_spacing_h_wavelengths', 0.5, ...
        'element_spacing_v_wavelengths', 0.7, ...
        'mechanical_downtilt_deg', 0, ...
        'num_beams', nB, ...
        'num_physical_elements', 768, ...
        'physical_grid_horizontal_cols_per_pol', 16, ...
        'physical_grid_vertical_rows_per_pol', 8, ...
        'subarray_downtilt_deg', 0, ...
        'tx_power_dbm', 46.0);
    metadata = jsonencode(md);
end

function a = wrapTo180(a)
    a = mod(a + 180, 360) - 180;
end

% =====================================================================
% Helpers
% =====================================================================
function o = mcOpts()
%MCOPTS Small, fast, fixed-seed runner options.
    o = struct();
    o.numMc      = 6;
    o.seed       = 11;
    o.azGridDeg  = -60:15:60;
    o.elGridDeg  = -20:10:20;
    o.numUesPerSector = 3;
end

function r = check(r, passed, message)
    r(end + 1) = struct('name', message, 'passed', logical(passed), ...
        'message', message);
    if passed
        fprintf('  PASS  %s\n', message);
    else
        fprintf('  FAIL  %s\n', message);
    end
end

function tf = throwsId(fn, id)
%THROWSID True when FN errors with the exact MException identifier ID.
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
        if ~tf
            fprintf('        (expected %s, got %s)\n', id, err.identifier);
        end
    end
end

function rmdirSafe(d)
    try
        if exist(d, 'dir')
            rmdir(d, 's');
        end
    catch
        % best effort
    end
end
