function results = test_runR23AasEirpCdfGrid()
%TEST_RUNR23AASEIRPCDFGRID Self tests for the R23 AAS EIRP CDF-grid runner.
%
%   RESULTS = test_runR23AasEirpCdfGrid()
%
%   Covers:
%       T1.  runR23AasEirpCdfGrid returns stats and percentileMaps.
%       T2.  stats grid size matches azGridDeg x elGridDeg.
%       T3.  stats.numMc equals requested numMc.
%       T4.  percentileMaps.values size is [Naz, Nel, P].
%       T5.  Default numBeams equals params.numUesPerSector (= 3).
%       T6.  For three identical beams via imtAasSectorEirpGridFromBeams,
%            aggregate peak EIRP is approximately 78.3 dBm / 100 MHz.
%       T7.  For 3-beam UE-driven draws perBeamPeakEirpDbm is
%            approximately 73.53 dBm / 100 MHz.
%       T8.  out.metadata says 'R23 Extended AAS'.
%       T9.  No output / metadata fields advertise path loss, receiver
%            gain, or I / N.
%       T10. Deterministic seed gives repeatable percentile maps.
%       T11. Flat-opts struct accepts opts.aasGeometryPreset (and the
%            other geometry override fields) and reaches identical
%            internal state to the equivalent name-value invocation.
%
%   Black-box coverage of the untested LOCAL (file-private) helpers of
%   runR23AasEirpCdfGrid, exercised only through the public entry point by
%   forcing the relevant branch and asserting on the observable result:
%       T12. validateNumMc: numMc = 0 and numMc = 2.5 both throw
%            'runR23AasEirpCdfGrid:badNumMc'.
%       T13. validateNumUes: numUesPerSector = 0 and 2.5 both throw
%            'runR23AasEirpCdfGrid:badNumUesPerSector'.
%       T14. validateOutputDomain: outputDomain = 'bogus' throws
%            'runR23AasEirpCdfGrid:invalidOutputDomain'; the default run
%            (no outputDomain) reports metadata.outputDomain == 'eirp'.
%       T15. writeMetadataSidecar: opts.outputMetadataPath writes a non-
%            empty JSON sidecar whose jsondecode is a struct with
%            .generator == 'runR23AasEirpCdfGrid'.
%       T16. resolveInputs: a non-struct, non-name-value first argument
%            (42) throws 'runR23AasEirpCdfGrid:badArgs'.
%       T17. extractGeometryNameValues: a non-char aasGeometryPreset (123)
%            throws 'runR23AasEirpCdfGrid:badGeometryPreset'.
%       T18. resolveSsbOpts: opts.ssb = 5 (non-struct, non-empty) throws
%            'runR23AasEirpCdfGrid:badSsbOpts'.
%       T19. environmentToDeployment: environment 'suburban' maps to
%            metadata.deployment 'macroSuburban' and 'urban' to 'macroUrban'.
%       T20. badMaxEirp: maxEirpPerSector_dBm = NaN throws
%            'runR23AasEirpCdfGrid:badMaxEirp'.
%       T21. numBeams/numUesPerSector conflict: both supplied and unequal
%            fires 'runR23AasEirpCdfGrid:numBeamsConflict' and
%            numUesPerSector wins (out.stats.numBeams == 3).
%       T22. writeMetadataSidecar: an unopenable opts.outputMetadataPath
%            (pointed at an existing directory) warns
%            'runR23AasEirpCdfGrid:cannotOpenSidecar'.
%       T23. resolveInputs: a non-char name in a name-value name slot
%            (struct first arg followed by a numeric) throws
%            'runR23AasEirpCdfGrid:badNV'.
%       T24. mcChunkSize is validated and chunked/unchunked runs preserve
%            identical streaming results for the same seed.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t_returns_stats_and_percentiles(results);
    results = t_grid_size(results);
    results = t_num_mc(results);
    results = t_percentile_size(results);
    results = t_default_num_beams(results);
    results = t_three_identical_beams_peak(results);
    results = t_three_beam_per_beam_peak(results);
    results = t_metadata_says_r23(results);
    results = t_no_path_loss_fields(results);
    results = t_seed_repeatable(results);
    results = t_flat_opts_geometry_preset(results);
    results = t_validate_num_mc(results);
    results = t_validate_num_ues(results);
    results = t_validate_output_domain(results);
    results = t_write_metadata_sidecar(results);
    results = t_resolve_inputs_bad_first_arg(results);
    results = t_bad_geometry_preset(results);
    results = t_resolve_ssb_opts(results);
    results = t_environment_to_deployment(results);
    results = t_bad_max_eirp(results);
    results = t_num_beams_conflict(results);
    results = t_unopenable_sidecar_warns(results);
    results = t_bad_name_value_name(results);
    results = t_mc_chunk_size(results);

    fprintf('\n--- test_runR23AasEirpCdfGrid summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% T1
% =====================================================================
function r = t_returns_stats_and_percentiles(r)
    out = runSmall(struct('seed', 1));
    ok = isfield(out, 'stats') && isstruct(out.stats) && ...
         isfield(out, 'percentileMaps') && isstruct(out.percentileMaps);
    r = check(r, ok, 'T1: runR23AasEirpCdfGrid returns stats and percentileMaps');
end

% =====================================================================
% T2
% =====================================================================
function r = t_grid_size(r)
    opts = smallOpts();
    opts.azGridDeg = -30:10:30;   % 7
    opts.elGridDeg = -10:5:10;    % 5
    out = runR23AasEirpCdfGrid(opts);
    Naz = numel(opts.azGridDeg);
    Nel = numel(opts.elGridDeg);
    okMean = isequal(size(out.stats.mean_dBm), [Naz, Nel]);
    okSum  = isequal(size(out.stats.sum_lin_mW), [Naz, Nel]);
    okMin  = isequal(size(out.stats.min_dBm),    [Naz, Nel]);
    okMax  = isequal(size(out.stats.max_dBm),    [Naz, Nel]);
    okCounts = size(out.stats.counts, 1) == Naz && ...
               size(out.stats.counts, 2) == Nel;
    r = check(r, okMean && okSum && okMin && okMax && okCounts, ...
        sprintf('T2: stats grid size matches az x el = %d x %d', Naz, Nel));
end

% =====================================================================
% T3
% =====================================================================
function r = t_num_mc(r)
    opts = smallOpts();
    opts.numMc = 25;
    out = runR23AasEirpCdfGrid(opts);
    okMc  = out.stats.numMc == 25;
    cellSums = sum(double(out.stats.counts), 3);
    okSums = all(cellSums(:) == 25);
    r = check(r, okMc && okSums, ...
        'T3: stats.numMc == requested numMc and counts sum to numMc');
end

% =====================================================================
% T4
% =====================================================================
function r = t_percentile_size(r)
    opts = smallOpts();
    opts.percentiles = [5 25 50 75 95];
    out = runR23AasEirpCdfGrid(opts);
    Naz = numel(opts.azGridDeg);
    Nel = numel(opts.elGridDeg);
    P   = numel(opts.percentiles);
    okShape = isequal(size(out.percentileMaps.values), [Naz, Nel, P]);
    r = check(r, okShape, ...
        sprintf('T4: percentileMaps.values size = [%d %d %d]', Naz, Nel, P));
end

% =====================================================================
% T5
% =====================================================================
function r = t_default_num_beams(r)
    params = imtAasDefaultParams();
    out = runR23AasEirpCdfGrid(struct( ...
        'numMc', 2, ...
        'azGridDeg', -10:10:10, ...
        'elGridDeg', -10:5:0, ...
        'binEdgesDbm', -80:5:120, ...
        'seed', 11));
    okDefault = out.stats.numBeams == params.numUesPerSector && ...
                params.numUesPerSector == 3;
    r = check(r, okDefault, sprintf( ...
        'T5: default numBeams = params.numUesPerSector = %d', ...
        params.numUesPerSector));
end

% =====================================================================
% T6: three identical beams aggregate peak ~ sectorEirpDbm
% =====================================================================
function r = t_three_identical_beams_peak(r)
    params = imtAasDefaultParams();
    az = -180:1:180;
    el =  -90:1:30;
    steerAz = 0;
    steerEl = -9;
    beams = struct( ...
        'steerAzDeg', repmat(steerAz, 3, 1), ...
        'steerElDeg', repmat(steerEl, 3, 1));
    sectorOut = imtAasSectorEirpGridFromBeams(az, el, beams, params, ...
        struct('splitSectorPower', true));
    peak = max(sectorOut.aggregateEirpDbm(:));
    okPeak = abs(peak - params.sectorEirpDbm) < 1e-6;
    r = check(r, okPeak, sprintf( ...
        ['T6: three identical beams aggregate peak ~ %.2f dBm/100MHz ' ...
         '(got %.6f, expected %.6f)'], ...
        params.sectorEirpDbm, peak, params.sectorEirpDbm));
end

% =====================================================================
% T7: 3-beam UE-driven perBeamPeakEirpDbm ~ 73.53 dBm
% =====================================================================
function r = t_three_beam_per_beam_peak(r)
    params = imtAasDefaultParams();
    expected = params.sectorEirpDbm - 10 * log10(3);
    out = runR23AasEirpCdfGrid(struct( ...
        'numMc',     5, ...
        'numBeams',  3, ...
        'azGridDeg', -30:10:30, ...
        'elGridDeg', -10:5:10, ...
        'binEdgesDbm', -80:5:120, ...
        'seed', 7));
    got = out.stats.perBeamPeakEirpDbm;
    okPerBeam = abs(got - expected) < 1e-9;
    r = check(r, okPerBeam, sprintf( ...
        ['T7: 3-beam perBeamPeakEirpDbm ~ %.4f dBm (got %.6f, ' ...
         'expected %.6f)'], expected, got, expected));
end

% =====================================================================
% T8
% =====================================================================
function r = t_metadata_says_r23(r)
    out = runSmall(struct('seed', 13));
    md = out.metadata;
    okGen   = isfield(md, 'generator') && ...
              strcmp(md.generator, 'runR23AasEirpCdfGrid');
    okModel = isfield(md, 'model') && ...
              ~isempty(strfind(lower(md.model), 'r23')) && ...        %#ok<STREMP>
              ~isempty(strfind(lower(md.model), 'extended aas'));      %#ok<STREMP>
    r = check(r, okGen && okModel, ...
        'T8: metadata generator + model identify R23 Extended AAS');
end

% =====================================================================
% T9: no path-loss / receiver / I/N output fields
% =====================================================================
function r = t_no_path_loss_fields(r)
    out = runSmall(struct('seed', 13));

    % Forbidden tokens for output / stats / percentileMaps fields
    % (the metadata struct deliberately carries explicit boolean flags
    % to declare absence of these features and is checked separately).
    bannedTokens = {'pathloss', 'rxgain', 'rxantenna', ...
        'iovern', 'i_over_n', 'inratio', 'coordination'};

    okOutTop  = ~hasBannedFieldExcept(out, bannedTokens, {'metadata'});
    okStats   = ~hasBannedField(out.stats, bannedTokens);
    okPmaps   = ~hasBannedField(out.percentileMaps, bannedTokens);

    md = out.metadata;
    okMd = isfield(md, 'includesPathLoss')        && ~md.includesPathLoss && ...
           isfield(md, 'includesReceiverAntenna') && ~md.includesReceiverAntenna && ...
           isfield(md, 'includesReceiverGain')    && ~md.includesReceiverGain && ...
           isfield(md, 'includesINMetric')        && ~md.includesINMetric;

    r = check(r, okOutTop && okStats && okPmaps && okMd, ...
        'T9: no output field advertises path loss / receiver gain / I / N (metadata declares absence)');
end

% =====================================================================
% T10: deterministic seed
% =====================================================================
function r = t_seed_repeatable(r)
    opts = smallOpts();
    opts.seed = 42;
    out1 = runR23AasEirpCdfGrid(opts);
    out2 = runR23AasEirpCdfGrid(opts);

    okEq = isequal(out1.stats.counts, out2.stats.counts) && ...
           isequaln(out1.stats.mean_dBm, out2.stats.mean_dBm) && ...
           isequaln(out1.percentileMaps.values, out2.percentileMaps.values);

    optsDiff = opts; optsDiff.seed = 1234;
    out3 = runR23AasEirpCdfGrid(optsDiff);
    okDiff = ~isequal(out1.stats.counts, out3.stats.counts) || ...
             ~isequaln(out1.stats.mean_dBm, out3.stats.mean_dBm);

    r = check(r, okEq && okDiff, ...
        'T10: same seed -> identical maps; different seed -> different maps');
end

% =====================================================================
% T11: flat-opts struct accepts aasGeometryPreset + geometry overrides
% =====================================================================
function r = t_flat_opts_geometry_preset(r)
    rev_num = 42;

    opts = struct();
    opts.aasGeometryPreset = 'ctia_7ghz_1x6';
    opts.numMc             = 10;
    opts.seed              = rev_num;
    opts.azGridDeg         = -120:2:120;
    opts.elGridDeg         = -30:2:30;
    opts.binEdgesDbm       = -100:0.1:120;
    opts.percentiles       = unique(sort(horzcat( ...
                                 1:1:99, 0.1:0.1:1, ...
                                 99:0.1:99.9, 0.01, 99.99)));

    outFlat = runR23AasEirpCdfGrid(opts);

    g = outFlat.metadata.aasGeometry;
    okPreset  = strcmp(g.aasGeometryPreset, 'ctia_7ghz_1x6');
    okSector  = isfield(g, 'sectorEirpDbm') && ...
                abs(g.sectorEirpDbm - 90.8) < 1e-6;
    okCond    = isfield(g, 'totalConductedPowerDbm') && ...
                abs(g.totalConductedPowerDbm - 58.6) < 1e-6;

    pcStatus  = outFlat.selfCheck.powerSemantics.status;
    okStatus  = strcmp(pcStatus, 'pass') || strcmp(pcStatus, 'warn');

    % Equivalent name-value invocation must reach identical internal
    % state (same seed, same RNG sequence, same loop, same aggregator).
    outNV = runR23AasEirpCdfGrid( ...
        'aasGeometryPreset', 'ctia_7ghz_1x6', ...
        'numMc',             opts.numMc, ...
        'seed',              opts.seed, ...
        'azGridDeg',         opts.azGridDeg, ...
        'elGridDeg',         opts.elGridDeg, ...
        'binEdgesDbm',       opts.binEdgesDbm, ...
        'percentiles',       opts.percentiles);

    meanDelta = abs(outFlat.stats.mean_dBm - outNV.stats.mean_dBm);
    finiteIdx = isfinite(meanDelta);
    okEquiv = all(meanDelta(finiteIdx) < 1e-9) && ...
              isequal(isfinite(outFlat.stats.mean_dBm), ...
                      isfinite(outNV.stats.mean_dBm));

    ok = okPreset && okSector && okCond && okStatus && okEquiv;
    r = check(r, ok, sprintf( ...
        ['T11: flat opts.aasGeometryPreset reaches identical state to ' ...
         'name-value form (preset=%s, sectorEirp=%.4f, ' ...
         'conducted=%.4f, selfCheck=%s, max|deltaMean|=%.3g)'], ...
        g.aasGeometryPreset, g.sectorEirpDbm, ...
        g.totalConductedPowerDbm, pcStatus, ...
        max([meanDelta(finiteIdx); 0])));
end

% =====================================================================
% T12: validateNumMc rejects non-positive / non-integer numMc.
% =====================================================================
function r = t_validate_num_mc(r)
    okZero = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'numMc', 0)), 'runR23AasEirpCdfGrid:badNumMc');             %#ok<SFLD>
    okFrac = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'numMc', 2.5)), 'runR23AasEirpCdfGrid:badNumMc');           %#ok<SFLD>
    r = check(r, okZero && okFrac, sprintf( ...
        ['T12: validateNumMc rejects numMc=0 and numMc=2.5 with ' ...
         'badNumMc (zero=%d frac=%d)'], okZero, okFrac));
