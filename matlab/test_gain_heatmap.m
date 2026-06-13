function results = test_gain_heatmap()
%TEST_GAIN_HEATMAP Self tests for the first-class GAIN heatmap output.
%
%   RESULTS = test_gain_heatmap()
%
%   Exercises the non-breaking opts.outputDomain knob added to
%   runR23AasEirpCdfGrid, which lets the R23 IMT-AAS Monte Carlo produce an
%   antenna GAIN heatmap (realized served-beam composite gain in dBi, the
%   MAX over simultaneous beams) alongside the existing EIRP heatmap (dBm).
%
%   The gain map is geometry-agnostic: it must work unchanged for the ITU
%   baseline ('r23_1x3_default'), the CTIA case ('ctia_7ghz_1x6'), and any
%   'custom' geometry, because the antenna geometry already flows through
%   params.
%
%   Tests covered (small fast Monte Carlo configs, fixed seed):
%     1. Back-compat invariant: omitting outputDomain == 'eirp'; EIRP
%        percentileMaps identical; gain not computed (empty .values).
%     2. outputDomain='gain' adds a finite gain map of the right shape and
%        leaves the EIRP percentileMaps additive-only (unchanged).
%     3. Geometry-agnostic: ITU vs CTIA gain maps differ; the peak realized
%        gain is within ~1.5 dB of calculatedAntennaGainDbi for each.
%     4. Custom geometry path returns a finite gain map of correct shape
%        (the gain map is not hard-wired to a named preset).
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_gain_heatmap ---\n');

    % ===== 1. back-compat invariant (default == 'eirp') =====
    base  = baseOpts('r23_1x3_default');
    optsEirp = base; optsEirp.outputDomain = 'eirp';
    rDef  = runR23AasEirpCdfGrid(base);
    rEirp = runR23AasEirpCdfGrid(optsEirp);

    assert(strcmp(rDef.opts.outputDomain, 'eirp') || ...
           strcmp(rDef.metadata.outputDomain, 'eirp'), ...
        'default outputDomain must resolve to ''eirp''');
    assert(isequal(rDef.percentileMaps.values, rEirp.percentileMaps.values), ...
        'default and explicit-eirp EIRP percentileMaps must be identical');
    assert(isempty(rDef.gainPercentileMaps.values), ...
        'gain must NOT be computed by default (.values must be empty)');
    assert(rDef.metadata.computeGain == false, ...
        'metadata.computeGain must be false by default');
    fprintf('  [OK] default == ''eirp''; EIRP identical; gain not computed\n');

    % ===== 2. gain requested adds maps; EIRP unchanged (additive only) ====
    optsGain = base; optsGain.outputDomain = 'gain';
    rGain = runR23AasEirpCdfGrid(optsGain);
    assert(rGain.metadata.computeGain == true, ...
        'metadata.computeGain must be true for outputDomain=''gain''');
    v = rGain.gainPercentileMaps.values;
    assert(~isempty(v) && all(isfinite(v(:))), ...
        'gain percentileMaps.values must be non-empty and finite');
    assert(isequal(size(v, 1), numel(rGain.gainPercentileMaps.azGrid)), ...
        'gain map dim-1 (Naz) must match azGrid length');
    assert(isequal(size(v, 2), numel(rGain.gainPercentileMaps.elGrid)), ...
        'gain map dim-2 (Nel) must match elGrid length');
    assert(strcmp(rGain.gainPercentileMaps.units, 'dBi'), ...
        'gain percentileMaps units must be dBi');
    assert(isequal(rGain.percentileMaps.values, rEirp.percentileMaps.values), ...
        'EIRP percentileMaps must be unchanged when gain is requested (additive only)');
    fprintf('  [OK] outputDomain=''gain'' adds finite dBi gain map; EIRP additive-only\n');

    % ===== 3. geometry-agnostic: ITU vs CTIA =====
    rITU  = runR23AasEirpCdfGrid(baseOpts('r23_1x3_default', 'gain'));
    rCTIA = runR23AasEirpCdfGrid(baseOpts('ctia_7ghz_1x6',   'gain'));

    gPeakITU  = rITU.metadata.aasGeometry.calculatedAntennaGainDbi;
    gPeakCTIA = rCTIA.metadata.aasGeometry.calculatedAntennaGainDbi;

    % values(:,:,end) is the highest requested percentile (100th -> per-cell
    % max realized gain); its max over the grid is the global peak realized
    % gain, which must sit within ~1.5 dB of the analytic antenna gain.
    obsPeakITU  = max(rITU.gainPercentileMaps.values(:, :, end),  [], 'all');
    obsPeakCTIA = max(rCTIA.gainPercentileMaps.values(:, :, end), [], 'all');
    assert(abs(obsPeakITU  - gPeakITU)  < 1.5, ...
        'ITU peak realized gain %.2f dBi differs from analytic %.2f dBi by > 1.5 dB', ...
        obsPeakITU, gPeakITU);
    assert(abs(obsPeakCTIA - gPeakCTIA) < 1.5, ...
        'CTIA peak realized gain %.2f dBi differs from analytic %.2f dBi by > 1.5 dB', ...
        obsPeakCTIA, gPeakCTIA);
    assert(~isequal(rITU.gainPercentileMaps.values, rCTIA.gainPercentileMaps.values), ...
        'ITU and CTIA gain maps must differ (geometry flows through params)');
    fprintf(['  [OK] geometry-agnostic: ITU peak=%.2f dBi (~%.2f), ' ...
             'CTIA peak=%.2f dBi (~%.2f); maps differ\n'], ...
        obsPeakITU, gPeakITU, obsPeakCTIA, gPeakCTIA);

    % ===== 4. custom geometry path works (not hard-wired to a preset) =====
    customOpts = baseOpts('custom', 'gain');
    customOpts.arrayRows                                 = 8;
    customOpts.arrayCols                                 = 8;
    customOpts.subarrayElementRows                       = 4;
    customOpts.subarrayElementCols                       = 1;
    customOpts.subarrayElementVerticalSpacingLambda      = 0.7;
    customOpts.radiatingSubarrayHorizontalSpacingLambda  = 0.5;
    customOpts.radiatingSubarrayVerticalSpacingLambda    = 2.8;
    customOpts.subarrayDowntiltDeg                       = 3;
    customOpts.mechanicalDowntiltDeg                     = 6;
    customOpts.elementGainDbi                            = 6.4;
    customOpts.sectorEirpDbm                             = 78.3;
    customOpts.conductedPowerDbm                         = 46.1;

    rCustom = runR23AasEirpCdfGrid(customOpts);
    vC = rCustom.gainPercentileMaps.values;
    assert(rCustom.metadata.computeGain == true, ...
        'custom-geometry gain run must set metadata.computeGain=true');
    assert(~isempty(vC) && all(isfinite(vC(:))), ...
        'custom-geometry gain map must be non-empty and finite');
    assert(isequal(size(vC, 1), numel(rCustom.gainPercentileMaps.azGrid)), ...
        'custom gain map dim-1 (Naz) must match azGrid length');
    assert(isequal(size(vC, 2), numel(rCustom.gainPercentileMaps.elGrid)), ...
        'custom gain map dim-2 (Nel) must match elGrid length');
    fprintf('  [OK] custom geometry returns a finite gain map of correct shape\n');

    results.passed = true;
    fprintf('--- test_gain_heatmap PASSED ---\n');
end

% =====================================================================
% Small, fast Monte Carlo config. The 100th percentile is requested so
% values(:,:,end) is the per-cell max realized gain, making the peak
% assertion robust on a modest grid / draw count. The grid is fine enough
% (and covers the sector beam-pointing region) that the global max realized
% gain lands within ~1.5 dB of the analytic antenna gain.
% =====================================================================
function opts = baseOpts(geometryPreset, outputDomain)
    opts = struct();
    opts.aasGeometryPreset = geometryPreset;
    opts.numMc             = 40;
    opts.seed              = 5;
    opts.azGridDeg         = -90:2:90;     % 91 pts, covers the sector
    opts.elGridDeg         = -12:1:3;      % 16 pts, covers the beam gate
    opts.percentiles       = [5 50 95 100];
    if nargin >= 2 && ~isempty(outputDomain)
        opts.outputDomain = outputDomain;
    end
end
