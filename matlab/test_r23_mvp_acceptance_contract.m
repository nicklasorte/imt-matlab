function results = test_r23_mvp_acceptance_contract()
%TEST_R23_MVP_ACCEPTANCE_CONTRACT MVP acceptance-contract gate for R23 EIRP CDF.
%
%   RESULTS = test_r23_mvp_acceptance_contract()
%
%   Locks down the R23 single-site / single-sector / N-UE EIRP CDF-grid
%   MVP as a product contract. This is intentionally narrow: it does NOT
%   re-derive antenna math (test_single_sector_eirp_mvp owns that) and it
%   does NOT chase deeper structural invariants (test_against_pycraf_strict
%   owns the antenna gate). It exists to catch drift that would silently
%   break callers of the MVP or smuggle out-of-scope modeling into the
%   core MVP files.
%
%   Sections:
%       C1.  Public MVP API exists (file + function callable).
%       C2.  R23 defaults are locked (UEs/sector, sector width, min UE
%            distance, BS height, BS EIRP, 8 x 16 array, +/- 60 deg az
%            coverage, [90, 100] global-theta vertical coverage,
%            [-10, 0] internal elevation coverage).
%       C3.  Vertical convention is explicit (rawThetaGlobalDeg,
%            steerThetaGlobalDeg, thetaGlobalLimitsDeg, theta = 90 - elev,
%            horizon and 10 deg downtilt cases).
%       C4.  Deterministic MVP behaviour for fixed seed (small grid /
%            small numSnapshots; same seed -> identical EIRP cube; cube
%            shape is grid_point x snapshot; CDF is monotonic).
%       C5.  Input-driven BS behaviour (bs.height_m, bs.azimuth_deg,
%            bs.eirp_dBm_per_100MHz overrides change downstream values
%            without mutating get_default_bs() defaults).
%       C6.  Scope guard: a static token scan of the MVP core MATLAB
%            files refuses out-of-scope tokens (path loss, clutter, FS /
%            FSS / victim receiver, 19-site / 57-sector aggregation, ...).
%       C7.  Legacy-reference hygiene: repo-wide best-effort scan finds
%            no occurrence of "EMBRSS" (any case).
%
%   Exit contract: RESULTS is a struct with fields .summary (cellstr) and
%   .passed (logical), matching the convention used by run_all_tests.m.

    results.summary = {};
    results.passed  = true;

    results = c1_public_api_exists(results);
    results = c2_r23_defaults_locked(results);
    results = c3_vertical_convention_explicit(results);
    results = c4_deterministic_mvp(results);
    results = c5_input_driven_bs(results);
    results = c6_scope_guard(results);
    results = c7_legacy_reference_hygiene(results);

    fprintf('\n--- test_r23_mvp_acceptance_contract summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL ACCEPTANCE CHECKS PASSED', 'ACCEPTANCE CHECKS FAILED'));
end

% =====================================================================
function r = c1_public_api_exists(r)
    expected = { ...
        'get_r23_aas_params', ...
        'validate_r23_params', ...
        'get_default_bs', ...
        'generate_single_sector_layout', ...
        'sample_ue_positions_in_sector', ...
        'compute_beam_angles_bs_to_ue', ...
        'clamp_beam_to_r23_coverage', ...
        'compute_bs_gain_toward_grid', ...
        'compute_eirp_grid', ...
        'run_monte_carlo_snapshots', ...
        'compute_cdf_per_grid_point', ...
        'run_single_sector_eirp_demo' };

    matlabDir = mvp_matlab_dir();
    missing = {};
    for i = 1:numel(expected)
        name = expected{i};
        % File present in matlab/?
        fp = fullfile(matlabDir, [name '.m']);
        fileOk = (exist(fp, 'file') == 2);
        % Function callable on path?
        callOk = (exist(name, 'file') == 2);
        if ~(fileOk && callOk)
            missing{end+1} = name; %#ok<AGROW>
        end
    end

    ok = isempty(missing);
    if ok
        msg = sprintf( ...
            'C1: all %d MVP public functions present and on the path', ...
            numel(expected));
    else
        msg = sprintf('C1: missing MVP functions: %s', ...
            strjoin(missing, ', '));
    end
    r = check(r, ok, msg);
end