end

% =====================================================================
% T13: validateNumUes rejects non-positive / non-integer numUesPerSector.
% =====================================================================
function r = t_validate_num_ues(r)
    okZero = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'numUesPerSector', 0)), ...
        'runR23AasEirpCdfGrid:badNumUesPerSector');                 %#ok<SFLD>
    okFrac = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'numUesPerSector', 2.5)), ...
        'runR23AasEirpCdfGrid:badNumUesPerSector');                 %#ok<SFLD>
    r = check(r, okZero && okFrac, sprintf( ...
        ['T13: validateNumUes rejects numUesPerSector=0 and 2.5 with ' ...
         'badNumUesPerSector (zero=%d frac=%d)'], okZero, okFrac));
end

% =====================================================================
% T14: validateOutputDomain rejects bad domain; default reports 'eirp'.
% =====================================================================
function r = t_validate_output_domain(r)
    okBad = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'outputDomain', 'bogus')), ...
        'runR23AasEirpCdfGrid:invalidOutputDomain');                %#ok<SFLD>
    out = runSmall(struct('seed', 1));   % no outputDomain -> default
    okDefault = strcmp(out.metadata.outputDomain, 'eirp');
    r = check(r, okBad && okDefault, sprintf( ...
        ['T14: validateOutputDomain rejects ''bogus'' (bad=%d) and the ' ...
         'default run reports metadata.outputDomain=''eirp'' (default=%d)'], ...
        okBad, okDefault));
