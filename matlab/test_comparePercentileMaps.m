function results = test_comparePercentileMaps()
%TEST_COMPAREPERCENTILEMAPS Focused unit tests for comparePercentileMaps.
%
%   RESULTS = test_comparePercentileMaps()
%
%   Covers:
%       1. Identical inputs -> delta all zero; perPercentile.maxAbs all 0;
%          summary.overallMeanBias == 0; summary.totalExceed == 0.
%       2. Constant offset B = A - 5 (A-B = +5 everywhere) -> delta all +5;
%          maxAbs==5; meanBias==+5; rms==5; p95Abs==5; nExceed == all cells;
%          worstCase.signedAtMaxAbs all +5.
%       3. Runner-output form: minimal structs carrying both
%          .gainPercentileMaps and .percentileMaps; 'Field' selects the
%          right cube and the default is gain.
%       4. Grid mismatch (different azGrid length, and separately different
%          percentiles) -> throws comparePercentileMaps:gridMismatch.
%       5. NaN handling: injected NaN excluded from reductions, counted in
%          nNaN, all reported metrics finite.
%       6. Worst-case-per-direction: a hand-checkable 2x2x3 cube with a known
%          per-direction argmax over p -> assert worstCase.signedAtMaxAbs and
%          worstCase.maxAbsDelta exactly.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')
%
%   See also: comparePercentileMaps, test_eirp_percentile_maps.

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_comparePercentileMaps ---\n');

    % ===== shared small pmaps fixture (Naz=4, Nel=3, P=5) =====
    az  = -30:20:30;       % Naz = 4
    el  = -10:10:10;       % Nel = 3
    pct = [5 25 50 75 95]; % P = 5
    Naz = numel(az); Nel = numel(el); P = numel(pct);
    rng(7);
    A = makePmaps(az, el, pct, 20 + 5 * randn(Naz, Nel, P));

    % ===== 1. identical inputs =====
    cmp1 = comparePercentileMaps(A, A, 'Print', false);
    assert(all(cmp1.delta(:) == 0), 'identical: delta must be all zero');
    assert(all(cmp1.perPercentile.maxAbs == 0), ...
        'identical: perPercentile.maxAbs must be all 0');
    assert(cmp1.summary.overallMeanBias == 0, ...
        'identical: overallMeanBias must be 0');
    assert(cmp1.summary.totalExceed == 0, ...
        'identical: totalExceed must be 0');
    assert(strcmp(cmp1.units, 'dB'), 'units must be dB');
    assert(isequal(size(cmp1.delta), [Naz, Nel, P]), 'delta shape');
    fprintf('  [OK] identical inputs -> zero delta, zero metrics\n');

    % ===== 2. constant offset B = A - 5 -> delta = +5 everywhere =====
    B2 = A;
    B2.values = A.values - 5;
    cmp2 = comparePercentileMaps(A, B2, 'Print', false);
    assert(all(abs(cmp2.delta(:) - 5) < 1e-12), 'offset: delta must be +5');
    assert(all(abs(cmp2.perPercentile.maxAbs   - 5) < 1e-12), 'maxAbs==5');
    assert(all(abs(cmp2.perPercentile.meanBias - 5) < 1e-12), 'meanBias==+5');
    assert(all(abs(cmp2.perPercentile.rms      - 5) < 1e-12), 'rms==5');
    assert(all(abs(cmp2.perPercentile.p95Abs   - 5) < 1e-12), 'p95Abs==5');
    assert(all(cmp2.perPercentile.nExceed == Naz * Nel), ...
        'nExceed must equal all cells (5 > 3)');
    assert(all(abs(cmp2.worstCase.signedAtMaxAbs(:) - 5) < 1e-12), ...
        'worstCase.signedAtMaxAbs must be +5');
    assert(all(abs(cmp2.worstCase.maxAbsDelta(:) - 5) < 1e-12), ...
        'worstCase.maxAbsDelta must be 5');
    assert(abs(cmp2.summary.overallMeanBias - 5) < 1e-12, 'overallMeanBias==5');
    assert(cmp2.summary.totalExceed == Naz * Nel * P, 'totalExceed all cells');
    fprintf('  [OK] constant +5 offset metrics\n');

    % Sign convention: A - B; swap -> -5.
    cmp2b = comparePercentileMaps(B2, A, 'Print', false);
    assert(all(abs(cmp2b.delta(:) + 5) < 1e-12), 'swapped sign -> -5');
    fprintf('  [OK] sign convention (A - B)\n');

    % ===== 3. runner-output form: Field selects the cube; default = gain =
    gainCube = A.values;            % treat as dBi
    eirpCube = A.values + 100;      % treat as dBm, clearly distinct
    runnerA = struct( ...
        'gainPercentileMaps', makePmapsUnits(az, el, pct, gainCube, 'dBi'), ...
        'percentileMaps',     makePmapsUnits(az, el, pct, eirpCube, 'dBm'));
    runnerB = struct( ...
        'gainPercentileMaps', makePmapsUnits(az, el, pct, gainCube - 2, 'dBi'), ...
        'percentileMaps',     makePmapsUnits(az, el, pct, eirpCube - 7, 'dBm'));

    cmpGainDefault = comparePercentileMaps(runnerA, runnerB, 'Print', false);
    assert(strcmp(cmpGainDefault.meta.fieldUsed, 'gainPercentileMaps'), ...
        'default Field must be gain');
    assert(all(abs(cmpGainDefault.delta(:) - 2) < 1e-12), ...
        'gain cube delta must be +2');

    cmpGain = comparePercentileMaps(runnerA, runnerB, 'Field', 'gain', 'Print', false);
    assert(all(abs(cmpGain.delta(:) - 2) < 1e-12), 'explicit gain delta +2');

    cmpEirp = comparePercentileMaps(runnerA, runnerB, 'Field', 'eirp', 'Print', false);
    assert(strcmp(cmpEirp.meta.fieldUsed, 'percentileMaps'), ...
        'Field eirp must select percentileMaps');
    assert(all(abs(cmpEirp.delta(:) - 7) < 1e-12), 'eirp cube delta must be +7');
    fprintf('  [OK] runner-output Field selection (gain default / eirp)\n');

    % ===== 4. grid mismatch -> gridMismatch error =====
    Baz = makePmaps(-30:20:50, el, pct, randn(5, Nel, P));   % Naz = 5
    threw = false;
    try
        comparePercentileMaps(A, Baz, 'Print', false);
    catch err
        threw = strcmp(err.identifier, 'comparePercentileMaps:gridMismatch');
    end
    assert(threw, 'azGrid length mismatch must throw gridMismatch');

    Bpct = makePmaps(az, el, [5 25 50 75 90], randn(Naz, Nel, P)); % different pct
    threw = false;
    try
        comparePercentileMaps(A, Bpct, 'Print', false);
    catch err
        threw = strcmp(err.identifier, 'comparePercentileMaps:gridMismatch');
    end
    assert(threw, 'percentiles mismatch must throw gridMismatch');
    fprintf('  [OK] grid mismatch (azGrid and percentiles) -> gridMismatch\n');

    % ===== 5. NaN handling =====
    Bn = A;
    Bn.values = A.values - 4;        % delta = +4 everywhere
    Bn.values(2, 2, 3) = NaN;        % inject a NaN in one cell/slice
    cmpN = comparePercentileMaps(A, Bn, 'Print', false);
    assert(isnan(cmpN.delta(2, 2, 3)), 'injected NaN preserved in delta');
    % slice 3 lost exactly one cell to NaN, the rest are +4.
    assert(cmpN.perPercentile.nNaN(3) == 1, 'nNaN for slice 3 must be 1');
    assert(sum(cmpN.perPercentile.nNaN) == 1, 'exactly one NaN total');
    assert(cmpN.summary.totalNaN == 1, 'summary.totalNaN must be 1');
    assert(all(isfinite([cmpN.perPercentile.maxAbs, cmpN.perPercentile.rms, ...
        cmpN.perPercentile.p95Abs, cmpN.perPercentile.meanBias, ...
        cmpN.perPercentile.std])), 'all per-percentile metrics finite');
    assert(abs(cmpN.perPercentile.meanBias(3) - 4) < 1e-12, ...
        'NaN excluded -> meanBias still +4');
    assert(isfinite(cmpN.summary.overallMaxAbs), 'overall metrics finite');
    fprintf('  [OK] NaN excluded from reductions, counted, metrics finite\n');

    % All-NaN slice -> NaN metrics for that slice (not an error).
    Ba = A; Ba.values = A.values - 1;
    Ba.values(:, :, 1) = NaN;
    cmpA = comparePercentileMaps(A, Ba, 'Print', false);
    assert(isnan(cmpA.perPercentile.maxAbs(1)), 'all-NaN slice -> NaN maxAbs');
    assert(cmpA.perPercentile.nNaN(1) == Naz * Nel, 'all-NaN slice count');
    assert(cmpA.perPercentile.nExceed(1) == 0, 'all-NaN slice -> 0 exceed');
    fprintf('  [OK] all-NaN slice -> NaN metrics, no error\n');

    % ===== 6. hand-checkable worst-case-per-direction (2x2x3) =====
    az6 = [0 10]; el6 = [0 5]; pct6 = [10 50 90];
    dA = zeros(2, 2, 3);
    dB = zeros(2, 2, 3);
    % Build deltas with a known per-direction argmax over p.
    % cell (1,1): deltas [+1 -7 +3] -> max|.| at p2, signed -7
    % cell (2,1): deltas [+8 -2 +5] -> max|.| at p1, signed +8
    % cell (1,2): deltas [-4 +6 -9] -> max|.| at p3, signed -9
    % cell (2,2): deltas [+2 +2 -2] -> max|.| at p1 (first), signed +2
    d = nan(2, 2, 3);
    d(1, 1, :) = [ 1 -7  3];
    d(2, 1, :) = [ 8 -2  5];
    d(1, 2, :) = [-4  6 -9];
    d(2, 2, :) = [ 2  2 -2];
    A6 = makePmaps(az6, el6, pct6, dA);
    B6 = makePmaps(az6, el6, pct6, dA - d);  % A - B = dA - (dA - d) = d
    cmp6 = comparePercentileMaps(A6, B6, 'Print', false);
    assert(isequal(cmp6.delta, d), 'delta cube must equal d');

    expSigned = [ -7  -9 ;  8   2 ];   % [(1,1) (1,2); (2,1) (2,2)]
    expMaxAbs = [  7   9 ;  8   2 ];
    assert(isequal(cmp6.worstCase.signedAtMaxAbs, expSigned), ...
        'signedAtMaxAbs mismatch');
    assert(isequal(cmp6.worstCase.maxAbsDelta, expMaxAbs), ...
        'maxAbsDelta mismatch');
    % Global worst cell = |delta|=9 at (1,2,3), signed -9.
    assert(cmp6.summary.worstCell.azIndex == 1 && ...
           cmp6.summary.worstCell.elIndex == 2 && ...
           cmp6.summary.worstCell.percentileIndex == 3, 'worstCell indices');
    assert(cmp6.summary.worstCell.value == -9, 'worstCell signed value');
    assert(cmp6.summary.worstCell.absValue == 9, 'worstCell abs value');
    assert(cmp6.summary.overallMaxAbs == 9, 'overallMaxAbs == 9');
    fprintf('  [OK] worst-case-per-direction argmax over p\n');

    % ===== bonus: pmaps-vs-runner mixing & Print smoke =====
    cmpMix = comparePercentileMaps(A, A, 'Print', true, ...
        'LabelA', 'CTIA 1x6', 'LabelB', 'ITU 1x3', 'ThresholdDb', 1);
    assert(strcmp(cmpMix.labelA, 'CTIA 1x6') && strcmp(cmpMix.labelB, 'ITU 1x3'), ...
        'labels echoed');
    assert(strcmp(cmpMix.meta.fieldUsed, 'pmaps'), 'pmaps input -> fieldUsed pmaps');
    fprintf('  [OK] labels + Print smoke test\n');

    results.passed = true;
    fprintf('--- test_comparePercentileMaps PASSED ---\n');
end

% =====================================================================

function pm = makePmaps(az, el, pct, values)
    pm = struct('percentiles', pct(:).', 'azGrid', az(:).', ...
        'elGrid', el(:).', 'values', values, ...
        'binEdges', []);
end

function pm = makePmapsUnits(az, el, pct, values, units)
    pm = makePmaps(az, el, pct, values);
    pm.units = units;
end
