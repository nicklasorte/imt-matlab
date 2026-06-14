function results = test_imtAasPrbWeights()
%TEST_IMTAASPRBWEIGHTS Unit tests for the per-UE PRB / bandwidth weighting.
%
%   RESULTS = test_imtAasPrbWeights()
%
%   Covers imtAasPrbWeights (SENSITIVITY-ONLY PRB / bandwidth weighting):
%       T1.  ueShares sums to 1 and wBeam sums to 1 for BOTH modes.
%       T2.  Fixed mode NORMALIZES the supplied weights to sum 1.
%       T3.  spread == 0 -> uniform shares AND consumes ZERO RNG; equal
%            fixed weights == 1/N shares.
%       T4.  Larger spread -> larger realized share variance (monotone
%            trend) and consumes exactly Nue randn draws.
%       T5.  Layer grouping: with a layering-style layerUeIndex, the
%            grouped-sum of wBeam per UE equals ueShares, and equal-UE-share
%            layers get 1/(Nue*r_u) each.
%       T6.  Participation ratio: Nue for equal shares, -> 1 as one UE
%            dominates, and within [1, Nue].
%       T7.  Strict validation errors (mode / weights / spread / layerUeIndex).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % ---- T1: shares + wBeam both sum to 1, both modes ---------------
    ue = (1:5).';
    rng(101);
    pwR = imtAasPrbWeights(ue, struct('mode', 'random', 'spread', 0.7));
    pwF = imtAasPrbWeights(ue, struct('mode', 'fixed', 'weights', [1 2 3 4 5]));
    ok1 = abs(sum(pwR.ueShares) - 1) <= 1e-12 && abs(sum(pwR.wBeam) - 1) <= 1e-12 && ...
          abs(sum(pwF.ueShares) - 1) <= 1e-12 && abs(sum(pwF.wBeam) - 1) <= 1e-12 && ...
          numel(pwR.wBeam) == numel(ue) && numel(pwF.ueShares) == 5;
    results = check(results, ok1, ...
        'T1: ueShares and wBeam sum to 1 for random and fixed modes');

    % ---- T2: fixed mode normalizes ----------------------------------
    pw2 = imtAasPrbWeights((1:3).', struct('mode', 'fixed', 'weights', [2 2 4]));
    ok2 = max(abs(pw2.ueShares - [0.25 0.25 0.5])) <= 1e-12 && ...
          max(abs(pw2.config.weights - [0.25 0.25 0.5])) <= 1e-12;
    results = check(results, ok2, ...
        'T2: fixed mode normalizes weights to sum 1');

    % ---- T3: spread 0 uniform + zero RNG; equal fixed == 1/N --------
    rng(2024);
    sBefore = rng;
    pw3 = imtAasPrbWeights((1:4).', struct('mode', 'random', 'spread', 0));
    sAfter = rng;
    pw3f = imtAasPrbWeights((1:4).', struct('mode', 'fixed', 'weights', [1 1 1 1]));
    ok3 = max(abs(pw3.ueShares - 0.25)) <= 1e-12 && ...
          isequal(sBefore.State, sAfter.State) && ...        % zero RNG consumed
          max(abs(pw3f.ueShares - 0.25)) <= 1e-12;
    results = check(results, ok3, ...
        'T3: spread 0 -> uniform shares + zero RNG; equal fixed == 1/N');

    % ---- T4: monotone variance trend + Nue randn draws -------------
    Nue = 8;
    ue4 = (1:Nue).';
    nTrials = 400;
    vars = zeros(1, 3);
    sigmas = [0.2 0.6 1.2];
    for s = 1:numel(sigmas)
        acc = zeros(1, nTrials);
        rng(7000 + s);
        for t = 1:nTrials
            pw = imtAasPrbWeights(ue4, struct('mode', 'random', 'spread', sigmas(s)));
            acc(t) = var(pw.ueShares);
        end
        vars(s) = mean(acc);
    end
    % Exactly Nue randn draws per call when sigma>0.
    rng(55);
    imtAasPrbWeights(ue4, struct('mode', 'random', 'spread', 0.5));
    randn(Nue, 1);                                          % consume Nue more
    s1State = rng;
    rng(55);
    randn(Nue, 1);                                          % consume Nue
    randn(Nue, 1);                                          % consume Nue
    s2State = rng;
    ok4 = vars(1) < vars(2) && vars(2) < vars(3) && ...
          isequal(s1State.State, s2State.State);
    results = check(results, ok4, sprintf( ...
        'T4: variance monotone (%.2e<%.2e<%.2e) and exactly Nue randn draws', ...
        vars(1), vars(2), vars(3)));

    % ---- T5: layer grouping via layerUeIndex ------------------------
    % UE 1 has 3 layers, UE 2 has 1, UE 3 has 2 (mimicking imtAasExpandUeLayers).
    layerUeIndex = [1 1 1 2 3 3].';
    rng(303);
    pw5 = imtAasPrbWeights(layerUeIndex, struct('mode', 'random', 'spread', 0.5));
    grouped = accumarray(layerUeIndex, pw5.wBeam, [3 1]);   % sum wBeam per UE
    ok5a = max(abs(grouped(:).' - pw5.ueShares(:).')) <= 1e-12;
    % Equal-UE-share check: each of UE u's layers == ueShares(u)/r_u.
    rOfU = accumarray(layerUeIndex, 1, [3 1]);
    us = pw5.ueShares(:);                                   % Nue x 1
    rr = rOfU(:);                                           % Nue x 1
    expPerBeam = us(layerUeIndex) ./ rr(layerUeIndex);
    ok5b = max(abs(pw5.wBeam - expPerBeam(:))) <= 1e-12;
    % And an explicit equal-shares layered case -> 1/(Nue*r_u).
    pw5e = imtAasPrbWeights(layerUeIndex, struct('mode', 'fixed', 'weights', [1 1 1]));
    expEq = (1 / 3) ./ rr(layerUeIndex);
    ok5c = max(abs(pw5e.wBeam - expEq(:))) <= 1e-12;
    % Gap case (UE 2 dropped by clipping): Nue = max = 3 but only 1,3 present;
    % wBeam must still sum to 1 (power conserved) and ueShares sum to 1.
    gapIdx = [1 1 3].';
    pw5g = imtAasPrbWeights(gapIdx, struct('mode', 'fixed', 'weights', [0.5 0.3 0.5]));
    ok5d = abs(sum(pw5g.wBeam) - 1) <= 1e-12 && abs(sum(pw5g.ueShares) - 1) <= 1e-12 && ...
           abs(pw5g.ueShares(2)) <= 1e-12;   % dropped UE has zero share
    ok5 = ok5a && ok5b && ok5c && ok5d;
    results = check(results, ok5, ...
        'T5: grouped wBeam==ueShares; equal layered==1/(Nue*r_u); gap conserves power');

    % ---- T6: participation ratio sensible ---------------------------
    pwEq  = imtAasPrbWeights((1:5).', struct('mode', 'fixed', 'weights', [1 1 1 1 1]));
    pwDom = imtAasPrbWeights((1:5).', struct('mode', 'fixed', 'weights', [0.96 0.01 0.01 0.01 0.01]));
    ok6 = abs(pwEq.participationRatio - 5) <= 1e-9 && ...
          pwDom.participationRatio < 1.2 && ...
          pwDom.participationRatio >= 1 && ...
          pwR.participationRatio >= 1 && pwR.participationRatio <= 5 + 1e-9;
    results = check(results, ok6, sprintf( ...
        'T6: participation ratio equal==%.2f, dominated==%.3f (in [1,Nue])', ...
        pwEq.participationRatio, pwDom.participationRatio));

    % ---- T7: strict validation errors -------------------------------
    okMode = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'nope')), ...
        'imtAasPrbWeights:invalidMode');
    okW1 = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'fixed', 'weights', [1 1])), ...
        'imtAasPrbWeights:invalidWeights');   % wrong length
    okW2 = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'fixed', 'weights', [0 0 0])), ...
        'imtAasPrbWeights:invalidWeights');   % all zero
    okW3 = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'fixed', 'weights', [1 -1 1])), ...
        'imtAasPrbWeights:invalidWeights');   % negative
    okW4 = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'fixed')), ...
        'imtAasPrbWeights:invalidWeights');   % missing weights
    okS = throwsId(@() imtAasPrbWeights((1:3).', struct('mode', 'random', 'spread', -1)), ...
        'imtAasPrbWeights:invalidSpread');
    okL1 = throwsId(@() imtAasPrbWeights([], struct('mode', 'random')), ...
        'imtAasPrbWeights:invalidLayerUeIndex');   % empty
    okL2 = throwsId(@() imtAasPrbWeights([1 2.5].', struct('mode', 'random')), ...
        'imtAasPrbWeights:invalidLayerUeIndex');   % non-integer
    ok7 = okMode && okW1 && okW2 && okW3 && okW4 && okS && okL1 && okL2;
    results = check(results, ok7, ...
        'T7: strict validation errors (mode/weights/spread/layerUeIndex)');

    fprintf('\n--- test_imtAasPrbWeights summary ---\n');
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