end

% =====================================================================
% T15: writeMetadataSidecar writes a decodable JSON sidecar.
% =====================================================================
function r = t_write_metadata_sidecar(r)
    sidecarPath = [tempname '.json'];
    cleanup = onCleanup(@() deleteIfExists(sidecarPath)); %#ok<NASGU>

    opts = smallOpts();
    opts.outputMetadataPath = sidecarPath;
    runR23AasEirpCdfGrid(opts);

    okExists = exist(sidecarPath, 'file') == 2;
    okNonEmpty = false;
    okStruct = false;
    okGen = false;
    if okExists
        txt = fileread(sidecarPath);
        okNonEmpty = ~isempty(strtrim(txt));
        if okNonEmpty
            decoded = jsondecode(txt);
            okStruct = isstruct(decoded);
            okGen = okStruct && isfield(decoded, 'generator') && ...
                    strcmp(decoded.generator, 'runR23AasEirpCdfGrid');
        end
    end
    r = check(r, okExists && okNonEmpty && okStruct && okGen, sprintf( ...
        ['T15: writeMetadataSidecar writes a non-empty JSON sidecar with ' ...
         'generator==runR23AasEirpCdfGrid (exists=%d nonEmpty=%d ' ...
         'struct=%d gen=%d)'], okExists, okNonEmpty, okStruct, okGen));