% =====================================================================
function r = c2_r23_defaults_locked(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    okUes        = isfield(params, 'numUesPerSector') && ...
                   params.numUesPerSector == 3;
    okSectorWid  = bs.sector_width_deg == 120;
    okMinUeDist  = abs(layout.minUeDistance_m - 35) < 1e-9;
    okBsHeight   = bs.height_m == 18 && layout.bsHeight_m == 18;
    okBsEirp     = abs(bs.eirp_dBm_per_100MHz - 78.3) < 1e-9 && ...
                   abs(params.sectorEirpDbm     - 78.3) < 1e-9;
    okArray      = params.numRows == 8 && params.numColumns == 16;
    okHCoverage  = isequal(layout.azLimitsDeg, [-60, 60]) && ...
                   params.hCoverageDeg == 60;
    okVThetaCov  = isfield(layout, 'verticalCoverageGlobalThetaDeg') && ...
                   isequal(layout.verticalCoverageGlobalThetaDeg, [90, 100]);
    okVElCov     = isequal(layout.elLimitsDeg, [-10, 0]);

    okAll = okUes && okSectorWid && okMinUeDist && okBsHeight && ...
            okBsEirp && okArray && okHCoverage && okVThetaCov && okVElCov;

    if okAll
        msg = ['C2: R23 defaults locked (3 UEs, 120 deg sector, 35 m min, ' ...
               '18 m BS, 78.3 dBm, 8x16 array, +/-60 az, [90,100] theta, ' ...
               '[-10,0] elev)'];
    else
        msg = sprintf( ...
            ['C2: R23 defaults drifted: UEs=%g sectorWid=%g minDist=%g ' ...
             'bsH=%g eirp=%g rows=%g cols=%g hCov=%g vTheta=[%g %g] ' ...
             'vElev=[%g %g]'], ...
            params.numUesPerSector, bs.sector_width_deg, ...
            layout.minUeDistance_m, bs.height_m, ...
            bs.eirp_dBm_per_100MHz, params.numRows, params.numColumns, ...
            params.hCoverageDeg, ...
            layout.verticalCoverageGlobalThetaDeg(1), ...
            layout.verticalCoverageGlobalThetaDeg(2), ...
            layout.elLimitsDeg(1), layout.elLimitsDeg(2));
    end
    r = check(r, okAll, msg);
end

% =====================================================================
function r = c3_vertical_convention_explicit(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    % Build a UE 5 m below the BS at 200 m ground range -> small downtilt.
    ue = struct();
    ue.x_m = 200; ue.y_m = 0; ue.z_m = layout.bsHeight_m - 5;
    ue.r_m = 200;
    ue.azRelDeg    = 0;
    ue.azGlobalDeg = 0;
    ue.height_m    = ue.z_m;
    ue.N           = 1;
    ue.layout      = layout;

    raw = compute_beam_angles_bs_to_ue(bs, ue, params);
    okRawField = isfield(raw, 'rawThetaGlobalDeg');
    okRawConv  = okRawField && ...
                 abs(raw.rawThetaGlobalDeg - (90 - raw.rawElDeg)) < 1e-12;

    % Drive horizon (UE at BS height) and 10 deg downtilt geometrically.
    ueH = ue; ueH.z_m = layout.bsHeight_m; ueH.height_m = ueH.z_m;
    bH  = compute_beam_angles_bs_to_ue(bs, ueH, params);
    okHorizonEl    = abs(bH.rawElDeg)               < 1e-9;
    okHorizonTheta = abs(bH.rawThetaGlobalDeg - 90) < 1e-9;

    range = 200;
    dz = -range * tand(10);
    ueD = ueH; ueD.z_m = layout.bsHeight_m + dz; ueD.height_m = ueD.z_m;
    bD  = compute_beam_angles_bs_to_ue(bs, ueD, params);
    okDownEl    = abs(bD.rawElDeg - (-10))         < 1e-9;
    okDownTheta = abs(bD.rawThetaGlobalDeg - 100)  < 1e-9;

    % Clamp output exposes both forms.
    beamsRaw = struct();
    beamsRaw.rawAzDeg = [0; 0];
    beamsRaw.rawElDeg = [0; -10];
    beamsRaw.layout   = layout;
    cl = clamp_beam_to_r23_coverage(bs, beamsRaw, params);
    okSteerField = isfield(cl, 'steerThetaGlobalDeg');
    okLimField   = isfield(cl, 'thetaGlobalLimitsDeg');
    okSteerConv  = okSteerField && ...
                   isequal(cl.steerThetaGlobalDeg, 90 - cl.steerElDeg);
    okLimitVals  = okLimField && ...
                   isequal(cl.thetaGlobalLimitsDeg, [90, 100]);

    okAll = okRawField && okRawConv && ...
            okHorizonEl && okHorizonTheta && ...
            okDownEl && okDownTheta && ...
            okSteerField && okLimField && okSteerConv && okLimitVals;

    if okAll
        msg = ['C3: vertical convention explicit (rawThetaGlobalDeg, ' ...
               'steerThetaGlobalDeg, thetaGlobalLimitsDeg, ' ...
               'theta = 90 - elev, horizon and 10 deg downtilt mapped)'];
    else
        msg = sprintf( ...
            ['C3: vertical convention drift: ' ...
             'horizon=(%.6f,%.6f) downtilt=(%.6f,%.6f) ' ...
             'limits=(%g,%g)'], ...
            bH.rawElDeg, bH.rawThetaGlobalDeg, ...
            bD.rawElDeg, bD.rawThetaGlobalDeg, ...
            ifNum(okLimField, cl.thetaGlobalLimitsDeg(1), NaN), ...
            ifNum(okLimField, cl.thetaGlobalLimitsDeg(2), NaN));
    end
    r = check(r, okAll, msg);
end

% =====================================================================
function r = c4_deterministic_mvp(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    grid = struct( ...
        'azGridDeg', -20:10:20, ...
        'elGridDeg', -10:5:0);
    cfg = struct('numSnapshots', 5, 'numUes', 3, 'seed', 42);

    a = run_monte_carlo_snapshots(bs, grid, params, cfg);
    b = run_monte_carlo_snapshots(bs, grid, params, cfg);

    Naz = numel(grid.azGridDeg);
    Nel = numel(grid.elGridDeg);
    okShape = isequal(size(a.eirpGrid), [Naz, Nel, 5]);
    okEqual = isequal(a.eirpGrid, b.eirpGrid);

    cdf = compute_cdf_per_grid_point(a.eirpGrid, [10 50 90]);
    diffs  = diff(cdf.percentileEirpDbm, 1, 3);
    okMono = all(diffs(:) >= -1e-9);

    okAll = okShape && okEqual && okMono;
    if okAll
        msg = sprintf( ...
            'C4: MC snapshots deterministic (size=[%d %d 5], same seed -> equal, CDF monotonic)', ...
            Naz, Nel);
    else
        msg = sprintf( ...
            'C4: MC determinism failed (shape=%d equal=%d mono=%d)', ...
            okShape, okEqual, okMono);
    end
    r = check(r, okAll, msg);
end

% =====================================================================
function r = c5_input_driven_bs(r)
    params = get_r23_aas_params();

    % --- defaults snapshot (must NOT change after overrides) -----------
    defBefore = get_default_bs();

    % --- (a) bs.height_m override -> rawElDeg / global theta change ----
    layout = generate_single_sector_layout(defBefore, params);
    ue = struct();
    ue.x_m = 200; ue.y_m = 0; ue.z_m = layout.ueHeight_m;
    ue.r_m = 200;
    ue.azRelDeg = 0; ue.azGlobalDeg = 0;
    ue.height_m = ue.z_m;
    ue.N = 1; ue.layout = layout;

    bsLow = get_default_bs();
    bsLow.position_m = [0 0 5];
    bsLow.height_m   = 5;

    bsHigh = get_default_bs();
    bsHigh.position_m = [0 0 25];
    bsHigh.height_m   = 25;

    bLow  = compute_beam_angles_bs_to_ue(bsLow,  ue, params);
    bHigh = compute_beam_angles_bs_to_ue(bsHigh, ue, params);
    okHeightEl    = bHigh.rawElDeg          < bLow.rawElDeg;
    okHeightTheta = bHigh.rawThetaGlobalDeg > bLow.rawThetaGlobalDeg;

    % --- (b) bs.azimuth_deg override -> azRel changes -------------------
    bsRot = get_default_bs();
    bsRot.azimuth_deg = 30;
    raw    = compute_beam_angles_bs_to_ue(defBefore, ue, params);
    rawRot = compute_beam_angles_bs_to_ue(bsRot,     ue, params);
    okAzRot = abs((raw.rawAzDeg - rawRot.rawAzDeg) - 30) < 1e-9;

    % --- (c) bs.eirp_dBm_per_100MHz override -> per-beam peak shifts ---
    grid = struct('azGridDeg', -20:10:20, 'elGridDeg', -10:5:0);
    ue3 = struct();
    ue3.x_m = 200 .* ones(3,1);
    ue3.y_m = zeros(3,1);
    ue3.z_m = layout.ueHeight_m .* ones(3,1);
    ue3.r_m = 200 .* ones(3,1);
    ue3.azRelDeg    = zeros(3,1);
    ue3.azGlobalDeg = zeros(3,1);
    ue3.height_m    = ue3.z_m;
    ue3.slantRange_m = hypot(ue3.r_m, ue3.z_m - layout.bsHeight_m);
    ue3.N = 3; ue3.layout = layout;

    snapDef = compute_eirp_grid(defBefore, ue3, grid, params);
    bsLowE  = defBefore; bsLowE.eirp_dBm_per_100MHz = 70.0;
    snapLow = compute_eirp_grid(bsLowE, ue3, grid, params);
    deltaPerBeam = snapDef.perBeamPeakEirpDbm - snapLow.perBeamPeakEirpDbm;
    okEirpDelta  = abs(deltaPerBeam - 8.3) < 1e-6;

    % --- defaults must be unmodified -----------------------------------
    defAfter = get_default_bs();
    okDefaultsIntact = isequal(defBefore, defAfter);

    okAll = okHeightEl && okHeightTheta && okAzRot && okEirpDelta && ...
            okDefaultsIntact;
    if okAll
        msg = ['C5: BS overrides drive height (downtilt + global theta), ' ...
               'azimuth (azRel shift), and EIRP (per-beam peak); ' ...
               'get_default_bs() unchanged'];
    else
        msg = sprintf( ...
            ['C5: input-driven BS failed (heightEl=%d heightTheta=%d ' ...
             'az=%d eirp=%d defaultsIntact=%d delta=%.6f)'], ...
            okHeightEl, okHeightTheta, okAzRot, okEirpDelta, ...
            okDefaultsIntact, deltaPerBeam);
    end
    r = check(r, okAll, msg);
end

% =====================================================================
function r = c6_scope_guard(r)
    % Forbidden tokens that would indicate out-of-scope modeling sneaking
    % into the MVP core. Token matches are case-INsensitive substring
    % matches; keep the list narrow to avoid catching benign words.
    forbidden = { ...
        'p2001', ...
        'p2108', ...
        'pathloss', ...
        'clutterloss', ...
        'fsreceiver', ...
        'fssreceiver', ...
        'victimreceiver', ...
        'interferenceaggregation', ...
        'nineteensite', ...
        'fiftysevensector' };
    % Numeric-shape patterns: detect "numSites = 19" / "numSectors = 57"
    % regardless of whitespace; case-insensitive.
    forbiddenRegex = { ...
        'numsites\s*=\s*19', ...
        'numsectors\s*=\s*57' };

    coreFiles = { ...
        'get_default_bs.m', ...
        'generate_single_sector_layout.m', ...
        'sample_ue_positions_in_sector.m', ...
        'compute_beam_angles_bs_to_ue.m', ...
        'clamp_beam_to_r23_coverage.m', ...
        'compute_bs_gain_toward_grid.m', ...
        'compute_eirp_grid.m', ...
        'run_monte_carlo_snapshots.m', ...
        'compute_cdf_per_grid_point.m', ...
        'run_single_sector_eirp_demo.m' };

    matlabDir = mvp_matlab_dir();
    hits = {};
    for i = 1:numel(coreFiles)
        fp = fullfile(matlabDir, coreFiles{i});
        if exist(fp, 'file') ~= 2
            hits{end+1} = sprintf('%s: file missing', coreFiles{i}); %#ok<AGROW>
            continue;
        end
        txt = lower(read_text_file(fp));
        for j = 1:numel(forbidden)
            if ~isempty(strfind(txt, forbidden{j})) %#ok<STREMP>
                hits{end+1} = sprintf('%s: contains "%s"', ...
                    coreFiles{i}, forbidden{j}); %#ok<AGROW>
            end
        end
        for j = 1:numel(forbiddenRegex)
            if ~isempty(regexp(txt, forbiddenRegex{j}, 'once'))
                hits{end+1} = sprintf('%s: matches /%s/', ...
                    coreFiles{i}, forbiddenRegex{j}); %#ok<AGROW>
            end
        end
    end

    ok = isempty(hits);
    if ok
        msg = sprintf( ...
            'C6: scope guard clean across %d MVP core files', ...
            numel(coreFiles));
    else
        msg = sprintf('C6: scope guard hits: %s', ...
            strjoin(hits, ' | '));
    end
    r = check(r, ok, msg);
end

% =====================================================================
function r = c7_legacy_reference_hygiene(r)
%C7 Best-effort repo-wide scan for legacy "EMBRSS" tokens.
%
%   This is implemented as a directory walk under the repo root. If the
%   walk hits an unreadable file we treat it as a soft-skip and report
%   the limitation in the summary. The shell equivalent is:
%       grep -RIn "EMBRSS\|embrss\|Embrss" .

    repoRoot = mvp_repo_root();
    needles  = {'embrss'};
    skipDirs = {'.git', 'node_modules'};

    [hits, walkErr] = scan_repo_for_tokens(repoRoot, needles, skipDirs);
    ok = isempty(hits);
    if ok && isempty(walkErr)
        msg = 'C7: no EMBRSS / embrss / Embrss occurrences in repo';
    elseif ok && ~isempty(walkErr)
        msg = sprintf( ...
            'C7: no EMBRSS occurrences (walk had %d soft skips: %s)', ...
            numel(walkErr), strjoin(walkErr, '; '));
    else
        msg = sprintf('C7: EMBRSS hit(s): %s', ...
            strjoin(hits, ' | '));
    end
    r = check(r, ok, msg);
end

% =====================================================================
% Helpers
% =====================================================================

function d = mvp_matlab_dir()
    d = fileparts(mfilename('fullpath'));
end

function d = mvp_repo_root()
    d = fileparts(mvp_matlab_dir());
end

function txt = read_text_file(fp)
    fid = fopen(fp, 'r');
    if fid < 0
        txt = '';
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    raw = fread(fid, '*char');
    txt = raw(:).';
end

function [hits, errs] = scan_repo_for_tokens(rootDir, needles, skipDirs)
    hits = {};
    errs = {};
    stack = {rootDir};
    while ~isempty(stack)
        cur = stack{end};
        stack(end) = [];
        try
            entries = dir(cur);
        catch ex
            errs{end+1} = sprintf('%s: %s', cur, ex.message); %#ok<AGROW>
            continue;
        end
        for i = 1:numel(entries)
            e = entries(i);
            if strcmp(e.name, '.') || strcmp(e.name, '..')
                continue;
            end
            full = fullfile(cur, e.name);
            if e.isdir
                if any(strcmp(e.name, skipDirs))
                    continue;
                end
                stack{end+1} = full; %#ok<AGROW>
            else
                if ~looks_textual(e.name)
                    continue;
                end
                try
                    txt = lower(read_text_file(full));
                catch ex
                    errs{end+1} = sprintf('%s: %s', full, ex.message); %#ok<AGROW>
                    continue;
                end
                for j = 1:numel(needles)
                    if ~isempty(strfind(txt, needles{j})) %#ok<STREMP>
                        hits{end+1} = sprintf('%s contains "%s"', ...
                            full, needles{j}); %#ok<AGROW>
                        break;
                    end
                end
            end
        end
    end
end

function tf = looks_textual(name)
    binaryExt = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.pdf', ...
                 '.zip', '.tar', '.gz', '.7z', '.mat', '.mex', '.mexa64', ...
                 '.mexw64', '.mexmaci64', '.so', '.dll', '.dylib', ...
                 '.fig', '.exe'};
    [~, ~, ext] = fileparts(lower(name));
    tf = ~any(strcmp(ext, binaryExt));
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

function v = ifNum(cond, a, b)
    if cond, v = a; else, v = b; end
end
