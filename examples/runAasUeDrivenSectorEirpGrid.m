function runAasUeDrivenSectorEirpGrid()
%RUNAASUEDRIVENSECTOREIRPGRID End-to-end UE-driven sector EIRP grid demo.
%
%   runAasUeDrivenSectorEirpGrid()
%
%   Pipeline (one IMT AAS macro sector):
%       imtAasDefaultParams       -> R23 antenna defaults / power semantics
%       imtAasSingleSectorParams  -> sector geometry + steering envelope
%       imtAasGenerateBeamSet     -> N_UE UE positions -> beam (az, el)
%       imtAasSectorEirpGridFromBeams ->
%           per-beam EIRP grids ->
%           linear-power-summed aggregate sector EIRP grid
%
%   For the default R23 macro reference:
%       sector peak EIRP        = 78.3  dBm / 100 MHz
%       N_UE                    = 3
%       per-beam peak EIRP      = 78.3 - 10*log10(3) ~ 73.53 dBm / 100 MHz
%
%   This driver is antenna-face EIRP only. There is NO path loss, NO
%   receiver antenna gain, and NO I / N: it produces the per-direction
%   EIRP that the sector radiates from the antenna face.
%
%   Run from the repo root:
%       runAasUeDrivenSectorEirpGrid
%
%   Or, with cd:
%       cd examples
%       runAasUeDrivenSectorEirpGrid

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    params = imtAasDefaultParams();
    sector = imtAasSingleSectorParams('macroUrban', params);
    beams  = imtAasGenerateBeamSet(params.numUesPerSector, sector, ...
        struct('seed', 1));

    azGridDeg = -180:1:180;
    elGridDeg =  -90:1:90;

    out = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beams, params);

    fprintf('=========================================================\n');
    fprintf('  UE-driven AAS sector EIRP grid (R23 macro 7.125-8.4 GHz)\n');
    fprintf('=========================================================\n');
    fprintf('  Antenna-face EIRP only - no path loss, receiver gain, or I/N.\n');
    fprintf('  numBeams                : %d\n', out.numBeams);
    fprintf('  sectorEirpDbm           : %.2f dBm / 100 MHz\n', ...
        out.sectorEirpDbm);
    fprintf('  perBeamPeakEirpDbm      : %.2f dBm / 100 MHz\n', ...
        out.perBeamPeakEirpDbm);
    fprintf('  peak aggregate EIRP     : %.2f dBm / 100 MHz\n', ...
        out.peakAggregateEirpDbm);
    fprintf('  peak envelope EIRP      : %.2f dBm / 100 MHz\n', ...
        out.peakEnvelopeEirpDbm);
    fprintf('  splitSectorPower        : %d\n', out.splitSectorPower);

    fprintf('---------------------------------------------------------\n');
    fprintf('  beam |  ue_x_m  ue_y_m  ue_z_m  range_m | rawAz   rawEl |  steerAz  steerEl  azClip  elClip\n');
    for i = 1:out.numBeams
        fprintf('  %4d | %7.1f %7.1f %6.2f %8.1f | %6.2f %6.2f | %7.2f %7.2f   %d       %d\n', ...
            i, beams.ue.x_m(i), beams.ue.y_m(i), beams.ue.z_m(i), ...
            beams.ue.r_m(i), ...
            beams.rawSteerAzDeg(i), beams.rawSteerElDeg(i), ...
            beams.steerAzDeg(i),    beams.steerElDeg(i), ...
            beams.wasAzClipped(i),  beams.wasElClipped(i));
    end
    fprintf('=========================================================\n');

    % ---- plots --------------------------------------------------------
    figs = plotImtAasSectorEirpGrid(out);

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    saveFigure(figs.aggregate, ...
        fullfile(outDir, 'aas_sector_aggregate_eirp_grid.png'));
    saveFigure(figs.envelope, ...
        fullfile(outDir, 'aas_sector_envelope_eirp_grid.png'));

    if iscell(figs.perBeam)
        K = numel(figs.perBeam);
    else
        K = 0;
    end
    K = min(3, K);
    pngNames = { ...
        'aas_sector_per_beam_1.png', ...
        'aas_sector_per_beam_2.png', ...
        'aas_sector_per_beam_3.png'};
    for k = 1:K
        saveFigure(figs.perBeam{k}, fullfile(outDir, pngNames{k}));
    end

    % ---- CSV exports --------------------------------------------------
    metaAggregate = struct( ...
        'function',                   'imtAasSectorEirpGridFromBeams', ...
        'sector_eirp_dbm_per_100mhz', out.sectorEirpDbm, ...
        'per_beam_peak_eirp_dbm_per_100mhz', out.perBeamPeakEirpDbm, ...
        'num_beams',                  out.numBeams, ...
        'split_sector_power',         out.splitSectorPower, ...
        'aggregation_mode',           out.aggregationMode, ...
        'bandwidth_mhz',              params.bandwidthMHz, ...
        'frequency_mhz',              params.frequencyMHz, ...
        'mechanical_downtilt_deg',    params.mechanicalDowntiltDeg, ...
        'subarray_downtilt_deg',      params.subarrayDowntiltDeg, ...
        'num_rows',                   params.numRows, ...
        'num_columns',                params.numColumns, ...
        'notes',                      'UE-driven sector aggregate EIRP grid; antenna-face EIRP only - no path loss, receiver gain, or I/N.');
    imtAasExportEirpGridCsv(azGridDeg, elGridDeg, out.aggregateEirpDbm, ...
        fullfile(outDir, 'aas_sector_aggregate_eirp_grid.csv'), ...
        metaAggregate);

    metaEnvelope = metaAggregate;
    metaEnvelope.notes = ...
        'UE-driven sector envelope EIRP grid (max over beams); antenna-face EIRP only - no path loss, receiver gain, or I/N.';
    imtAasExportEirpGridCsv(azGridDeg, elGridDeg, out.maxEnvelopeEirpDbm, ...
        fullfile(outDir, 'aas_sector_envelope_eirp_grid.csv'), ...
        metaEnvelope);

    % ---- per-beam summary CSV ----------------------------------------
    summaryPath = fullfile(outDir, 'aas_sector_beam_summary.csv');
    writeBeamSummaryCsv(summaryPath, beams, out);

    fprintf('  saved %s\n', summaryPath);
    fprintf('=========================================================\n');