end

% =====================================================================
% T16: resolveInputs rejects a bad first argument.
% =====================================================================
function r = t_resolve_inputs_bad_first_arg(r)
    okBad = throwsId(@() runR23AasEirpCdfGrid(42), ...
        'runR23AasEirpCdfGrid:badArgs');
    r = check(r, okBad, ...
        'T16: resolveInputs(42) throws runR23AasEirpCdfGrid:badArgs');
end

% =====================================================================
% T17: extractGeometryNameValues rejects a non-char aasGeometryPreset.
% =====================================================================
function r = t_bad_geometry_preset(r)
    okBad = throwsId(@() runR23AasEirpCdfGrid( ...
        'aasGeometryPreset', 123, ...
        'numMc', 2, ...
        'azGridDeg', -10:10:10, ...
        'elGridDeg', -10:5:0, ...
        'binEdgesDbm', -80:5:120, ...
        'seed', 1), 'runR23AasEirpCdfGrid:badGeometryPreset');
    r = check(r, okBad, ...
        ['T17: extractGeometryNameValues rejects non-char ' ...
         'aasGeometryPreset with badGeometryPreset']);
end

% =====================================================================
% T18: resolveSsbOpts rejects a non-struct, non-empty opts.ssb.
% =====================================================================
function r = t_resolve_ssb_opts(r)
    okBad = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'ssb', 5)), 'runR23AasEirpCdfGrid:badSsbOpts');             %#ok<SFLD>
    r = check(r, okBad, ...
        'T18: resolveSsbOpts rejects opts.ssb=5 with badSsbOpts');
