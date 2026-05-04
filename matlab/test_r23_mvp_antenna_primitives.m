function results = test_r23_mvp_antenna_primitives()
%TEST_R23_MVP_ANTENNA_PRIMITIVES Focused tests for snake_case MVP antenna primitives.
%
%   RESULTS = test_r23_mvp_antenna_primitives()
%
%   Pins the public R23 MVP antenna primitives that have no other direct
%   coverage:
%
%     compute_element_pattern  - wrapper of imtAasElementPattern. Swaps
%                                argument order (theta, phi) -> (az, el).
%     compute_subarray_factor  - own math (parallel implementation of the
%                                L-element sub-array branch inside
%                                imtAasArrayFactor); has zero callers in
%                                the codebase.
%     compute_array_factor     - wrapper of imtAasArrayFactor. Swaps
%                                argument order and accepts a struct form
%                                of the steering angles.
%
%   The composite-gain pipeline already exercises the wrapped functions
%   (imtAasElementPattern / imtAasArrayFactor) indirectly. This file pins
%   only what those indirect tests cannot catch:
%
%     P1.  compute_element_pattern at (theta=0, phi=0) returns
%          params.elementGainDbi exactly.
%     P2.  Argument-order regression: at (theta=0, phi=phi_3db) the result
%          is dominated by horizontal attenuation; at
%          (theta=theta_3db, phi=0) it is dominated by vertical attenuation.
%          The two values must differ by exactly the asymmetric A_EH/A_EV
%          difference, which catches a silent (theta, phi) -> (az, el)
%          swap.
%     P3.  Strict equality vs imtAasElementPattern with arguments swapped
%          back, at multiple asymmetric points (1e-12 dB).
%     P4.  compute_subarray_factor peaks at theta = -subarrayDowntiltDeg
%          with value 10*log10(L) (= 10*log10(3) ~ 4.7712 dB for the R23
%          default L = 3).
%     P5.  Off-peak monotonicity: at theta = 0 (horizon, mismatched against
%          a +3 deg downtilt) the value is strictly less than the peak.
%     P6.  L = 1 short-circuit returns exactly zero (no sub-array gain).
%     P7.  compute_array_factor peak gain in the panel frame at
%          (theta, phi) = (-subarrayDowntiltDeg, 0) with steering
%          [0, -subarrayDowntiltDeg] is
%          10*log10(1 + rho*(N_H*N_V - 1)) + 10*log10(L)
%          (= ~25.84 dB for the R23 defaults).
%     P8.  Strict equality vs imtAasArrayFactor with arguments swapped
%          back, at an asymmetric (theta, phi) point that would not be
%          symmetric under a (theta <-> phi) transposition (1e-12 dB).
%     P9.  Struct-form steering ([.steerAzDeg, .steerElDeg] fields) gives
%          identical output to vector-form steering [steerAzDeg, steerElDeg].

    results.summary = {};
    results.passed  = true;

    results = p1_element_boresight(results);
    results = p2_element_argument_order(results);
    results = p3_element_wraps_imtaas(results);
    results = p4_subarray_peak(results);
    results = p5_subarray_off_peak(results);
    results = p6_subarray_L1_shortcut(results);
    results = p7_array_factor_panel_peak(results);
    results = p8_array_factor_wraps_imtaas(results);
    results = p9_array_factor_struct_steering(results);

    fprintf('\n--- test_r23_mvp_antenna_primitives summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = p1_element_boresight(r)
    p = get_r23_aas_params();
    g = compute_element_pattern(0, 0, p);
    ok = isfinite(g) && abs(g - p.elementGainDbi) < 1e-12;
    r = check(r, ok, sprintf( ...
        'P1: compute_element_pattern(0,0) = elementGainDbi (got %.9f, expected %.9f)', ...
        g, p.elementGainDbi));
end

% =====================================================================
function r = p2_element_argument_order(r)
    p = get_r23_aas_params();

    % Horizontal cut at the horizontal 3 dB beamwidth: phi=phi_3db, theta=0.
    % Wrapper passes phi -> az, theta -> el. Expect:
    %   A_EH = -min(k*(phi_3db/phi_3db)^2, A_m) = -k = -12 dB
    %   A_EV = 0
    %   loss = min(12, A_m=30) = 12
    %   result = elementGainDbi - 12
    gH = compute_element_pattern(0, p.hBeamwidthDeg, p);
    expectedH = p.elementGainDbi - p.k;
    okH = isfinite(gH) && abs(gH - expectedH) < 1e-9;

    % Vertical cut at the vertical 3 dB beamwidth: phi=0, theta=theta_3db.
    % Same magnitude as horizontal because A_EV = -k there.
    gV = compute_element_pattern(p.vBeamwidthDeg, 0, p);
    expectedV = p.elementGainDbi - p.k;
    okV = isfinite(gV) && abs(gV - expectedV) < 1e-9;

    % Asymmetric witness for argument-order swap: at (theta=0, phi=vBeamwidth)
    % the dominant attenuation is horizontal at vBeamwidth/hBeamwidth squared
    % (small, since vBeamwidth < hBeamwidth). At (theta=hBeamwidth, phi=0)
    % the dominant attenuation is vertical at hBeamwidth/vBeamwidth squared
    % (large, since hBeamwidth > vBeamwidth). These two MUST be different;
    % a swapped wrapper would return identical magnitudes (just relabelled),
    % so the difference is the canary.
    gA = compute_element_pattern(0, p.vBeamwidthDeg, p);
    gB = compute_element_pattern(p.hBeamwidthDeg, 0, p);
    % Closed-form expected loss, capped per M.2101: A_EH at A_m, A_EV at
    % SLA_nu, total loss at A_m.
    A_EH_A = min(p.k * (p.vBeamwidthDeg / p.hBeamwidthDeg)^2, p.frontToBackDb);
    A_EV_A = 0;
    expectedA = p.elementGainDbi - min(A_EH_A + A_EV_A, p.frontToBackDb);
    A_EH_B = 0;
    A_EV_B = min(p.k * (p.hBeamwidthDeg / p.vBeamwidthDeg)^2, p.sideLobeAttenuationDb);
    expectedB = p.elementGainDbi - min(A_EH_B + A_EV_B, p.frontToBackDb);
    okA = abs(gA - expectedA) < 1e-9;
    okB = abs(gB - expectedB) < 1e-9;
    okAsym = abs(gA - gB) > 1.0;  % they must differ by > 1 dB

    r = check(r, okH && okV && okA && okB && okAsym, sprintf( ...
        ['P2: element pattern at horizontal/vertical 3 dB cuts and asymmetric ' ...
         'witness (gH=%.6f, gV=%.6f, gA=%.6f, gB=%.6f; expected gA=%.6f, gB=%.6f)'], ...
        gH, gV, gA, gB, expectedA, expectedB));
end

% =====================================================================
function r = p3_element_wraps_imtaas(r)
    p = get_r23_aas_params();
    thetaList = [-30, -10, 0, 5, 20];
    phiList   = [-45, -10, 0, 15, 60];
    okAll = true;
    maxAbs = 0;
    for i = 1:numel(thetaList)
        for j = 1:numel(phiList)
            theta = thetaList(i);
            phi   = phiList(j);
            gWrap = compute_element_pattern(theta, phi, p);
            gRef  = imtAasElementPattern(phi, theta, p);
            diff = abs(gWrap - gRef);
            maxAbs = max(maxAbs, diff);
            if ~(diff < 1e-12)
                okAll = false;
            end
        end
    end
    r = check(r, okAll, sprintf( ...
        'P3: compute_element_pattern == imtAasElementPattern with swapped args (max |diff| = %.3e dB)', ...
        maxAbs));
end

% =====================================================================
function r = p4_subarray_peak(r)
    p = get_r23_aas_params();
    L = p.numElementsPerSubarray;

    % Peak is at theta = -subarrayDowntiltDeg.
    thetaPeak = -p.subarrayDowntiltDeg;
    g = compute_subarray_factor(thetaPeak, 0, p);
    expected = 10 * log10(double(L));
    ok = isfinite(g) && abs(g - expected) < 1e-9;
    r = check(r, ok, sprintf( ...
        'P4: compute_subarray_factor peak at theta=-subarrayDowntiltDeg (got %.9f, expected %.9f = 10*log10(L=%d))', ...
        g, expected, L));
end

% =====================================================================
function r = p5_subarray_off_peak(r)
    p = get_r23_aas_params();
    L = p.numElementsPerSubarray;

    thetaPeak = -p.subarrayDowntiltDeg;
    gPeak = compute_subarray_factor(thetaPeak, 0, p);
    g0    = compute_subarray_factor(0,         0, p);

    okPeakDominant = isfinite(gPeak) && isfinite(g0) && (gPeak > g0 + 1e-6);

    % phi is accepted for API symmetry but the sub-array factor is
    % independent of phi. Pin that contract.
    gPhiTrash = compute_subarray_factor(thetaPeak, 47.31, p);
    okPhiInvariant = abs(gPhiTrash - gPeak) < 1e-12;

    % Same-shape input handling: vector theta and matching-shape phi.
    thetaVec = [-10 -3 0 5 10];
    gVec = compute_subarray_factor(thetaVec, zeros(size(thetaVec)), p);
    okVecShape = isequal(size(gVec), size(thetaVec));
    okVecPeak  = abs(gVec(2) - 10*log10(double(L))) < 1e-9;
    okVecMonotonic = (gVec(2) >= max([gVec(1), gVec(3), gVec(4), gVec(5)]) - 1e-9);

    r = check(r, okPeakDominant && okPhiInvariant && okVecShape && okVecPeak && okVecMonotonic, ...
        sprintf(['P5: sub-array drop off peak / phi-invariant / vector shape ' ...
                 '(gPeak=%.6f, g0=%.6f, gVec(2)=%.6f)'], ...
                gPeak, g0, gVec(2)));
end

% =====================================================================
function r = p6_subarray_L1_shortcut(r)
    p = get_r23_aas_params();
    p.numElementsPerSubarray = 1;
    thetaList = [-15 -3 0 5 15];
    phiList   = zeros(size(thetaList));
    g = compute_subarray_factor(thetaList, phiList, p);
    ok = isequal(size(g), size(thetaList)) && all(abs(g(:)) < 1e-12);
    r = check(r, ok, sprintf( ...
        'P6: compute_subarray_factor(L=1) returns all-zeros (max |g| = %.3e)', ...
        max(abs(g(:)))));
end

% =====================================================================
function r = p7_array_factor_panel_peak(r)
    p = get_r23_aas_params();
    N_H = p.numColumns;
    N_V = p.numRows;
    L   = p.numElementsPerSubarray;
    rho = p.rho;

    % Panel-frame peak: observation aligned with steering, and elevation
    % matched to the fixed sub-array downtilt. Note: steerEl = -subarrayTilt
    % so that thi_r = -steerEl = +subarrayTilt.
    sAz = 0;
    sEl = -p.subarrayDowntiltDeg;
    g = compute_array_factor(sEl, sAz, [sAz, sEl], p);

    expected = 10 * log10(1 + rho * (double(N_H) * double(N_V) - 1)) ...
             + 10 * log10(double(L));
    ok = isfinite(g) && abs(g - expected) < 1e-9;
    r = check(r, ok, sprintf( ...
        ['P7: compute_array_factor peak (panel frame) = 10*log10(1+rho*(N_H*N_V-1))+10*log10(L) ' ...
         '(got %.9f, expected %.9f)'], g, expected));
end

% =====================================================================
function r = p8_array_factor_wraps_imtaas(r)
    p = get_r23_aas_params();

    % Asymmetric witness: theta != phi and steerAz != steerEl. A swapped
    % wrapper would silently return imtAasArrayFactor(theta, phi, ...)
    % instead of imtAasArrayFactor(phi, theta, ...). The two are not equal
    % at this point because the array geometry is N_H = 16 != N_V = 8.
    theta = -7;
    phi   = 25;
    sAz   = 5;
    sEl   = -2;

    gWrap = compute_array_factor(theta, phi, [sAz, sEl], p);
    gRef  = imtAasArrayFactor(phi, theta, sAz, sEl, p);
    okEq  = isfinite(gWrap) && isfinite(gRef) && abs(gWrap - gRef) < 1e-12;

    % Witness: would-be-swapped value at this point must differ from the
    % correct value by an amount greater than the equality tolerance, so
    % we know the test would actually catch a silent swap.
    gSwap = imtAasArrayFactor(theta, phi, sAz, sEl, p);
    okWitness = abs(gWrap - gSwap) > 1e-3;

    r = check(r, okEq && okWitness, sprintf( ...
        ['P8: compute_array_factor == imtAasArrayFactor with swapped args; ' ...
         '(|gWrap - gRef| = %.3e dB; witness |gWrap - gSwap| = %.3e dB)'], ...
        abs(gWrap - gRef), abs(gWrap - gSwap)));
end

% =====================================================================
function r = p9_array_factor_struct_steering(r)
    p = get_r23_aas_params();

    theta = 4;
    phi   = -12;
    sAz   = -7;
    sEl   = -1.5;

    gVec    = compute_array_factor(theta, phi, [sAz, sEl], p);
    gStruct = compute_array_factor(theta, phi, ...
        struct('steerAzDeg', sAz, 'steerElDeg', sEl), p);
    okEq = isfinite(gVec) && isfinite(gStruct) && abs(gVec - gStruct) < 1e-12;

    % Bad steering struct (vector-valued field) should error cleanly.
    % NOTE: wrap the vector field in a cell so struct() does not expand
    % into a struct array.
    threwBad = false;
    badSteer = struct('steerAzDeg', {[0 1]}, 'steerElDeg', {0});
    try
        compute_array_factor(theta, phi, badSteer, p);
    catch err
        threwBad = strcmp(err.identifier, 'compute_array_factor:badSteeringStruct');
    end

    % Wrong-shape input (neither vector nor recognised struct) should error.
    threwShape = false;
    try
        compute_array_factor(theta, phi, [0 0 0], p);
    catch err
        threwShape = strcmp(err.identifier, 'compute_array_factor:badSteering');
    end

    r = check(r, okEq && threwBad && threwShape, sprintf( ...
        ['P9: struct-form steering matches vector form (|diff| = %.3e dB), ' ...
         'and bad inputs throw the documented identifiers'], ...
        abs(gVec - gStruct)));
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
