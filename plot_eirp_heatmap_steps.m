function plot_eirp_heatmap_steps(opts)
%PLOT_EIRP_HEATMAP_STEPS Working-paper figure: composite gain -> EIRP heatmap.
%
%   plot_eirp_heatmap_steps()
%   plot_eirp_heatmap_steps(OPTS)
%
%   Renders the 4-panel "steps to the EIRP heatmap" figure for the working
%   paper (insert after Section 3, AAS Composite Gain Pattern):
%
%       (1) Composite gain, one beam steered to a UE          [Step 3]
%           ABSOLUTE dBi from imtAasCompositeGain (via
%           imtAasSectorEirpGridFromBeams computeGain path).
%       (2) The same beam converted to per-beam EIRP          [Step 4]
%           Peak-normalized: EIRP_b = P_beam + G_b - max(G_b) with
%           P_beam = sectorEirp - 10*log10(N). Every beam peaks at
%           exactly P_beam at its steering direction (repo convention;
%           scan loss conservatively neglected, see imtAasEirpGrid).
%       (3) One Monte Carlo snapshot                          [Step 5]
%           Linear-mW sum of the N = 3 simultaneous per-beam grids
%           (imtAasSectorEirpGridFromBeams, aggregationMode 'sum_mW').
%       (4) Percentile EIRP heatmap                           [Step 6]
%           out.percentileMaps from the BASELINE bare call
%           runR23AasEirpCdfGrid(struct()) (macroUrban, 10k snapshots,
%           1 deg grid), or from a caller-supplied result.
%
%   OPTS (all optional):
%       .result       out struct from a previous runR23AasEirpCdfGrid run.
%                     When supplied, panel (4) and the observation grid are
%                     taken from it and the 10k baseline is NOT re-run.
%       .percentile   percentile for panel (4). Default 50. Must be a
%                     member of result.percentileMaps.percentiles.
%       .outFile      output PNG path. Default 'eirp_heatmap_steps.png'
%                     in the current folder. '' -> no export.
%       .demoRadiusM  1x3 UE ground ranges for the demo snapshot [m].
%                     Default [60 150 380] (urban macro).
%       .demoAzDeg    1x3 UE azimuths [deg]. Default [-35 8 44].
%       .bsHeightM    BS antenna height [m].  Default 18 (urban macro).
%       .ueHeightM    UE height [m].          Default 1.5.
%       .elClampDeg   steering elevation clamp [deg]. Default [-10 0]
%                     (R23 coverage envelope, cf. clamp_beam_to_r23_coverage).
%
%   Console acceptance prints:
%       per-beam peak EIRP vs sectorEirp - 10*log10(N)
%       demo-snapshot aggregate peak
%       panel-4 percentile map max
%
%   Example:
%       out = runR23AasEirpCdfGrid(struct());          % baseline, reusable
%       plot_eirp_heatmap_steps(struct('result', out));
%
%   See also: imtAasSectorEirpGridFromBeams, imtAasEirpGrid,
%             imtAasCompositeGain, runR23AasEirpCdfGrid.

    if nargin < 1 || isempty(opts); opts = struct(); end
    if ~isstruct(opts)
        error('plot_eirp_heatmap_steps:invalidOpts', ...
            'OPTS must be a struct (or omitted).');
    end

    pctWanted  = getOpt(opts, 'percentile', 50);
    outFile    = getOpt(opts, 'outFile', fullfile(pwd, 'eirp_heatmap_steps.png'));
    rDemo      = getOpt(opts, 'demoRadiusM', [60 150 380]);
    azDemo     = getOpt(opts, 'demoAzDeg',  [-35 8 44]);
    hBs        = getOpt(opts, 'bsHeightM',  18);
    hUe        = getOpt(opts, 'ueHeightM',  1.5);
    elClamp    = getOpt(opts, 'elClampDeg', [-10 0]);

    % ---- panel (4): baseline percentile heatmap ------------------------
    if isfield(opts, 'result') && ~isempty(opts.result)
        out = opts.result;
    else
        fprintf('plot_eirp_heatmap_steps: running baseline runR23AasEirpCdfGrid(struct()) ...\n');
        out = runR23AasEirpCdfGrid(struct());   %#ok<*NASGU> baseline bare call
    end
    pm = out.percentileMaps;
    ip = find(abs(pm.percentiles - pctWanted) < 1e-9, 1);
    if isempty(ip)
        error('plot_eirp_heatmap_steps:percentileUnavailable', ...
            ['Percentile %g not in result.percentileMaps.percentiles ', ...
             '[%s]. Re-run with opts.percentiles including it.'], ...
            pctWanted, num2str(pm.percentiles));
    end
    azGrid = pm.azGrid(:).';
    elGrid = pm.elGrid(:).';
    if ~(size(pm.values,1) == numel(azGrid) && size(pm.values,2) == numel(elGrid))
        error('plot_eirp_heatmap_steps:unexpectedShape', ...
            'percentileMaps.values must be Naz x Nel x P.');
    end
    pan4 = pm.values(:, :, ip);                      % Naz x Nel

    nMc = NaN;
    if isfield(out, 'metadata') && isfield(out.metadata, 'numSnapshots')
        nMc = out.metadata.numSnapshots;
    end

    % ---- panels (1)-(3): demo snapshot via the repo EIRP path ----------
    params = imtAasDefaultParams();
    elDemo = -atand((hBs - hUe) ./ rDemo(:));
    elDemo = min(max(elDemo, elClamp(1)), elClamp(2));   % R23 steering envelope
    beams  = struct('steerAzDeg', azDemo(:), 'steerElDeg', elDemo);

    fb = imtAasSectorEirpGridFromBeams(azGrid, elGrid, beams, params, ...
        struct('computeGain', true));

    kMid = 2;                                        % middle-range demo UE
    pan1 = fb.perBeamGainDbi(:, :, kMid);            % ABSOLUTE composite gain [dBi]
    pan2 = fb.perBeamEirpDbm(:, :, kMid);            % peak-normalized per-beam EIRP
    pan3 = fb.aggregateEirpDbm;                      % sum_mW over N = 3 beams

    % ---- acceptance checks ---------------------------------------------
    pBeamExpect = fb.sectorEirpDbm - 10 * log10(fb.numBeams);
    assert(abs(fb.perBeamPeakEirpDbm - pBeamExpect) < 1e-9, ...
        'per-beam peak EIRP mismatch');
    for k = 1:fb.numBeams
        pk = max(max(fb.perBeamEirpDbm(:, :, k)));
        assert(abs(pk - fb.perBeamPeakEirpDbm) < 1e-6, ...
            'beam %d grid peak %.4f != perBeamPeakEirpDbm %.4f', ...
            k, pk, fb.perBeamPeakEirpDbm);
    end
    fprintf('perBeamPeakEirpDbm       = %.2f dBm (sectorEirp - 10log10(%d) = %.2f)\n', ...
        fb.perBeamPeakEirpDbm, fb.numBeams, pBeamExpect);
    fprintf('demo aggregate peak      = %.2f dBm/100 MHz\n', fb.peakAggregateEirpDbm);
    fprintf('panel-4 p%g map max      = %.2f dBm/100 MHz\n', ...
        pm.percentiles(ip), max(pan4(:)));

    % ---- figure ---------------------------------------------------------
    fig = figure('Units', 'inches', 'Position', [1 1 11.2 7.2], 'Color', 'w');
    tl  = tiledlayout(fig, 2, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

    eClim = [25 78];                                 % shared EIRP color limits
    if isnan(nMc); mcStr = 'baseline'; else; mcStr = addComma(nMc); end
    ttl = { ...
        '(1) Composite gain - one beam steered to a UE   [Step 3]', ...
        '(2) Per-beam EIRP: peak-normalized to P_{beam}   [Step 4]', ...
        '(3) One Monte Carlo snapshot - \Sigma of N = 3 beams   [Step 5]', ...
        sprintf('(4) %g^{th}-percentile heatmap - %s snapshots   [Step 6]', ...
                pm.percentiles(ip), mcStr)};
    pans  = {pan1, pan2, pan3, pan4};
    clims = {[-15 35], eClim, eClim, eClim};
    cbl   = {'Gain (dBi)', 'EIRP (dBm/100 MHz)', 'EIRP (dBm/100 MHz)', ...
             'EIRP (dBm/100 MHz)'};
    ax = gobjects(1, 4);
    for i = 1:4
        ax(i) = nexttile(tl);
        imagesc(ax(i), azGrid, elGrid, pans{i}.');   % transpose: repo convention
        axis(ax(i), 'xy');
        colormap(ax(i), turbo);
        clim(ax(i), clims{i});
        title(ax(i), ttl{i}, 'FontSize', 10);
        xlabel(ax(i), 'Azimuth (deg)', 'FontSize', 9);
        ylabel(ax(i), 'Elevation (deg)', 'FontSize', 9);
        set(ax(i), 'XTick', -180:60:180, 'YTick', -90:30:90, 'FontSize', 8);
        cb = colorbar(ax(i));
        cb.Label.String = cbl{i};
        cb.FontSize = 7.5;
        hold(ax(i), 'on');
    end

    plot(ax(1), azDemo(kMid), elDemo(kMid), 'wx', 'MarkerSize', 8, 'LineWidth', 2);
    plot(ax(2), azDemo(kMid), elDemo(kMid), 'wx', 'MarkerSize', 8, 'LineWidth', 2);
    plot(ax(3), azDemo, elDemo, 'wx', 'MarkerSize', 8, 'LineWidth', 2);
    text(ax(3), -165, -55, 'UE beam directions', 'Color', 'w', 'FontSize', 8);
    line(ax(3), [-100 azDemo(1)], [-50 elDemo(1)], 'Color', 'w', 'LineWidth', 0.6);

    title(tl, sprintf(['From composite gain to the EIRP heatmap ', ...
        '(ITU macro urban AAS, %.1f dBm/100 MHz, N = %d UEs)'], ...
        fb.sectorEirpDbm, fb.numBeams), 'FontSize', 12);

    % ---- flow arrows + labels (normalized figure coordinates) ----------
    drawnow;
    p = arrayfun(@(a) get(a, 'Position'), ax, 'UniformOutput', false);

    yTop = p{1}(2) + p{1}(4) / 2;                    % (1) -> (2)
    arrowWithLabel(fig, [p{1}(1) + p{1}(3) + 0.055, yTop], ...
                        [p{2}(1) - 0.006,           yTop], ...
        {'peak-normalize each beam:', ...
         'P_{beam} = 78.3 - 10log_{10}(3) = 73.5 dBm'}, 0.055);

    arrowWithLabel(fig, ...                          % (2) -> (3), diagonal
        [p{2}(1) + 0.30 * p{2}(3), p{2}(2) - 0.012], ...
        [p{3}(1) + 0.80 * p{3}(3), p{3}(2) + p{3}(4) + 0.050], ...
        {'sum N = 3 simultaneous beams', '(linear mW) \rightarrow one snapshot'}, 0.012);

    yBot = p{3}(2) + p{3}(4) / 2;                    % (3) -> (4)
    arrowWithLabel(fig, [p{3}(1) + p{3}(3) + 0.055, yBot], ...
                        [p{4}(1) - 0.006,           yBot], ...
        {sprintf('repeat \\times %s \\rightarrow', mcStr), 'per-cell percentile'}, 0.055);

    % ---- export ----------------------------------------------------------
    if ~isempty(outFile)
        exportgraphics(fig, outFile, 'Resolution', 300);
        fprintf('figure written: %s\n', outFile);
    end
end

% ======================= local helpers ==================================
function v = getOpt(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end

function arrowWithLabel(fig, xy1, xy2, str, dy)
    annotation(fig, 'arrow', [xy1(1) xy2(1)], [xy1(2) xy2(2)], ...
        'LineWidth', 1.5, 'Color', [0.25 0.25 0.25], 'HeadLength', 9, ...
        'HeadWidth', 9);
    cx = (xy1(1) + xy2(1)) / 2;
    cy = (xy1(2) + xy2(2)) / 2 + dy;
    annotation(fig, 'textbox', [cx - 0.10, cy - 0.02, 0.20, 0.04], ...
        'String', str, 'FitBoxToText', 'on', 'BackgroundColor', 'w', ...
        'EdgeColor', [0.6 0.6 0.6], 'FontSize', 8, ...
        'HorizontalAlignment', 'center', 'Margin', 3);
end

function s = addComma(n)
    s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end