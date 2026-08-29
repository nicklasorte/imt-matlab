function results = test_imtAasExternalBeamGainFrame()
%TEST_IMTAASEXTERNALBEAMGAINFRAME Frame (panel vs sector) regression test.
%
%   RESULTS = test_imtAasExternalBeamGainFrame()
%
%   Locks in the finding that external PMI beam sets are PANEL-FRAME
%   (pre-mechanical-tilt) and that the external gain path does not rotate
%   them a second time. Replaces the ad hoc verification script that
%   originally established this.
%
%   Method -- the "tilt smile" positive control. A mechanical downtilt
%   applied as a coordinate rotation makes constant-elevation null bands BOW
%   with azimuth; an untilted / panel-frame pattern has FLAT horizontal
%   bands. The band-shift metric below measures that bowing:
%
%       for each azimuth column with |az| <= azLim, find the integer
%       elevation shift that best aligns that column's elevation profile to
%       the az ~ 0 column (min SSE); report std / max-min of those shifts.
%
%   Robust to many equal-depth nulls, unlike "elevation of the per-column
%   minimum", which jumps between nulls and produces meaningless numbers.
%
%   CRITICAL -- the positive control. A metric that always returned 0 would
%   be indistinguishable from a genuinely flat pattern, so the test never
%   asserts "flat" on its own. It asserts flat on the as-delivered fixture
%   AND that the SAME metric, on the SAME data rotated by a known angle
%   through imt_aas_mechanical_tilt_transform, reads clearly nonzero and
%   grows with the rotation angle.
%
%       T1. As-delivered synthetic beam set reads ~0 (flat bands).
%       T2. Rotated copy reads clearly nonzero -> the metric can detect tilt.
%       T3. The metric increases monotonically with rotation angle.
%       T4. Peak elevation is preserved as delivered and moves by ~the
%           rotation angle when rotated (direction check, not just magnitude).
%       T5. imtAasExternalBeamGain does not rotate the pattern: evaluated on
%           a panel-frame grid it reproduces the fixture, and a beam's own
%           peak direction round-trips to its recorded peak gain.
%
%   Synthetic fixture only -- no real MAT file, so the suite stays fast.
%   Base MATLAB only.
%
%   See also imtAasExternalBeamGain, imtAasLoadExternalBeamset,
%   imt_aas_mechanical_tilt_transform, test_external_beamset.

    results = struct('name','test_imtAasExternalBeamGainFrame','passed',false, ...
        'skipped',false,'numChecks',0,'numPassed',0,'message','','checks',[]);
    checks = struct('name',{},'passed',{},'message',{});

    fprintf('\n--- test_imtAasExternalBeamGainFrame ---\n');

    AZLIM = 60; ELWIN = 20; SHIFTMAX = 8;
    [bs, az, el, envFlat] = buildFlatBandFixture();

    % ---- T1: as delivered -> flat -----------------------------------
    sd0 = bandShift(envFlat, el, az, AZLIM, ELWIN, SHIFTMAX);
    ok1 = sd0 < 1e-9;
    checks = add(checks, ok1, sprintf('T1: as-delivered band-shift std = %.6f deg (flat)', sd0));

    % ---- T2/T3: positive control ------------------------------------
    tilts = [3 6 10];
    sdT = zeros(size(tilts));
    for k = 1:numel(tilts)
        sdT(k) = bandShift(rotateMap(envFlat, az, el, tilts(k)), el, az, ...
            AZLIM, ELWIN, SHIFTMAX);
    end
    ok2 = all(sdT > 100 * max(sd0, eps));
    checks = add(checks, ok2, sprintf(['T2: POSITIVE CONTROL rotated std = [%s] deg ' ...
        '-> metric detects a real tilt (not stuck at 0)'], num2str(sdT, '%.4f ')));
    ok3 = all(diff(sdT) > 0);
    checks = add(checks, ok3, sprintf('T3: metric grows monotonically with tilt %s deg (%d)', ...
        mat2str(tilts), ok3));

    % ---- T4: peak elevation moves by ~the rotation ------------------
    peakEl = @(M) el(peakRow(M));
    pe0 = peakEl(envFlat);
    pe6 = peakEl(rotateMap(envFlat, az, el, 6));
    ok4 = abs(pe0) <= 1.0 && abs((pe6 - pe0) + 6) <= 1.0;
    checks = add(checks, ok4, sprintf(['T4: peak el as delivered %+.2f deg, rotated 6 deg ' ...
        '-> %+.2f deg (moved %+.2f, expected ~-6)'], pe0, pe6, pe6 - pe0));

    % ---- T5: the gain path does not re-rotate the pattern -----------
    G = imtAasExternalBeamGain(az, el, 0, 0, bs);      % [nAz x nEl]
    sd5 = bandShift(G.', el, az, AZLIM, ELWIN, SHIFTMAX);
    okFlat = sd5 < 1e-9;
    kk = 3;
    [gPk, sel] = imtAasExternalBeamGain(bs.peakAzDeg(kk), bs.peakElDeg(kk), ...
        bs.peakAzDeg(kk), bs.peakElDeg(kk), bs);
    okRt = (sel.beamIndex == kk) && abs(gPk - bs.peakGainDbi(kk)) < 1e-9;
    ok5 = okFlat && okRt;
    checks = add(checks, ok5, sprintf(['T5: gain path leaves the pattern un-rotated ' ...
        '(std %.6f deg) and peak round-trips (beam %d, %.4f dBi) [flat=%d rt=%d]'], ...
        sd5, sel.beamIndex, gPk, okFlat, okRt));

    nPass = sum([checks.passed]); nTot = numel(checks);
    fprintf('--- test_imtAasExternalBeamGainFrame summary: %d/%d passed ---\n', nPass, nTot);
    if nPass == nTot, fprintf('  ALL TESTS PASSED\n'); end
    results.passed    = nPass == nTot;
    results.numChecks = nTot;
    results.numPassed = nPass;
    results.message   = sprintf('%d/%d checks passed', nPass, nTot);
    results.checks    = checks;
end

% =====================================================================

function [bs, az, el, envFlat] = buildFlatBandFixture()
%BUILDFLATBANDFIXTURE Beam set with deliberately FLAT horizontal null bands.
%   Separable in az and el, so constant-elevation features are perfectly
%   azimuth-independent by construction: the metric must read exactly 0.
    az = -180:1:180;
    el = -60:0.25:60;
    peakAzList = [-20 -10 0 10 20];
    nB = numel(peakAzList);
    nAz = numel(az); nEl = numel(el);

    % Elevation factor with sharp nulls at fixed elevations (the "bands").
    elFactor = -3 - 30 * abs(sin(deg2rad(el * 4)));      % nulls every 45 deg
    gain = zeros(nB, nEl, nAz);
    for i = 1:nB
        dAz = wrapTo180Local(az - peakAzList(i));
        azFactor = -0.004 * dAz.^2;                      % broad in azimuth
        gain(i,:,:) = 32 + repmat(elFactor(:), 1, nAz) + repmat(azFactor, nEl, 1);
    end
    envFlat = reshape(max(gain, [], 1), [nEl, nAz]);

    % Canonical beamset struct (same shape imtAasLoadExternalBeamset returns).
    bs = struct();
    bs.type         = 'patterns';
    bs.numBeams     = nB;
    bs.gainDbi      = permute(gain, [3 2 1]);            % [nAz x nEl x nB]
    bs.azDeg        = az(:);
    bs.elDeg        = el(:);
    bs.gainFloorDbi = min(gain(:));
    flat = reshape(gain, nB, nEl * nAz);
    [pk, li] = max(flat, [], 2);
    ie = mod(li - 1, nEl) + 1; ia = floor((li - 1) / nEl) + 1;
    bs.peakGainDbi = pk(:);
    bs.peakElDeg   = el(ie).';
    bs.peakAzDeg   = az(ia).';
end

function M = rotateMap(M0, az, el, tiltDeg)
%ROTATEMAP Sector-frame view of a panel-frame map, via the repo transform.
    [AZ, EL] = meshgrid(az, el);
    [AZp, ELp] = imt_aas_mechanical_tilt_transform(AZ, EL, tiltDeg);
    M = interp2(az, el, M0, AZp, ELp, 'linear', min(M0(:)));
end

function r = peakRow(M)
    [~, l] = max(M(:)); [r, ~] = ind2sub(size(M), l);
end

function sdDeg = bandShift(M, elVec, azVec, azLim, elWin, shiftMaxDeg)
%BANDSHIFT Column-alignment curvature metric (see the header).
    elStep = median(diff(elVec));
    maxS   = round(shiftMaxDeg / elStep);
    w      = find(abs(elVec) <= elWin);
    w      = w(w - maxS >= 1 & w + maxS <= numel(elVec));
    [~, j0] = min(abs(azVec));
    ref = M(w, j0);
    cols = find(abs(azVec) <= azLim);
    sh = zeros(numel(cols), 1);
    for k = 1:numel(cols)
        best = inf; bshift = 0;
        for s = -maxS:maxS
            d = M(w + s, cols(k)) - ref; e = sum(d.^2);
            if e < best, best = e; bshift = s; end
        end
        sh(k) = bshift * elStep;
    end
    sdDeg = std(sh);
end

function a = wrapTo180Local(a)
    a = mod(a + 180, 360) - 180;
end

function c = add(c, passed, message)
    c(end+1) = struct('name', message, 'passed', logical(passed), 'message', message);
    if passed, fprintf('  PASS  %s\n', message); else, fprintf('  FAIL  %s\n', message); end
end
