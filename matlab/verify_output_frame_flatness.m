function results = verify_output_frame_flatness(outDir)
%VERIFY_OUTPUT_FRAME_FLATNESS Verify the outputFrame option: panel (flat) vs
%   global (curved) az/el EIRP maps.
%
%   RESULTS = verify_output_frame_flatness()
%   RESULTS = verify_output_frame_flatness(OUTDIR)
%
%   Runs the R23 AAS EIRP pipeline in BOTH observation frames on the
%   deterministic path (imt_r23_aas_eirp_grid) and the Monte-Carlo path
%   (runR23AasEirpCdfGrid), confirms that:
%
%       outputFrame = 'global' (default)  -> CURVED maps (mechanical-tilt
%                                            rotation of the observation grid;
%                                            ITU-R IMT char. Note 8 /
%                                            3GPP TR 36.814 A.2.1.6.2)
%       outputFrame = 'panel'             -> FLAT maps (un-rotated panel frame)
%
%   and saves side-by-side PNGs plus a printed flatness table. This is a
%   self-contained verification/demo script; it edits nothing and is not part
%   of run_all_tests. It pins the path to THIS checkout so it never resolves a
%   shadowed copy of the pipeline from another folder on the MATLAB path.
%
%   Flatness metric (deterministic): the repo main-lobe RIDGE spread (an exact
%   copy of test_output_frame.m's ridgeSpreadDeg) -- the elevation of the main
%   lobe, windowed around the global map peak, tracked across azimuth. Panel
%   stays flat (~0); global curves. The main lobe is used so array nulls and
%   grating lobes do not enter the metric.
%
%   Flatness metric (Monte-Carlo): deepest-null elevation spread of the p50
%   map across azimuth. The MC p50 averages over many random beam azimuths,
%   which smears the sharp azimuth nulls, so the deepest null is a stable
%   elevation feature here (flat in panel, strongly curved in global).
%
%   OUTDIR defaults to fullfile(tempdir, 'output_frame_check').
%
%   See also: runR23AasEirpCdfGrid, imt_r23_aas_eirp_grid, test_output_frame.

    % ---- pin path to this checkout (avoid shadowed copies) --------------
    thisFile  = mfilename('fullpath');
    matlabDir = fileparts(thisFile);
    repoRoot  = fileparts(matlabDir);
    addpath(genpath(matlabDir));
    resolved = which('runR23AasEirpCdfGrid');
    assert(contains(resolved, matlabDir), ...
        'Resolved the wrong runR23AasEirpCdfGrid: %s', resolved);

    if nargin < 1 || isempty(outDir)
        outDir = fullfile(tempdir, 'output_frame_check');
    end
    if exist(outDir, 'dir') ~= 7; mkdir(outDir); end

    fprintf('verify_output_frame_flatness\n');
    fprintf('  checkout : %s\n', repoRoot);
    fprintf('  pipeline : %s\n', resolved);
    fprintf('  outDir   : %s\n\n', outDir);

    az     = -120:2:120;
    el     = -30:2:30;
    preset = 'ctia_7ghz_1x6';
    cover  = 60;     % flatness region |az| <= 60 deg
    win    = 6;      % main-lobe window for the ridge metric

    rows = {};   % {method, frame, metric, spreadDeg}
    pass = true;

    % ================= (A) DETERMINISTIC ridge flatness =================
    % Grid matched to test_output_frame T8 for the ridge metric.
    azDet = -120:5:120;  elDet = -30:1:30;  gridStep = 1;
    cfgR = imt_r23_aas_defaults('macroUrban');                       % 8x16, L=3
    cfgC = cfgR; cfgC.N_V = 4; cfgC.d_V = 4.2; ...                   % ctia 4x16, L=6
        cfgC.subarray.numVerticalElements = 6;

    detGeoms = {'r23_default', cfgR; 'ctia_7ghz_1x6', cfgC};
    for gi = 1:size(detGeoms, 1)
        name = detGeoms{gi, 1}; cfg = detGeoms{gi, 2};
        cfgG = cfg; cfgG.observationFrame = 'global';
        cfgP = cfg; cfgP.observationFrame = 'panel';
        gG = imt_r23_aas_eirp_grid(azDet, elDet, cfgG);
        gP = imt_r23_aas_eirp_grid(azDet, elDet, cfgP);
        sG = ridgeSpreadDeg(gG.gain_dBi, azDet, elDet, win, cover);
        sP = ridgeSpreadDeg(gP.gain_dBi, azDet, elDet, win, cover);
        rows(end+1, :) = {['det:' name], 'global', 'ridge', sG}; %#ok<AGROW>
        rows(end+1, :) = {['det:' name], 'panel',  'ridge', sP}; %#ok<AGROW>
        okPanelFlat    = sP <= 1.0 * gridStep;
        okGlobalCurved = sG >= 2.0 * gridStep && sG >= sP + 1.0;
        pass = pass && okPanelFlat && okGlobalCurved;
    end

    % ================= (B) MONTE-CARLO p50 flatness ====================
    optsBase = struct('aasGeometryPreset', preset, 'numMc', 2000, ...
        'seed', 19, 'azGridDeg', az, 'elGridDeg', el);
    optsG = optsBase; optsG.outputFrame = 'global';
    optsP = optsBase; optsP.outputFrame = 'panel';
    rG = runR23AasEirpCdfGrid(optsG);
    rP = runR23AasEirpCdfGrid(optsP);
    fprintf('\nMC metadata.outputFrame echo: global-run=''%s''  panel-run=''%s''\n', ...
        rG.metadata.outputFrame, rP.metadata.outputFrame);

    p50G = p50Slice(rG.percentileMaps);
    p50P = p50Slice(rP.percentileMaps);
    sMcG = nullElevSpread(p50G, az, el, cover);
    sMcP = nullElevSpread(p50P, az, el, cover);
    rows(end+1, :) = {'mc:ctia_7ghz_1x6', 'global', 'null', sMcG};
    rows(end+1, :) = {'mc:ctia_7ghz_1x6', 'panel',  'null', sMcP};
    pass = pass && (sMcP <= 2 * 2) && (sMcG >= 6) && (sMcG >= sMcP + 4);

    % ========================= PLOTS ====================================
    % Seven PNGs are written to OUTDIR:
    %   det_global.png / det_panel.png            R23-default deterministic EIRP
    %   mc_global_p50.png / mc_panel_p50.png      Monte-Carlo p50 EIRP
    %   det_ctia_global.png / det_ctia_panel.png  ctia deterministic gain
    %   compare_frames.png                        combined 2x2 (det EIRP + mc p50)

    % (1-2) Deterministic R23-default EIRP maps [dBm / 100 MHz].
    cfgRG = cfgR; cfgRG.observationFrame = 'global';
    cfgRP = cfgR; cfgRP.observationFrame = 'panel';
    eRG = imt_r23_aas_eirp_grid(az, el, cfgRG);
    eRP = imt_r23_aas_eirp_grid(az, el, cfgRP);
    ZdetG = eRG.eirp_dBm_per100MHz;
    ZdetP = eRP.eirp_dBm_per100MHz;
    detEirpClim = [ZdetG(:); ZdetP(:)];
    saveMap(ZdetG, az, el, 'Deterministic EIRP - global (curved)', ...
        fullfile(outDir, 'det_global.png'), detEirpClim, 'EIRP [dBm]');
    saveMap(ZdetP, az, el, 'Deterministic EIRP - panel (flat)', ...
        fullfile(outDir, 'det_panel.png'),  detEirpClim, 'EIRP [dBm]');

    % (3-4) Monte-Carlo p50 EIRP maps [dBm].
    mcClimData = [p50G(:); p50P(:)];
    saveMap(p50G, az, el, 'Monte-Carlo p50 EIRP - global (curved)', ...
        fullfile(outDir, 'mc_global_p50.png'), mcClimData, 'EIRP [dBm]');
    saveMap(p50P, az, el, 'Monte-Carlo p50 EIRP - panel (flat)', ...
        fullfile(outDir, 'mc_panel_p50.png'),  mcClimData, 'EIRP [dBm]');

    % (5-6) Deterministic ctia-geometry composite-gain maps [dBi] (finer el).
    elCtia = -30:1:30;
    cfgCG = cfgC; cfgCG.observationFrame = 'global';
    cfgCP = cfgC; cfgCP.observationFrame = 'panel';
    dCG = imt_r23_aas_eirp_grid(az, elCtia, cfgCG);
    dCP = imt_r23_aas_eirp_grid(az, elCtia, cfgCP);
    detGainClim = [dCG.gain_dBi(:); dCP.gain_dBi(:)];
    saveMap(dCG.gain_dBi, az, elCtia, 'Deterministic ctia gain - global (curved)', ...
        fullfile(outDir, 'det_ctia_global.png'), detGainClim, 'Gain [dBi]');
    saveMap(dCP.gain_dBi, az, elCtia, 'Deterministic ctia gain - panel (flat)', ...
        fullfile(outDir, 'det_ctia_panel.png'),  detGainClim, 'Gain [dBi]');

    % (7) Combined 2x2: deterministic EIRP (top) + Monte-Carlo p50 (bottom).
    f = figure('Visible', 'off', 'Position', [100 100 1200 800]);
    detClim = [min(detEirpClim) max(detEirpClim)];
    mcClim  = [min(mcClimData)  max(mcClimData)];
    subplot(2,2,1); paintMap(ZdetG, az, el, 'det global (curved)', detClim, 'EIRP [dBm]');
    subplot(2,2,2); paintMap(ZdetP, az, el, 'det panel (flat)',   detClim, 'EIRP [dBm]');
    subplot(2,2,3); paintMap(p50G,  az, el, 'mc p50 global (curved)', mcClim, 'EIRP [dBm]');
    subplot(2,2,4); paintMap(p50P,  az, el, 'mc p50 panel (flat)',   mcClim, 'EIRP [dBm]');
    exportgraphics(f, fullfile(outDir, 'compare_frames.png'), 'Resolution', 120);
    close(f);

    % ========================= REPORT ===================================
    fprintf('\n================= FLATNESS REPORT =================\n');
    fprintf('%-20s %-7s %-6s %s\n', 'method', 'frame', 'metric', 'spread (deg)');
    for i = 1:size(rows, 1)
        fprintf('%-20s %-7s %-6s %.2f\n', rows{i,1}, rows{i,2}, rows{i,3}, rows{i,4});
    end
    fprintf('--------------------------------------------------\n');
    if pass
        fprintf('RESULT: PASS  (panel ~flat, global clearly curved)\n');
    else
        fprintf('RESULT: FAIL\n');
    end
    fprintf('PNGs saved to: %s\n', outDir);

    results = struct('passed', pass, 'rows', {rows}, 'outDir', outDir);
end

% ---- exact copy of test_output_frame.m ridgeSpreadDeg ------------------
function spreadDeg = ridgeSpreadDeg(map, azGrid, elGrid, halfWindowDeg, azCoverDeg)
%RIDGESPREADDEG Spread (max-min) of the main-lobe ridge elevation across az.
    azGrid = azGrid(:).'; elGrid = elGrid(:).';
    [~, linIdx] = max(map(:));
    [~, elPeakIdx] = ind2sub(size(map), linIdx);
    el0 = elGrid(elPeakIdx);
    elMask = abs(elGrid - el0) <= halfWindowDeg;
    azIdx = find(abs(azGrid) <= azCoverDeg);
    ridgeEl = nan(1, numel(azIdx));
    for i = 1:numel(azIdx)
        col = map(azIdx(i), :);
        col(~elMask) = -inf;
        [~, j] = max(col);
        ridgeEl(i) = elGrid(j);
    end
    ridgeEl = ridgeEl(isfinite(ridgeEl));
    if isempty(ridgeEl); spreadDeg = 0; else; spreadDeg = max(ridgeEl) - min(ridgeEl); end
end

% ---- deepest-null elevation spread across azimuth (for MC p50) ---------
function s = nullElevSpread(Z, az, el, coverDeg)
    az = az(:).'; el = el(:).';
    azIdx = find(abs(az) <= coverDeg);
    nullEl = nan(1, numel(azIdx));
    for i = 1:numel(azIdx)
        [~, j] = min(Z(azIdx(i), :));
        nullEl(i) = el(j);
    end
    nullEl = nullEl(isfinite(nullEl));
    if isempty(nullEl); s = 0; else; s = max(nullEl) - min(nullEl); end
end

% ---- pull the p50 Naz x Nel slice via the percentiles vector ----------
function m = p50Slice(pmaps)
    p = pmaps.percentiles(:).';
    idx = find(p == 50, 1);
    if isempty(idx); [~, idx] = min(abs(p - 50)); end
    m = pmaps.values(:, :, idx);
end

% ---- plotting helpers (rows = el, cols = az) --------------------------
function paintMap(Z, az, el, ttl, clim, cbLabel)
    imagesc(az, el, Z.'); set(gca, 'YDir', 'normal');
    if nargin >= 5 && ~isempty(clim); caxis(clim); end
    xlabel('Azimuth [deg]'); ylabel('Elevation [deg]'); title(ttl);
    c = colorbar; c.Label.String = cbLabel;
end

function saveMap(Z, az, el, ttl, fpath, climData, cbLabel)
    f = figure('Visible', 'off', 'Position', [100 100 700 420]);
    paintMap(Z, az, el, ttl, [min(climData) max(climData)], cbLabel);
    exportgraphics(f, fpath, 'Resolution', 120);
    close(f);
end