end

% =====================================================================
% T19: environmentToDeployment maps environment -> deployment tag.
% =====================================================================
function r = t_environment_to_deployment(r)
    base = struct( ...
        'numMc',       2, ...
        'azGridDeg',   -10:10:10, ...
        'elGridDeg',   -10:5:0, ...
        'binEdgesDbm', -80:5:120, ...
        'seed',        5);

    optsSub = base; optsSub.environment = 'suburban';
    outSub  = runR23AasEirpCdfGrid(optsSub);

    optsUrb = base; optsUrb.environment = 'urban';
    outUrb  = runR23AasEirpCdfGrid(optsUrb);

    okSub = strcmp(outSub.metadata.deployment, 'macroSuburban');
    okUrb = strcmp(outUrb.metadata.deployment, 'macroUrban');
    r = check(r, okSub && okUrb, sprintf( ...
        ['T19: environmentToDeployment maps suburban->macroSuburban ' ...
         '(%d) and urban->macroUrban (%d)'], okSub, okUrb));
end

% =====================================================================
% T20: a non-finite maxEirpPerSector_dBm is rejected.
% =====================================================================
function r = t_bad_max_eirp(r)
    okBad = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'maxEirpPerSector_dBm', NaN)), ...
        'runR23AasEirpCdfGrid:badMaxEirp');                         %#ok<SFLD>
    r = check(r, okBad, ...
        'T20: maxEirpPerSector_dBm=NaN throws badMaxEirp');
