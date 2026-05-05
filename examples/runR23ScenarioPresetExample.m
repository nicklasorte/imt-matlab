function results = runR23ScenarioPresetExample(varargin)
%RUNR23SCENARIOPRESETEXAMPLE End-to-end R23 scenario-preset comparison.
%
%   RESULTS = runR23ScenarioPresetExample()
%   RESULTS = runR23ScenarioPresetExample('Name', Value, ...)
%
%   Runs both the urban-baseline and suburban-baseline R23 scenario
%   presets through runR23AasEirpCdfGrid, renders mean EIRP and pointing
%   azimuth heatmaps, and prints metadata + scenario differences + the
%   power-semantics self-check.
%
%   Optional name-value overrides (forwarded to r23ScenarioPreset for
%   each preset to keep runtime light during interactive demos):
%       'numSnapshots'   default 50 (small for fast example runs)
%       'azGridDeg'      default -180:5:180
%       'elGridDeg'      default -90:5:30
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO propagation, NO coordination
%   distance, and NO 19-site laydown. Network loading and TDD activity
%   are NOT yet active modeled behaviours -- they appear only in
%   referenceOnly metadata for traceability.
%
%   Example:
%       runR23ScenarioPresetExample
%
%   Returns RESULTS struct with .urban and .suburban runR23AasEirpCdfGrid
%   output structs and .diff from compareR23ScenarioMetadata.
%
%   See also: r23ScenarioPreset, runR23AasEirpCdfGrid,
%             compareR23ScenarioMetadata, plotR23AasEirpCdfGrid,
%             plotR23AasPointingHeatmap.

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    outDir = fullfile(here, 'output', 'r23_scenario_presets');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    % ---- defaults / overrides ---------------------------------------
    optsDefaults = struct( ...
        'numSnapshots', 50, ...
        'azGridDeg',    -180:5:180, ...
        'elGridDeg',    -90:5:30);
    overrides = parseNV(varargin, fieldnames(optsDefaults));
    optsRun = mergeStructs(optsDefaults, overrides);

    % ---- build presets ----------------------------------------------
    urbanParams    = r23ScenarioPreset('urban-baseline', ...
                        'numSnapshots', optsRun.numSnapshots);
    suburbanParams = r23ScenarioPreset('suburban-baseline', ...
                        'numSnapshots', optsRun.numSnapshots);

    % Tighten the sim grids to keep example runtime light.
    urbanParams.sim.azGrid_deg    = optsRun.azGridDeg;
    urbanParams.sim.elGrid_deg    = optsRun.elGridDeg;
    suburbanParams.sim.azGrid_deg = optsRun.azGridDeg;
    suburbanParams.sim.elGrid_deg = optsRun.elGridDeg;

    fprintf('=========================================================\n');
    fprintf('  runR23ScenarioPresetExample (R23 7/8 GHz Extended AAS)\n');
    fprintf('=========================================================\n');

    % ---- run urban-baseline -----------------------------------------
    fprintf('  ---- running urban-baseline -----\n');
    urbanOut = runR23AasEirpCdfGrid(urbanParams);
    saveScenarioFigures(urbanOut, outDir, 'urban_baseline');
    printRunSummary(urbanOut, 'urban-baseline');

    % ---- run suburban-baseline --------------------------------------
    fprintf('  ---- running suburban-baseline -----\n');
    suburbanOut = runR23AasEirpCdfGrid(suburbanParams);
    saveScenarioFigures(suburbanOut, outDir, 'suburban_baseline');
    printRunSummary(suburbanOut, 'suburban-baseline');

    % ---- scenario diff ----------------------------------------------
    fprintf('\n  ---- scenario metadata differences ----\n');
    diff = compareR23ScenarioMetadata(urbanOut, suburbanOut);

    % ---- self-check summary -----------------------------------------
    fprintf('\n  ---- power self-check summary ----\n');
    printSelfCheck(urbanOut.selfCheck.powerSemantics, 'urban-baseline');
    printSelfCheck(suburbanOut.selfCheck.powerSemantics, 'suburban-baseline');

    fprintf('---------------------------------------------------------\n');
    fprintf('  REMINDER: antenna-face EIRP only.\n');
    fprintf('    no path loss, no receiver antenna, no I / N,\n');
    fprintf('    no propagation, no coordination distance,\n');
    fprintf('    no 19-site laydown. Network loading and TDD\n');
    fprintf('    activity factors are reference-only metadata\n');
    fprintf('    and NOT active in the EIRP-grid computation.\n');
    fprintf('=========================================================\n');

    results = struct();
    results.urban    = urbanOut;
    results.suburban = suburbanOut;
    results.diff     = diff;
