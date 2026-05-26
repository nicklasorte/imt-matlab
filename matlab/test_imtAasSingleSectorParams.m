function results = test_imtAasSingleSectorParams()
%TEST_IMTAASSINGLESECTORPARAMS Focused unit tests for imtAasSingleSectorParams.
%
%   RESULTS = test_imtAasSingleSectorParams()
%
%   Covers:
%       1. Default (no args) is macroUrban with bsHeight=18 m, cellRadius=400 m.
%       2. 'macroSuburban' deployment gives bsHeight=20 m, cellRadius=800 m.
%       3. All expected fields are present with correct types.
%       4. Default azLimitsDeg = [-60 60], elLimitsDeg = [-10 0],
%          boresightAzDeg = 0, sectorWidthDeg = 120, minUeDistance_m = 35,
%          ueHeight_m = 1.5.
%       5. The embedded params struct is the imtAasDefaultParams output.
%       6. Custom params struct passes through unchanged.
%       7. Non-string deployment raises imtAasSingleSectorParams:invalidDeployment.
%       8. Unknown deployment raises imtAasSingleSectorParams:unknownDeployment.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasSingleSectorParams ---\n');

    % ===== 1. default macroUrban =====
    s = imtAasSingleSectorParams();
    assert(strcmp(s.deployment, 'macroUrban'), 'default deployment = macroUrban');
    assert(s.bsHeight_m   == 18,  'macroUrban bsHeight_m expected 18');
    assert(s.cellRadius_m == 400, 'macroUrban cellRadius_m expected 400');
    fprintf('  [OK] default = macroUrban (18 m / 400 m)\n');

    % ===== 2. macroSuburban =====
    sSub = imtAasSingleSectorParams('macroSuburban');
    assert(strcmp(sSub.deployment, 'macroSuburban'));
    assert(sSub.bsHeight_m   == 20,  'macroSuburban bsHeight_m expected 20');
    assert(sSub.cellRadius_m == 800, 'macroSuburban cellRadius_m expected 800');
    fprintf('  [OK] macroSuburban (20 m / 800 m)\n');

    % ===== 3. expected fields =====
    expected = {'deployment','bsX_m','bsY_m','bsHeight_m','ueHeight_m', ...
                'cellRadius_m','minUeDistance_m','boresightAzDeg', ...
                'sectorWidthDeg','azLimitsDeg','elLimitsDeg','params'};
    for i = 1:numel(expected)
        assert(isfield(s, expected{i}), 'missing field "%s"', expected{i});
    end
    fprintf('  [OK] all expected fields present\n');

    % ===== 4. envelope defaults =====
    assert(isequal(s.azLimitsDeg, [-60, 60]),  'azLimitsDeg expected [-60 60]');
    assert(isequal(s.elLimitsDeg, [-10,  0]),  'elLimitsDeg expected [-10 0]');
    assert(s.boresightAzDeg  == 0,    'boresightAzDeg expected 0');
    assert(s.sectorWidthDeg  == 120,  'sectorWidthDeg expected 120');
    assert(s.minUeDistance_m == 35,   'minUeDistance_m expected 35');
    assert(s.ueHeight_m      == 1.5,  'ueHeight_m expected 1.5');
    assert(s.bsX_m == 0 && s.bsY_m == 0, 'BS centred at origin');
    fprintf('  [OK] sector envelope defaults correct\n');

    % ===== 5. embedded params = imtAasDefaultParams =====
    pDef = imtAasDefaultParams();
    assert(isequal(s.params, pDef), ...
        'embedded params must equal imtAasDefaultParams()');
    fprintf('  [OK] embedded params = imtAasDefaultParams()\n');

    % ===== 6. explicit params pass-through =====
    pCustom = pDef;
    pCustom.sectorEirpDbm = 60.0;
    sCustom = imtAasSingleSectorParams('macroUrban', pCustom);
    assert(sCustom.params.sectorEirpDbm == 60.0, ...
        'explicit params must pass through unchanged');
    fprintf('  [OK] custom params struct passes through\n');

    % ===== 7. non-string deployment =====
    threw = false;
    try
        imtAasSingleSectorParams(42); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, ...
            'imtAasSingleSectorParams:invalidDeployment'), ...
            'expected invalidDeployment, got %s', err.identifier);
    end
    assert(threw, 'numeric deployment must error');
    fprintf('  [OK] numeric deployment raises invalidDeployment\n');

    % ===== 8. unknown deployment =====
    threw = false;
    try
        imtAasSingleSectorParams('macroMystery'); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, ...
            'imtAasSingleSectorParams:unknownDeployment'), ...
            'expected unknownDeployment, got %s', err.identifier);
    end
    assert(threw, 'unknown deployment must error');
    fprintf('  [OK] unknown deployment raises unknownDeployment\n');

    results.passed = true;
    fprintf('--- test_imtAasSingleSectorParams PASSED ---\n');
end