end

% =====================================================================
% T21: numBeams vs numUesPerSector conflict warns; numUesPerSector wins.
% =====================================================================
function r = t_num_beams_conflict(r)
    opts = smallOpts();
    opts.numBeams        = 4;
    opts.numUesPerSector = 3;

    % Disable every other warning (e.g. the unrelated coarse-grid power
    % self-check soft warning) and re-enable ONLY the conflict id, so the
    % conflict warning is the sole one that can update lastwarn after it
    % fires (disabled warnings do not update lastwarn). Restore the full
    % prior warning state on exit.
    prevWarn = warning('off', 'all');
    cleanup  = onCleanup(@() warning(prevWarn)); %#ok<NASGU>
    warning('on', 'runR23AasEirpCdfGrid:numBeamsConflict');
    lastwarn('');

    out = runR23AasEirpCdfGrid(opts);

    [~, lastId] = lastwarn();
    okWarn = strcmp(lastId, 'runR23AasEirpCdfGrid:numBeamsConflict');
    okWins = out.stats.numBeams == 3;
    r = check(r, okWarn && okWins, sprintf( ...
        ['T21: numBeams=4 / numUesPerSector=3 conflict fires ' ...
         'numBeamsConflict (warn=%d) and numUesPerSector wins ' ...
         '(numBeams=%d, wins=%d)'], okWarn, out.stats.numBeams, okWins));
end

% =====================================================================
% T22: an unopenable outputMetadataPath warns cannotOpenSidecar.
% =====================================================================
function r = t_unopenable_sidecar_warns(r)
    % writeMetadataSidecar mkdir()s a missing PARENT, so a nonexistent
    % file path would just be created. Pointing outputMetadataPath at an
    % EXISTING DIRECTORY makes fopen-for-write return -1 on all platforms
    % (and its parent already exists, so no mkdir is attempted).
    sidecarDir = tempname;
    mkdir(sidecarDir);                              % existing dir -> fopen 'w' fails
    cleanupDir = onCleanup(@() rmdirIfExists(sidecarDir)); %#ok<NASGU>
    oMeta = smallOpts();
    oMeta.outputMetadataPath = sidecarDir;          % point the sidecar AT a directory
    ok22 = warnsId(@() runR23AasEirpCdfGrid(oMeta), ...
                   'runR23AasEirpCdfGrid:cannotOpenSidecar');
    r = check(r, ok22, ...
        'T22: unopenable outputMetadataPath warns runR23AasEirpCdfGrid:cannotOpenSidecar');
end

% =====================================================================
% T23: a non-char name-value name throws badNV.
% =====================================================================
function r = t_bad_name_value_name(r)
    % A struct first arg is treated as flat opts; the trailing numeric
    % lands in a name slot. extractGeometryNameValues skips a non-char
    % name (continue), so it falls through to the badNV guard.
    ok23 = throwsId(@() runR23AasEirpCdfGrid(struct('numMc',4), 7, 'x'), ...
                    'runR23AasEirpCdfGrid:badNV');
    r = check(r, ok23, ...
        'T23: non-char name-value name throws runR23AasEirpCdfGrid:badNV');
