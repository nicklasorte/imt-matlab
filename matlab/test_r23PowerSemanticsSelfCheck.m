function results = test_r23PowerSemanticsSelfCheck()
%TEST_R23POWERSEMANTICSSELFCHECK Focused unit tests for r23PowerSemanticsSelfCheck.
%
%   RESULTS = test_r23PowerSemanticsSelfCheck()
%
%   Covers:
%       1. PASS when observed equals expected per-beam peak (split case).
%       2. PASS when observed equals sector peak (no-split case).
%       3. WARN when observed is more than warn shortfall below expected
%          per-beam peak.
%       4. FAIL when observed exceeds sector peak by more than tolerance.
%       5. Returned struct contains expected*, observed*, peakShortfall_dB,
%          status and message fields.
%       6. Custom Tolerance_dB / WarnShortfall_dB name-value pairs are
%          honored.
%       7. Unknown name-value pair raises r23PowerSemanticsSelfCheck:badArgs.
%       8. Odd-length varargin raises r23PowerSemanticsSelfCheck:badArgs.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_r23PowerSemanticsSelfCheck ---\n');

    sectorPeak  = 78.3;
    perBeam     = 78.3 - 10*log10(3);   % 3 simultaneous beams ~ 73.53 dBm

    % ===== 1. PASS, split case =====
    ps = r23PowerSemanticsSelfCheck(perBeam, sectorPeak, perBeam, true);
    assert(strcmp(ps.status, 'pass'), ...
        'expected pass when observed == perBeam (split)');
    fprintf('  [OK] PASS when observed matches perBeam peak\n');

    % ===== 2. PASS, no-split case =====
    ps = r23PowerSemanticsSelfCheck(sectorPeak, sectorPeak, sectorPeak, false);
    assert(strcmp(ps.status, 'pass'), ...
        'expected pass when observed == sectorPeak (no split)');
    fprintf('  [OK] PASS when observed matches sectorPeak (no split)\n');

    % ===== 3. WARN: observed well below perBeam peak =====
    observed = perBeam - 5.0;   % 5 dB shortfall (default warn = 3 dB)
    ps = r23PowerSemanticsSelfCheck(observed, sectorPeak, perBeam, true);
    assert(strcmp(ps.status, 'warn'), ...
        'expected warn for 5 dB shortfall, got %s', ps.status);
    assert(ps.peakShortfall_dB > 3 - 1e-9, 'peakShortfall_dB must reflect 5 dB');
    fprintf('  [OK] WARN when shortfall > WarnShortfall_dB threshold\n');

    % ===== 4. FAIL: observed exceeds sector peak =====
    observed = sectorPeak + 0.1;
    ps = r23PowerSemanticsSelfCheck(observed, sectorPeak, perBeam, true);
    assert(strcmp(ps.status, 'fail'), ...
        'expected fail for observed > sectorPeak + tol');
    fprintf('  [OK] FAIL when observed exceeds sector peak\n');

    % ===== 5. struct field set =====
    expected = {'expectedSectorPeakEirp_dBm','expectedPerBeamPeakEirp_dBm', ...
                'observedMaxGridEirp_dBm','peakShortfall_dB', ...
                'tolerance_dB','warnShortfallThreshold_dB', ...
                'splitSectorPower','status','message'};
    for k = 1:numel(expected)
        assert(isfield(ps, expected{k}), 'missing field "%s"', expected{k});
    end
    assert(ischar(ps.message) && ~isempty(ps.message), ...
        'message must be a non-empty char');
    fprintf('  [OK] expected output struct field set\n');

    % ===== 6. custom Tolerance_dB / WarnShortfall_dB =====
    ps = r23PowerSemanticsSelfCheck(perBeam - 1.0, sectorPeak, perBeam, true, ...
        'Tolerance_dB', 1e-3, 'WarnShortfall_dB', 0.5);
    assert(strcmp(ps.status, 'warn'), ...
        'lowered WarnShortfall_dB must fire warn earlier');
    assert(abs(ps.tolerance_dB - 1e-3) < 1e-12);
    assert(abs(ps.warnShortfallThreshold_dB - 0.5) < 1e-12);
    fprintf('  [OK] custom Tolerance_dB and WarnShortfall_dB honored\n');

    % ===== 7. unknown name-value pair =====
    threw = false;
    try
        r23PowerSemanticsSelfCheck(perBeam, sectorPeak, perBeam, true, ...
            'BogusOption', 1); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'r23PowerSemanticsSelfCheck:badArgs'), ...
            'expected badArgs, got %s', err.identifier);
    end
    assert(threw, 'unknown option must error');
    fprintf('  [OK] unknown option raises badArgs\n');

    % ===== 8. odd-length varargin =====
    threw = false;
    try
        r23PowerSemanticsSelfCheck(perBeam, sectorPeak, perBeam, true, ...
            'Tolerance_dB'); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'r23PowerSemanticsSelfCheck:badArgs'), ...
            'expected badArgs, got %s', err.identifier);
    end
    assert(threw, 'odd-length varargin must error');
    fprintf('  [OK] odd-length varargin raises badArgs\n');

    results.passed = true;
    fprintf('--- test_r23PowerSemanticsSelfCheck PASSED ---\n');
end
