function results = test_r23_power_semantics()
%TEST_R23_POWER_SEMANTICS Power-semantics regression gate for R23 AAS EIRP.
%
%   RESULTS = test_r23_power_semantics()
%
%   Authoritative regression for the R23 macro 7.125-8.4 GHz reference:
%
%       maxEirpPerSector_dBm = 78.3   sector peak EIRP [dBm / 100 MHz]
%       conductedPower_dBm   = 46.1   conducted BS power [dBm / 100 MHz]
%       peakGain_dBi         = 32.2   composite peak gain [dBi]
%       46.1 + 32.2 = 78.3
%
%   The runR23AasEirpCdfGrid -> imtAasSectorEirpGridFromBeams ->
%   imtAasEirpGrid path uses the canonical "maxEirp + relativeGainOffset"
%   form:
%
%       eirpGridDbm = sectorEirpDbm + (compositeGainDbi - max(compositeGainDbi))
%
%   so the in-grid peak EIRP equals sectorEirpDbm exactly. Per-beam
%   power-splitting reduces sectorEirpDbm by 10*log10(numBeams) BEFORE
%   the peak-normalization. The path NEVER computes
%   maxEirpPerSector_dBm + gain(direction).
%
%   imt_aas_bs_eirp.m / run_imt_aas_eirp_monte_carlo (the legacy
%   Extended-AAS Monte Carlo runner) uses the alternative canonical form
%       eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB,
%   with the extended-pattern gain renormalised so the panel-frame main-
%   lobe peak equals peakGain_dBi exactly.
%
%   Invariants exercised:
%       S1. r23DefaultParams: defaults equal 78.3 / 46.1 / 32.2 and the
%           identity 46.1 + 32.2 == 78.3 holds within tolerance.
%       S2. imtAasDefaultParams agrees with the same constants.
%       S3. With splitSectorPower=false and one UE/beam, the maximum EIRP
%           over the grid does not exceed maxEirpPerSector_dBm by more than
%           a small numerical tolerance. The same holds for the streaming
%           Monte Carlo (max across cells of stats.max_dBm).
%       S4. With maxEirpPerSector_dBm changed by +X dB, the resulting EIRP
%           grid shifts by +X dB, NOT by +X plus antenna gain. Verified for
%           both the deterministic per-call EIRP grid and the streaming
%           mean-EIRP grid.
%       S5. No output EIRP value is consistent with
%           maxEirpPerSector_dBm + peakGain_dBi. Specifically the maximum
%           EIRP over the streaming run stays well below 78.3 + 32.2 = 110.5.
%       S6. With splitSectorPower=true and N UEs the per-beam peak is
%           reduced by 10*log10(N) (the documented split rule) and N
%           identical co-pointed beams sum back to the full sectorEirpDbm.
%       S7. The pointing heatmap is in degrees (not dBm), reports the beam
%           pointing angle (not the observation grid), uses an azimuth
%           circular mean, has dimensions matching the EIRP grid, and is
%           bounded by the sector steering convention.
%
%   Returns struct with .summary (cellstr) and .passed (logical), matching
%   the run_all_tests harness.

    results.summary = {};
    results.passed  = true;

    results = s1_default_constants(results);
    results = s2_flat_params_agree(results);
    results = s3_max_eirp_does_not_exceed_sector_peak(results);
    results = s4_eirp_shifts_one_to_one_with_max_eirp(results);
    results = s5_no_double_counted_value(results);
    results = s6_per_beam_split_rule(results);
    results = s7_pointing_heatmap_metadata(results);

    fprintf('\n--- test_r23_power_semantics summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function r = s1_default_constants(r)
    p = r23DefaultParams();

    okMaxEirp = abs(p.bs.maxEirpPerSector_dBm - 78.3) < 1e-12;
    okConducted = abs(p.bs.conductedPower_dBm - 46.1) < 1e-12;
    okPeakGain = abs(p.bs.peakGain_dBi - 32.2) < 1e-12;

    sumIdentity = p.bs.conductedPower_dBm + p.bs.peakGain_dBi;
    okIdentity = abs(sumIdentity - p.bs.maxEirpPerSector_dBm) < 1e-9;

    okAll = okMaxEirp && okConducted && okPeakGain && okIdentity;
    r = check(r, okAll, sprintf( ...
        ['S1: r23DefaultParams: maxEirp=%.6f (78.3), conducted=%.6f (46.1), ' ...
         'peakGain=%.6f (32.2), 46.1+32.2 = %.6f (=78.3)'], ...
         p.bs.maxEirpPerSector_dBm, p.bs.conductedPower_dBm, ...
         p.bs.peakGain_dBi, sumIdentity));
end

% =====================================================================

function r = s2_flat_params_agree(r)
    flat = imtAasDefaultParams();
    okFlatSector  = abs(flat.sectorEirpDbm        - 78.3) < 1e-12;
    okFlatTx      = abs(flat.txPowerDbmPer100MHz  - 46.1) < 1e-12;
    okFlatPeakG   = abs(flat.peakGainDbi          - 32.2) < 1e-12;
    okFlatId      = abs((flat.txPowerDbmPer100MHz + flat.peakGainDbi) - ...
                         flat.sectorEirpDbm) < 1e-9;

    % Cross-check the nested-to-flat adapter agrees too.
    flatFromNested = r23ToImtAasParams(r23DefaultParams());
    okAdapter = abs(flatFromNested.sectorEirpDbm       - 78.3) < 1e-12 && ...
                abs(flatFromNested.txPowerDbmPer100MHz - 46.1) < 1e-12 && ...
                abs(flatFromNested.peakGainDbi         - 32.2) < 1e-12;

    okAll = okFlatSector && okFlatTx && okFlatPeakG && okFlatId && okAdapter;
    r = check(r, okAll, ...
        'S2: imtAasDefaultParams + r23ToImtAasParams agree on 78.3 / 46.1 / 32.2');
end

% =====================================================================

function r = s3_max_eirp_does_not_exceed_sector_peak(r)
    % --- (a) Deterministic single-beam, no split -------------------------
    % Use a fine grid that surrounds the steered direction so the
    % composite-gain peak is well sampled.
    azGrid = -60:1:60;     % 121 cells
    elGrid = -10:0.5:0;    % 21 cells
    steerAz = 0;
    steerEl = -9;
    p = imtAasDefaultParams();

    beams1 = struct('steerAzDeg', steerAz, 'steerElDeg', steerEl);
    out1 = imtAasSectorEirpGridFromBeams(azGrid, elGrid, beams1, p, ...
        struct('splitSectorPower', false));

    sectorPeak = p.sectorEirpDbm;        % 78.3 dBm by default
    tol = 1e-6;
    detMax = max(out1.aggregateEirpDbm(:));
    okDeterministic = detMax <= sectorPeak + tol;

    % --- (b) Streaming Monte Carlo, splitSectorPower=false, 1 UE ---------
    out2 = runR23AasEirpCdfGrid( ...
        'numUesPerSector',   1, ...
        'splitSectorPower',  false, ...
        'numMc',             8, ...
        'azGridDeg',         azGrid, ...
        'elGridDeg',         elGrid, ...
        'binEdgesDbm',       -80:1:120, ...
        'percentiles',       [50 95], ...
        'seed',              17);
    streamMax = max(out2.stats.max_dBm(:));
    okStreaming = streamMax <= sectorPeak + tol;

    okAll = okDeterministic && okStreaming;
    r = check(r, okAll, sprintf( ...
        ['S3: maxEirp does not exceed sector peak (deterministic=%.6f dBm, ' ...
         'streaming=%.6f dBm, sectorPeak=%.6f dBm, tol=%.1e)'], ...
        detMax, streamMax, sectorPeak, tol));
end

% =====================================================================

function r = s4_eirp_shifts_one_to_one_with_max_eirp(r)
    % --- (a) Deterministic per-grid shift ------------------------------
    azGrid = -60:5:60;
    elGrid = -10:1:0;
    p = imtAasDefaultParams();

    beams = struct('steerAzDeg', 0, 'steerElDeg', -9);
    optsA = struct('splitSectorPower', false, 'sectorEirpDbm', 78.3);
    optsB = struct('splitSectorPower', false, 'sectorEirpDbm', 75.0);

    outA = imtAasSectorEirpGridFromBeams(azGrid, elGrid, beams, p, optsA);
    outB = imtAasSectorEirpGridFromBeams(azGrid, elGrid, beams, p, optsB);

    expectedDelta = 75.0 - 78.3;        % -3.3 dB
    delta = outB.aggregateEirpDbm - outA.aggregateEirpDbm;
    finiteDelta = delta(isfinite(delta));
    okDeterministic = ~isempty(finiteDelta) && ...
        all(abs(finiteDelta - expectedDelta) < 1e-9);

    % --- (b) Streaming Monte Carlo shift -------------------------------
    smallOpts = struct( ...
        'numMc',         6, ...
        'numUesPerSector', 1, ...
        'splitSectorPower', false, ...
        'azGridDeg',     azGrid, ...
        'elGridDeg',     elGrid, ...
        'binEdgesDbm',   -80:1:120, ...
        'percentiles',   [50 95], ...
        'seed',          21);

    optsHigh = smallOpts; optsHigh.maxEirpPerSector_dBm = 78.3;
    optsLow  = smallOpts; optsLow.maxEirpPerSector_dBm  = 75.0;

    outHi = runR23AasEirpCdfGrid(optsHigh);
    outLo = runR23AasEirpCdfGrid(optsLow);

    deltaMean = outLo.stats.mean_dBm - outHi.stats.mean_dBm;
    finiteMean = deltaMean(isfinite(deltaMean));
    okStreaming = ~isempty(finiteMean) && ...
        all(abs(finiteMean - expectedDelta) < 1e-6);

    % --- (c) Anti-double-count: the shift must NOT include the gain ----
    % If the code did EIRP = maxEirp + gain, a +X dB shift in maxEirp
    % would still produce a +X dB shift in EIRP - so the +X invariant
    % alone does not catch double-counting. Pin the absolute peak
    % instead: the streaming Monte Carlo max (1 beam, no split) must
    % equal exactly maxEirpPerSector_dBm to high precision, NOT
    % maxEirpPerSector_dBm + peakGain_dBi.
    streamMaxHi = max(outHi.stats.max_dBm(:));
    streamMaxLo = max(outLo.stats.max_dBm(:));
    okPeakHi = abs(streamMaxHi - 78.3) < 1e-6;
    okPeakLo = abs(streamMaxLo - 75.0) < 1e-6;

    okAll = okDeterministic && okStreaming && okPeakHi && okPeakLo;
    r = check(r, okAll, sprintf( ...
        ['S4: +X dB shift in maxEirp gives exactly +X dB shift in EIRP ' ...
         '(det median delta=%.6f, stream median delta=%.6f, peakHi=%.6f, peakLo=%.6f)'], ...
        median(finiteDelta), median(finiteMean), streamMaxHi, streamMaxLo));
end

% =====================================================================

function r = s5_no_double_counted_value(r)
    % If any code path computed eirp = maxEirpPerSector + peakGain, the
    % maximum EIRP over the streaming run would be ~110.5 dBm. Verify it
    % is bounded well below that, even with multiple snapshots and
    % multiple beams.
    out = runR23AasEirpCdfGrid( ...
        'numUesPerSector', 3, ...
        'numMc',           20, ...
        'azGridDeg',       -60:5:60, ...
        'elGridDeg',       -10:1:0, ...
        'binEdgesDbm',     -80:1:120, ...
        'percentiles',     [50 95], ...
        'seed',            33);

    sectorPeak = out.stats.sectorEirpDbm;        % 78.3
    peakGain   = imtAasDefaultParams().peakGainDbi;   % 32.2
    doubleCountedValue = sectorPeak + peakGain;       % 110.5

    streamMax = max(out.stats.max_dBm(:));
    tol = 1e-6;

    % Sector peak EIRP is the absolute upper bound for any antenna-face
    % output cell across any beam configuration in this MVP (the
    % aggregate of N identical beams equals sectorEirpDbm exactly, no
    % constructive overshoot is possible because per-beam grids share
    % one peak normalization).
    okBounded = streamMax <= sectorPeak + tol;

    % And the streamMax must be at least 30 dB below the double-counted
    % value (huge guard band - the actual gap should be exactly 32.2 dB).
    okGap = (doubleCountedValue - streamMax) > 30;

    okAll = okBounded && okGap;
    r = check(r, okAll, sprintf( ...
        ['S5: no value consistent with double-counted maxEirp+peakGain=%.3f ' ...
         '(streamMax=%.6f, sectorPeak=%.3f, gap=%.3f dB)'], ...
        doubleCountedValue, streamMax, sectorPeak, ...
        doubleCountedValue - streamMax));
end

% =====================================================================

function r = s6_per_beam_split_rule(r)
    azGrid = -60:1:60;
    elGrid = -10:0.5:0;
    p = imtAasDefaultParams();

    Nlist = [1 2 3 5];
    okList = false(size(Nlist));
    okAggList = false(size(Nlist));
    for j = 1:numel(Nlist)
        N = Nlist(j);
        % N identical co-pointed beams.
        beams = struct( ...
            'steerAzDeg', repmat(0,  N, 1), ...
            'steerElDeg', repmat(-9, N, 1));
        out = imtAasSectorEirpGridFromBeams(azGrid, elGrid, beams, p, ...
            struct('splitSectorPower', true));

        expectedPerBeamPeak = p.sectorEirpDbm - 10 * log10(N);
        okList(j) = abs(out.perBeamPeakEirpDbm - expectedPerBeamPeak) < 1e-9;

        % N identical beams aggregate by linear-mW summation back to
        % the full sectorEirpDbm.
        okAggList(j) = abs(max(out.aggregateEirpDbm(:)) - p.sectorEirpDbm) ...
                       < 1e-6;
    end

    okAll = all(okList) && all(okAggList);
    r = check(r, okAll, sprintf( ...
        ['S6: split rule perBeamPeak = sectorEirp - 10*log10(N) holds ' ...
         'for N=[1 2 3 5]; N identical beams sum back to sectorEirp ' ...
         '(perBeamOK=%s, aggOK=%s)'], ...
        mat2str(okList), mat2str(okAggList)));
end

% =====================================================================

function r = s7_pointing_heatmap_metadata(r)
    azGrid = -30:10:30;
    elGrid = -10:5:0;
    out = runR23AasEirpCdfGrid( ...
        'numUesPerSector',         3, ...
        'numMc',                   4, ...
        'azGridDeg',               azGrid, ...
        'elGridDeg',               elGrid, ...
        'binEdgesDbm',             -80:1:120, ...
        'percentiles',             [50 95], ...
        'seed',                    101, ...
        'computePointingHeatmap',  true);

    Naz = numel(azGrid);
    Nel = numel(elGrid);

    pt = out.pointing;

    okAzShape = isequal(size(pt.azimuthDegGrid),   [Naz, Nel]);
    okElShape = isequal(size(pt.elevationDegGrid), [Naz, Nel]);
    okMatchesEirp = isequal(size(pt.azimuthDegGrid), size(out.stats.mean_dBm));

    okUnits = isfield(pt, 'units') && ischar(pt.units) && ...
              strcmpi(pt.units, 'degrees');

    okAzConv = isfield(pt, 'azWrappedConvention') && ...
               ischar(pt.azWrappedConvention) && ...
               ~isempty(strfind(lower(pt.azWrappedConvention), 'circular')); %#ok<STREMP>

    okStat = isfield(pt, 'summaryStatistic') && ...
             ~isempty(pt.summaryStatistic);

    % Pointing must be in degrees, NOT dBm. The values must lie inside
    % the sector steering envelope (azimuth in [-60, 60], elevation in
    % [-10, 0] for the R23 macro defaults). Any value far outside that
    % envelope (e.g. >= 60 dBm-style values) would indicate the
    % heatmap has been confused with EIRP.
    az = pt.azimuthDegGrid;
    el = pt.elevationDegGrid;
    azFinite = az(isfinite(az));
    elFinite = el(isfinite(el));

    azLim = out.sector.azLimitsDeg;
    elLim = out.sector.elLimitsDeg;
    tol = 1e-6;

    okAzBounds = isempty(azFinite) || ...
        (min(azFinite) >= azLim(1) - tol && ...
         max(azFinite) <= azLim(2) + tol);
    okElBounds = isempty(elFinite) || ...
        (min(elFinite) >= elLim(1) - tol && ...
         max(elFinite) <= elLim(2) + tol);

    % And: no pointing value is within 10 dB of typical EIRP magnitudes,
    % i.e. all finite values are << 60 deg and << 78.3 (units guard).
    okNotEirpLike = isempty(azFinite) || ...
        (max(abs(azFinite)) <= 60 + tol);

    okAll = okAzShape && okElShape && okMatchesEirp && okUnits && ...
            okAzConv && okStat && okAzBounds && okElBounds && okNotEirpLike;
    r = check(r, okAll, sprintf( ...
        ['S7: pointing heatmap shape [%d %d], units=degrees, az circular-mean ' ...
         'convention, az in [%g,%g], el in [%g,%g], summaryStatistic=%s'], ...
        Naz, Nel, azLim(1), azLim(2), elLim(1), elLim(2), pt.summaryStatistic));
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