end

% =====================================================================
% T24: mcChunkSize validation and deterministic chunking.
% =====================================================================
function r = t_mc_chunk_size(r)
    opts = smallOpts();
    opts.numMc = 7;
    opts.seed = 123;
    opts.mcChunkSize = opts.numMc;
    unchunked = runR23AasEirpCdfGrid(opts);

    opts.mcChunkSize = 3;
    quietText = evalc('chunked = runR23AasEirpCdfGrid(opts);');
    same = isequal(unchunked.stats.counts, chunked.stats.counts) && ...
           isequaln(unchunked.stats.sum_lin_mW, chunked.stats.sum_lin_mW) && ...
           isequaln(unchunked.stats.min_dBm, chunked.stats.min_dBm) && ...
           isequaln(unchunked.stats.max_dBm, chunked.stats.max_dBm) && ...
           isequaln(unchunked.percentileMaps.values, chunked.percentileMaps.values);
    echoed = chunked.stats.opts.mcChunkSize == 3;
    quiet = ~contains(quietText, '[R23-MC]') && ...
            ~contains(quietText, 'Percentile Maps') && ...
            ~contains(quietText, 'Elapsed time');

    badId = 'runR23AasEirpCdfGrid:badMcChunkSize';
    badZero = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'mcChunkSize', 0)), badId); %#ok<SFLD>
    badFrac = throwsId(@() runR23AasEirpCdfGrid(setfield(smallOpts(), ...
        'mcChunkSize', 2.5)), badId); %#ok<SFLD>

    r = check(r, same && echoed && quiet && badZero && badFrac, sprintf( ...
        ['T24: mcChunkSize chunking is deterministic, echoed, quiet, and ', ...
         'validates zero/fractional values ', ...
         '(same=%d echo=%d quiet=%d zero=%d frac=%d)'], ...
        same, echoed, quiet, badZero, badFrac));
end

% =====================================================================
% Helpers
% =====================================================================
function tf = throwsId(fn, id)
%THROWSID True when FN errors with the exact MException identifier ID.
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end

function tf = warnsId(fn, id)
%WARNSID True when FN raises a warning with the exact identifier ID.
    prev = warning('error', id);             % promote this warning to an error
    restore = onCleanup(@() warning(prev));  %#ok<NASGU> restore on exit
    tf = false;
    try, fn(); catch err, tf = strcmp(err.identifier, id); end
end

function deleteIfExists(p)
%DELETEIFEXISTS Best-effort delete of a temp file (never raises).
    if exist(p, 'file') == 2
        try
            delete(p);
        catch
            % Leave the temp file on any failure; not fatal to the test.
        end
    end
end

function rmdirIfExists(d)
%RMDIRIFEXISTS Best-effort delete of a temp dir (never raises).
    if exist(d, 'dir') == 7
        try, rmdir(d, 's'); catch, end
    end
end

function opts = smallOpts()
    opts = struct();
    opts.numMc       = 8;
    opts.azGridDeg   = -30:10:30;     % 7
    opts.elGridDeg   = -10:5:10;      % 5
    opts.binEdgesDbm = -80:5:120;
    opts.percentiles = [5 50 95];
    opts.seed        = 1;
    opts.numBeams    = 3;
    opts.deployment  = 'macroUrban';
end

function out = runSmall(extra)
    opts = smallOpts();
    flds = fieldnames(extra);
    for k = 1:numel(flds)
        opts.(flds{k}) = extra.(flds{k});
    end
    out = runR23AasEirpCdfGrid(opts);
end

function tf = hasBannedField(s, tokens)
    tf = hasBannedFieldExcept(s, tokens, {});
end

function tf = hasBannedFieldExcept(s, tokens, exceptFields)
    if ~isstruct(s)
        tf = false;
        return;
    end
    flds = fieldnames(s);
    lf = lower(flds);
    tf = false;
    for k = 1:numel(lf)
        if any(strcmpi(flds{k}, exceptFields))
            continue;
        end
        for t = 1:numel(tokens)
            if ~isempty(strfind(lf{k}, tokens{t})) %#ok<STREMP>
                tf = true;
                return;
            end
        end
    end
end

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
