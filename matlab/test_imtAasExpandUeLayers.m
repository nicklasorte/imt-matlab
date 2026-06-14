function results = test_imtAasExpandUeLayers()
%TEST_IMTAASEXPANDUELAYERS Unit tests for the rank / MU-MIMO layer expansion.
%
%   RESULTS = test_imtAasExpandUeLayers()
%
%   Covers imtAasExpandUeLayers:
%       T1.  IDENTITY: fixed rank 1 + spread 0 returns the input directions
%            unchanged and consumes ZERO RNG (rng state unchanged).
%       T2.  Fixed-rank-r count: totalLayers == r*N, realizedRankPerUe all r,
%            layerUeIndex correct, layer-1 == UE direction.
%       T3.  Rank PMF: realized ranks lie within the PMF support {1..R}.
%       T4.  Greedy clip: sum(r_u) > maxTotalLayers -> totalLayers ==
%            maxTotalLayers and clipped > 0.
%       T5.  Angular spread: rank>1 spread layers are offset from the UE
%            direction (mean offset ~ 0) and remain within the envelope.
%       T6.  Strict validation errors (rank / PMF / spread / maxLayers /
%            clipRule).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    sector = imtAasSingleSectorParams();

    % ---- T1: identity expansion, no RNG -----------------------------
    beams = imtAasGenerateBeamSet(3, sector, struct('seed', 777));
    rng(31415);
    sBefore = rng;
    exp1 = imtAasExpandUeLayers(beams, sector, ...
        struct('rank', 1, 'layerSpreadDeg', 0));
    sAfter = rng;
    ok1 = isequal(exp1.steerAzDeg(:), beams.steerAzDeg(:)) && ...
          isequal(exp1.steerElDeg(:), beams.steerElDeg(:)) && ...
          exp1.totalLayers == numel(beams.steerAzDeg) && ...
          all(exp1.realizedRankPerUe == 1) && ...
          isequal(sBefore.State, sAfter.State);   % zero RNG consumed
    results = check(results, ok1, ...
        'T1: rank1+spread0 identity expansion, directions unchanged, no RNG');

    % ---- T2: fixed-rank-r count -------------------------------------
    N = numel(beams.steerAzDeg);
    r = 2;
    exp2 = imtAasExpandUeLayers(beams, sector, ...
        struct('rank', r, 'layerSpreadDeg', 0, 'maxTotalLayers', 64));
    okLayer1 = true;
    for u = 1:N
        idx = find(exp2.layerUeIndex == u);
        if isempty(idx) || abs(exp2.steerAzDeg(idx(1)) - beams.steerAzDeg(u)) > 0 || ...
                abs(exp2.steerElDeg(idx(1)) - beams.steerElDeg(u)) > 0
            okLayer1 = false; break;
        end
    end
    ok2 = exp2.totalLayers == r * N && ...
          numel(exp2.steerAzDeg) == r * N && ...
          all(exp2.realizedRankPerUe == r) && ...
          numel(exp2.layerUeIndex) == r * N && ...
          exp2.clipped == 0 && okLayer1;
    results = check(results, ok2, ...
        'T2: fixed rank r -> totalLayers==r*N, ranks==r, layer-1==UE dir');

    % ---- T3: rank PMF support ---------------------------------------
    bigBeams = imtAasGenerateBeamSet(50, sector, struct('seed', 99));
    rng(2024);
    exp3 = imtAasExpandUeLayers(bigBeams, sector, ...
        struct('rank', [0.5 0.5], 'layerSpreadDeg', 0, 'maxTotalLayers', 1e6));
    rr = exp3.realizedRankPerUe;
    ok3 = all(ismember(rr, [1 2])) && ...
          exp3.totalLayers == sum(rr) && ...
          any(rr == 2) && any(rr == 1);   % PMF actually exercised both
    results = check(results, ok3, ...
        'T3: rank PMF realized ranks within support {1,2}');

    % ---- T4: greedy clipping ----------------------------------------
    exp4 = imtAasExpandUeLayers(beams, sector, ...
        struct('rank', 3, 'layerSpreadDeg', 0, 'maxTotalLayers', 8));
    % 3 UEs x rank 3 = 9 > 8 -> trim 1 layer.
    ok4 = exp4.totalLayers == 8 && exp4.clipped == 1 && ...
          sum(exp4.realizedRankPerUe) == 8 && ...
          numel(exp4.steerAzDeg) == 8;
    results = check(results, ok4, ...
        'T4: greedy clip -> totalLayers==maxTotalLayers, clipped surfaced');

    % ---- T5: angular spread statistics ------------------------------
    % Azimuth-only spread (sigmaEl=0) keeps elevation pinned so the offset
    % is unbiased by the elevation gate; small sigma keeps azimuth off the
    % +-60 edges so the mean offset stays ~0.
    spreadBeams = imtAasGenerateBeamSet(300, sector, struct('seed', 1234));
    rng(555);
    exp5 = imtAasExpandUeLayers(spreadBeams, sector, ...
        struct('rank', 2, 'layerSpreadDeg', [3 0], 'maxTotalLayers', 1e6));
    azLim = exp5.azLimitsDeg;
    elLim = exp5.elLimitsDeg;
    offsets = zeros(0, 1);
    for u = 1:numel(spreadBeams.steerAzDeg)
        idx = find(exp5.layerUeIndex == u);
        if numel(idx) >= 2
            offsets(end+1, 1) = exp5.steerAzDeg(idx(2)) - spreadBeams.steerAzDeg(u); %#ok<AGROW>
        end
    end
    withinEnv = all(exp5.steerAzDeg >= azLim(1) - 1e-9 & exp5.steerAzDeg <= azLim(2) + 1e-9) && ...
                all(exp5.steerElDeg >= elLim(1) - 1e-9 & exp5.steerElDeg <= elLim(2) + 1e-9);
    ok5 = ~isempty(offsets) && abs(mean(offsets)) < 1.0 && ...
          std(offsets) > 0.5 && withinEnv;
    results = check(results, ok5, sprintf( ...
        'T5: spread offsets centered (mean %.3f deg) and within envelope', ...
        mean(offsets)));

    % ---- T6: strict validation errors -------------------------------
    okR  = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('rank', 2.5)), ...
        'imtAasExpandUeLayers:invalidRank');
    okR2 = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('rank', 0)), ...
        'imtAasExpandUeLayers:invalidRank');
    okP  = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('rank', [0.5 0.6])), ...
        'imtAasExpandUeLayers:invalidRankPmf');
    okP2 = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('rank', [-0.5 1.5])), ...
        'imtAasExpandUeLayers:invalidRankPmf');
    okM  = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('maxTotalLayers', 0)), ...
        'imtAasExpandUeLayers:invalidMaxLayers');
    okM2 = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('maxTotalLayers', 2.5)), ...
        'imtAasExpandUeLayers:invalidMaxLayers');
    okS  = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('layerSpreadDeg', -1)), ...
        'imtAasExpandUeLayers:invalidSpread');
    okS2 = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('layerSpreadDeg', [1 2 3])), ...
        'imtAasExpandUeLayers:invalidSpread');
    okC  = throwsId(@() imtAasExpandUeLayers(beams, sector, struct('clipRule', 'nope')), ...
        'imtAasExpandUeLayers:invalidClipRule');
    ok6 = okR && okR2 && okP && okP2 && okM && okM2 && okS && okS2 && okC;
    results = check(results, ok6, ...
        'T6: strict validation errors (rank/PMF/spread/maxLayers/clipRule)');

    fprintf('\n--- test_imtAasExpandUeLayers summary ---\n');
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

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