end

% =====================================================================

function saveFigure(fig, pngPath)
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    if exist('exportgraphics', 'file') == 2
        try
            exportgraphics(fig, pngPath, 'Resolution', 150);
            fprintf('  saved %s\n', pngPath);
            return;
        catch err
            fprintf('  exportgraphics failed (%s); falling back to saveas\n', ...
                err.message);
        end
    end
    try
        saveas(fig, pngPath);
        fprintf('  saved %s\n', pngPath);
    catch err
        fprintf('  could not save %s (%s)\n', pngPath, err.message);
    end
end

function writeBeamSummaryCsv(csvPath, beams, out)
    [outDir, ~, ~] = fileparts(csvPath);
    if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    fid = fopen(csvPath, 'w');
    if fid < 0
        error('runAasUeDrivenSectorEirpGrid:cannotOpenSummary', ...
            'Could not open %s for writing.', csvPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, ['beam_index,ue_x_m,ue_y_m,ue_z_m,ue_range_m,', ...
        'raw_steer_az_deg,raw_steer_el_deg,steer_az_deg,steer_el_deg,', ...
        'was_az_clipped,was_el_clipped,', ...
        'per_beam_peak_eirp_dbm_per_100mhz\n']);
    for i = 1:out.numBeams
        fprintf(fid, '%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%.6f\n', ...
            i, beams.ue.x_m(i), beams.ue.y_m(i), beams.ue.z_m(i), ...
            beams.ue.r_m(i), ...
            beams.rawSteerAzDeg(i), beams.rawSteerElDeg(i), ...
            beams.steerAzDeg(i),    beams.steerElDeg(i), ...
            beams.wasAzClipped(i),  beams.wasElClipped(i), ...
            out.perBeamPeakEirpDbm);
    end
    clear cleanupObj;   %#ok<CLMVR>
end
