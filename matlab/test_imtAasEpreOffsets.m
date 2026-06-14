function results = test_imtAasEpreOffsets()
%TEST_IMTAASEPREOFFSETS Unit tests for the TS 38.214 Clause 4.1 EPRE lookup.
%
%   RESULTS = test_imtAasEpreOffsets()
%
%   Asserts the exact dB values from 3GPP TS 38.214 V19.2.0 Clause 4.1:
%       * DM-RS boost (Table 4.1-1): 1 CDM group -> 0, 2 -> 3, 3 -> 4.77.
%       * Config type 1 + 3 CDM groups errors.
%       * PT-RS state 0 layers 1..6 (Table 4.1-2)  -> [0 3 4.77 6 7 7.78].
%       * PT-RS state 0 layers 7..8 (Table 4.1-2A) -> 8.45, 9 (enh DM-RS).
%       * PT-RS state 1 -> 0 for all layers.
%       * PT-RS states 2/3 reserved -> error.
%       * Layers 7..8 without dmrsTypeEnh -> error.
%       * csirsOffsetDb passthrough; hottestBoostDb = max(dmrs, ptrs).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;
    tol = 1e-12;

    % ---- DM-RS Table 4.1-1 boosts -----------------------------------
    o1 = imtAasEpreOffsets(struct('dmrsCdmGroupsNoData', 1));
    results = check(results, abs(o1.dmrsBoostDb - 0) <= tol, ...
        'DM-RS 1 CDM group -> 0 dB boost');

    o2 = imtAasEpreOffsets(struct('dmrsCdmGroupsNoData', 2));
    results = check(results, abs(o2.dmrsBoostDb - 3) <= tol, ...
        'DM-RS 2 CDM groups -> 3 dB boost');

    o3 = imtAasEpreOffsets(struct('dmrsConfigType', 2, 'dmrsCdmGroupsNoData', 3));
    results = check(results, abs(o3.dmrsBoostDb - 4.77) <= tol, ...
        'DM-RS 3 CDM groups (config type 2) -> 4.77 dB boost');

    % ---- config type 1 + 3 CDM groups errors ------------------------
    results = check(results, throwsWithId( ...
        @() imtAasEpreOffsets(struct('dmrsConfigType', 1, 'dmrsCdmGroupsNoData', 3)), ...
        'imtAasEpreOffsets:invalidCdmGroups'), ...
        'config type 1 + 3 CDM groups -> invalidCdmGroups error');

    % ---- PT-RS Table 4.1-2 (state 0, no enhanced DM-RS) layers 1..6 --
    expect126 = [0, 3, 4.77, 6, 7, 7.78];
    ok126 = true;
    for L = 1:6
        oL = imtAasEpreOffsets(struct('includePtrs', true, 'pdschLayers', L));
        ok126 = ok126 && abs(oL.ptrsBoostDb - expect126(L)) <= tol;
    end
    results = check(results, ok126, ...
        'PT-RS state 0 layers 1..6 -> [0 3 4.77 6 7 7.78]');

    % ---- PT-RS Table 4.1-2A (state 0, enhanced DM-RS) layers 7..8 ----
    o7 = imtAasEpreOffsets(struct('includePtrs', true, 'dmrsTypeEnh', true, ...
        'pdschLayers', 7));
    o8 = imtAasEpreOffsets(struct('includePtrs', true, 'dmrsTypeEnh', true, ...
        'pdschLayers', 8));
    results = check(results, abs(o7.ptrsBoostDb - 8.45) <= tol && ...
                             abs(o8.ptrsBoostDb - 9) <= tol, ...
        'PT-RS state 0 layers 7..8 (enh DM-RS) -> 8.45, 9');

    % ---- PT-RS state 1 -> 0 for all layers --------------------------
    ok_s1 = true;
    for L = 1:6
        oL = imtAasEpreOffsets(struct('includePtrs', true, 'epreRatioState', 1, ...
            'pdschLayers', L));
        ok_s1 = ok_s1 && abs(oL.ptrsBoostDb - 0) <= tol;
    end
    results = check(results, ok_s1, 'PT-RS state 1 -> 0 dB for all layers');

    % ---- states 2 / 3 reserved -> error -----------------------------
    results = check(results, throwsWithId( ...
        @() imtAasEpreOffsets(struct('includePtrs', true, 'epreRatioState', 2)), ...
        'imtAasEpreOffsets:reservedEpreRatioState') && throwsWithId( ...
        @() imtAasEpreOffsets(struct('includePtrs', true, 'epreRatioState', 3)), ...
        'imtAasEpreOffsets:reservedEpreRatioState'), ...
        'PT-RS states 2/3 reserved -> reservedEpreRatioState error');

    % ---- layers 7..8 without dmrsTypeEnh -> error -------------------
    results = check(results, throwsWithId( ...
        @() imtAasEpreOffsets(struct('includePtrs', true, 'pdschLayers', 7)), ...
        'imtAasEpreOffsets:layersRequireEnhancedDmrs') && throwsWithId( ...
        @() imtAasEpreOffsets(struct('includePtrs', true, 'pdschLayers', 8)), ...
        'imtAasEpreOffsets:layersRequireEnhancedDmrs'), ...
        'PT-RS layers 7..8 without dmrsTypeEnh -> layersRequireEnhancedDmrs error');

    % ---- includePtrs false -> ptrsBoostDb 0 -------------------------
    oNoPtrs = imtAasEpreOffsets(struct('includePtrs', false, 'pdschLayers', 4));
    results = check(results, abs(oNoPtrs.ptrsBoostDb - 0) <= tol, ...
        'includePtrs false -> ptrsBoostDb 0 (PT-RS absent)');

    % ---- csirsOffsetDb passthrough ----------------------------------
    oCsi = imtAasEpreOffsets(struct('csirsPowerOffsetSsDb', -3));
    results = check(results, abs(oCsi.csirsOffsetDb - (-3)) <= tol, ...
        'csirsPowerOffsetSsDb passthrough to csirsOffsetDb');

    % ---- hottestBoostDb = max(dmrs, ptrs) ---------------------------
    % dmrs 3 dB (2 CDM groups), ptrs 6 dB (4 layers) -> hottest 6.
    oHot = imtAasEpreOffsets(struct('dmrsCdmGroupsNoData', 2, ...
        'includePtrs', true, 'pdschLayers', 4));
    results = check(results, abs(oHot.hottestBoostDb - 6) <= tol && ...
        abs(oHot.hottestBoostDb - max(oHot.dmrsBoostDb, oHot.ptrsBoostDb)) <= tol, ...
        'hottestBoostDb = max(dmrsBoostDb, ptrsBoostDb)');

    % dmrs 4.77 dB (3 CDM groups), ptrs 3 dB (2 layers) -> hottest 4.77.
    oHot2 = imtAasEpreOffsets(struct('dmrsConfigType', 2, 'dmrsCdmGroupsNoData', 3, ...
        'includePtrs', true, 'pdschLayers', 2));
    results = check(results, abs(oHot2.hottestBoostDb - 4.77) <= tol, ...
        'hottestBoostDb picks the DM-RS boost when it dominates');

    % ---- default config (no fields) ---------------------------------
    oDef = imtAasEpreOffsets();
    results = check(results, abs(oDef.dmrsBoostDb - 3) <= tol && ...
        abs(oDef.ptrsBoostDb - 0) <= tol && ...
        abs(oDef.hottestBoostDb - 3) <= tol && ...
        ischar(oDef.specReference) && ~isempty(oDef.specReference), ...
        'default config -> DM-RS 3 dB, no PT-RS, specReference populated');

    fprintf('\n--- test_imtAasEpreOffsets summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
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

function tf = throwsWithId(fn, expectedId)
%THROWSWITHID True if FN errors with the expected MException identifier.
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, expectedId);
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end