end

% =====================================================================

function saveScenarioFigures(out, outDir, tag)
    try
        figs = plotR23AasEirpCdfGrid(out, []);
        if isfield(figs, 'mean') && ~isempty(figs.mean) && ...
                isgraphics(figs.mean)
            saveFigure(figs.mean, fullfile(outDir, ...
                sprintf('%s_mean_grid.png', tag)));
        end
    catch err
        fprintf('  EIRP heatmap render failed (%s): %s\n', tag, err.message);
    end
    if isfield(out, 'pointing') && isstruct(out.pointing) && ...
            ~isempty(out.pointing.azimuthDegGrid)
        try
            azFig = plotR23AasPointingHeatmap(out, 'azimuth');
            saveFigure(azFig, fullfile(outDir, ...
                sprintf('%s_pointing_az.png', tag)));
        catch err
            fprintf('  pointing heatmap render failed (%s): %s\n', ...
                tag, err.message);
        end
    end
end

function printRunSummary(out, label)
    md = out.metadata;
    fprintf('  %s:\n', label);
    fprintf('    scenarioPreset       : %s\n', getStrField(md, 'scenarioPreset'));
    fprintf('    environment          : %s\n', getStrField(md, 'environment'));
    fprintf('    cellRadius_m         : %.0f\n', md.cellRadius_m);
    fprintf('    bsHeight_m           : %.1f\n', md.bsHeight_m);
    fprintf('    numUesPerSector      : %d\n', md.numUesPerSector);
    fprintf('    maxEirpPerSector_dBm : %.2f\n', md.maxEirpPerSector_dBm);
    fprintf('    perBeamPeakEirpDbm   : %.2f\n', md.perBeamPeakEirpDbm);
    fprintf('    randomSeed           : %g\n', md.randomSeed);
    finiteMean = out.stats.mean_dBm(isfinite(out.stats.mean_dBm));
    if isempty(finiteMean)
        fprintf('    mean_dBm grid        : (no finite cells)\n');
    else
        fprintf('    mean_dBm min/mean/max: %.2f / %.2f / %.2f dBm\n', ...
            min(finiteMean), mean(finiteMean), max(finiteMean));
    end
end

function printSelfCheck(ps, label)
    fprintf('  %s: status=%s\n', label, ps.status);
    fprintf('    expectedSectorPeakEirp_dBm  = %.4f\n', ...
        ps.expectedSectorPeakEirp_dBm);
    fprintf('    expectedPerBeamPeakEirp_dBm = %.4f\n', ...
        ps.expectedPerBeamPeakEirp_dBm);
    fprintf('    observedMaxGridEirp_dBm     = %.4f\n', ...
        ps.observedMaxGridEirp_dBm);
    fprintf('    peakShortfall_dB            = %.4f\n', ps.peakShortfall_dB);
    fprintf('    %s\n', ps.message);
end

function s = getStrField(md, name)
    if isfield(md, name)
        v = md.(name);
        if ischar(v)
            s = v;
        elseif isstring(v) && isscalar(v)
            s = char(v);
        else
            s = '<...>';
        end
    else
        s = '<unset>';
    end
end

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

function out = parseNV(args, allowed)
    out = struct();
    if isempty(args), return; end
    if mod(numel(args), 2) ~= 0
        error('runR23ScenarioPresetExample:badArgs', ...
            'Optional arguments must be Name, Value pairs.');
    end
    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name); name = char(name); end
        if ~ismember(name, allowed)
            error('runR23ScenarioPresetExample:badArg', ...
                ['Unknown option "%s". Allowed: %s'], ...
                name, strjoin(allowed, ', '));
        end
        out.(name) = args{k+1};
    end
end

function s = mergeStructs(defaults, overrides)
    s = defaults;
    fns = fieldnames(overrides);
    for k = 1:numel(fns)
        s.(fns{k}) = overrides.(fns{k});
    end
end
