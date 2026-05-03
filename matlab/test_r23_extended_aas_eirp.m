function results = test_r23_extended_aas_eirp()
%TEST_R23_EXTENDED_AAS_EIRP Self tests for the R23 extended AAS path.
%
%   Covers:
%       E1. With cfg.patternModel = 'r23_extended_aas',
%           [eirp,gain] = imt_aas_bs_eirp(0,-9, 0,-9, cfg)
%           returns gain ~= 32.2 dBi and eirp ~= 78.3 dBm/100MHz.
%       E2. A small grid around the beam direction returns finite
%           gain / EIRP.
%       E3. Backwards-compat parity: with sub-array degenerate
%           (numVerticalElements = 1, d_V = 0, downtiltDeg = 0,
%           mechanicalDowntiltDeg = 0, normalizeToPeakGain = false), the
%           extended pattern equals imt2020_composite_pattern to within
%           1e-9 dB on a near-boresight grid.
%       E4. imt_r23_aas_eirp_grid returns shape [Naz x Nel] and includes
%           eirp_dBW_perHz; gain peaks near the beam direction.
%       E5. run_imt_aas_eirp_monte_carlo accepts cfg = imt_r23_aas_defaults
%           with a fixed beamSampler.

    results.summary = {};
    results.passed  = true;

    cfg = imt_r23_aas_defaults('macroUrban');

    % ====================================================================
    % E1. peak gain / EIRP at the (panel-frame) beam direction
    % ====================================================================
    [eirp, gain] = imt_aas_bs_eirp(0, -9, 0, -9, cfg);
    % Observation == beam direction with normalizeToPeakGain = true,
    % so gain must equal cfg.peakGain_dBi to floating-point precision.
    results = check(results, abs(gain - 32.2) < 1e-6, ...
        sprintf('gain at beam dir = %.6f dBi, expected 32.2 (tol 1e-6)', gain));
    results = check(results, abs(eirp - 78.3) < 1e-6, ...
        sprintf('EIRP at beam dir = %.6f dBm, expected 78.3 (tol 1e-6)', eirp));

    % ====================================================================
    % E2. small grid around the beam returns finite values
    % ====================================================================
    azGrid = -10:1:10;
    elGrid = -15:1:-3;
    [AZ, EL] = ndgrid(azGrid, elGrid);
    [eirpGrid, gainGrid] = imt_aas_bs_eirp(AZ, EL, 0, -9, cfg);

    results = check(results, all(isfinite(gainGrid(:))), ...
        'composite extended gain is finite over the near-beam grid');
    results = check(results, all(isfinite(eirpGrid(:))), ...
        'EIRP is finite over the near-beam grid');

    % peak gain should be within 0.1 dB of cfg.peakGain_dBi for this
    % near-beam grid (panel-frame element pattern is nearly flat here).
    results = check(results, abs(max(gainGrid(:)) - 32.2) < 0.1, ...
        sprintf('peak gain on small grid = %.4f dBi, expected ~32.2 (tol 0.1)', ...
            max(gainGrid(:))));

    % ====================================================================
    % E3. backwards-compat parity vs imt2020_composite_pattern
    % ====================================================================
    parity = struct();
    parity.G_Emax    = 8;
    parity.A_m       = 30;
    parity.SLA_nu    = 30;
    parity.phi_3db   = 65;
    parity.theta_3db = 65;
    parity.d_H       = 0.5;
    parity.d_V       = 0.5;
    parity.N_H       = 8;
    parity.N_V       = 8;
    parity.rho       = 1;
    parity.k         = 12;
    parity.subarray.numVerticalElements = 1;
    parity.subarray.d_V                  = 0;
    parity.subarray.downtiltDeg          = 0;
    parity.mechanicalDowntiltDeg         = 0;
    parity.normalizeToPeakGain           = false;
    parity.peakGain_dBi                  = 0;

    azParity = -20:2:20;
    elParity = -10:2:10;
    [AZp, ELp] = ndgrid(azParity, elParity);

    A_simple = imt2020_composite_pattern(AZp, ELp, 0, 0, ...
        parity.G_Emax, parity.A_m, parity.SLA_nu, ...
        parity.phi_3db, parity.theta_3db, ...
        parity.d_H, parity.d_V, parity.N_H, parity.N_V, ...
        parity.rho, parity.k);
    A_ext = imt2020_composite_pattern_extended(AZp, ELp, 0, 0, parity);

    diff = A_ext - A_simple;
    finiteMask = isfinite(diff);
    if any(finiteMask(:))
        maxAbs = max(abs(diff(finiteMask)));
    else
        maxAbs = inf;
    end
    results = check(results, maxAbs <= 1e-9, ...
        sprintf(['extended pattern matches imt2020_composite_pattern in '...
                 'degenerate config (maxAbs = %.3e dB, tol 1e-9)'], maxAbs));

    % ====================================================================
    % E4. imt_r23_aas_eirp_grid shape + eirp_dBW_perHz
    % ====================================================================
    % use a grid that includes the beam-pointing elevation (-9 deg) so
    % the on-grid peak coincides with the antenna-frame peak.
    azGrid4 = -180:5:180;
    elGrid4 = sort(unique([-90:5:30, -9]));
    out = imt_r23_aas_eirp_grid(azGrid4, elGrid4, cfg);

    Naz = numel(azGrid4);
    Nel = numel(elGrid4);
    results = check(results, ...
        isequal(size(out.gain_dBi), [Naz, Nel]), ...
        sprintf('gain_dBi has shape [%d x %d]', Naz, Nel));
    results = check(results, ...
        isequal(size(out.eirp_dBm_per100MHz), [Naz, Nel]), ...
        sprintf('eirp_dBm_per100MHz has shape [%d x %d]', Naz, Nel));
    results = check(results, isfield(out, 'eirp_dBW_perHz') && ...
        isequal(size(out.eirp_dBW_perHz), [Naz, Nel]), ...
        sprintf('eirp_dBW_perHz has shape [%d x %d]', Naz, Nel));

    % spectral-density conversion
    expected = out.eirp_dBm_per100MHz - 30 - 10 * log10(cfg.bandwidthMHz * 1e6);
    convDiff = max(abs(out.eirp_dBW_perHz(:) - expected(:)));
    results = check(results, convDiff < 1e-9, ...
        sprintf('eirp_dBW_perHz matches spectral-density formula (max diff %.3e)', ...
            convDiff));

    % default beam pointing
    results = check(results, out.beamAzimDeg == 0, ...
        sprintf('beamAzimDeg = %.6f, expected 0', out.beamAzimDeg));
    results = check(results, abs(out.beamElevDeg - (-9)) < 1e-12, ...
        sprintf('beamElevDeg = %.6f, expected -9', out.beamElevDeg));

    % peak EIRP near 78.3 dBm/100MHz
    results = check(results, abs(max(out.eirp_dBm_per100MHz(:)) - 78.3) < 0.1, ...
        sprintf('peak EIRP on full grid = %.4f dBm, expected ~78.3 (tol 0.1)', ...
            max(out.eirp_dBm_per100MHz(:))));

    % ====================================================================
    % E5. Monte Carlo runner accepts the R23 cfg with a fixed beamSampler
    % ====================================================================
    mcOpts = struct();
    mcOpts.numMc       = 4;
    mcOpts.azGrid      = -30:5:30;
    mcOpts.elGrid      = -15:5:0;
    mcOpts.binEdges    = -50:5:120;
    mcOpts.beamSampler = struct('mode', 'fixed', ...
        'azim_i', 0, 'elev_i', -9, 'numBeams', 1);
    mcOpts.seed        = 7;

    threw = false;
    mcMsg = '';
    stats = [];
    try
        stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    catch err
        threw = true;
        mcMsg = err.message;
    end
    results = check(results, ~threw, ...
        sprintf('run_imt_aas_eirp_monte_carlo accepts R23 cfg + fixed beam (err: "%s")', mcMsg));

    if ~threw
        results = check(results, ...
            isequal(size(stats.max_dBm), [numel(mcOpts.azGrid), numel(mcOpts.elGrid)]), ...
            'MC stats.max_dBm has the right shape');
        results = check(results, all(isfinite(stats.max_dBm(:))), ...
            'MC stats.max_dBm is finite');
        % all draws are at the same beam, so min == max per cell
        results = check(results, max(abs(stats.max_dBm(:) - stats.min_dBm(:))) < 1e-9, ...
            'fixed-beam MC gives identical min and max per cell');
    end

    fprintf('\n--- test_r23_extended_aas_eirp summary ---\n');
    for i = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{i});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  TESTS FAILED\n');
    end
end

function results = check(results, condition, msg)
    if condition
        tag = 'PASS';
    else
        tag = 'FAIL';
        results.passed = false;
    end
    line = sprintf('[%s] %s', tag, msg);
    fprintf('  %s\n', line);
    results.summary{end + 1} = line; %#ok<*AGROW>
end
