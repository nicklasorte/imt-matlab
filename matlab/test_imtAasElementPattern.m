function results = test_imtAasElementPattern()
%TEST_IMTAASELEMENTPATTERN Focused unit tests for imtAasElementPattern.
%
%   RESULTS = test_imtAasElementPattern()
%
%   Covers:
%       1. At boresight (az=0, el=0) the element gain equals G_Emax = 6.4 dBi.
%       2. Output shape matches input shape (scalar / vector / 2-D).
%       3. Front-to-back floor: the worst-case attenuation is bounded by
%          A_m so gain >= G_Emax - A_m.
%       4. Outputs are finite for any finite input.
%       5. Symmetric in azimuth and elevation: pattern(az,el) =
%          pattern(-az,el) = pattern(az,-el).
%       6. Mismatched-size azDeg / elDeg raises imtAasElementPattern:sizeMismatch.
%       7. Non-finite input raises imtAasElementPattern:nonFiniteInput.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasElementPattern ---\n');

    p = imtAasDefaultParams();
    tol = 1e-9;

    % ===== 1. boresight = G_Emax =====
    g0 = imtAasElementPattern(0, 0, p);
    assert(abs(g0 - p.elementGainDbi) < tol, ...
        'boresight gain expected %.4f dBi, got %.6f dBi', ...
        p.elementGainDbi, g0);
    fprintf('  [OK] boresight gain = G_Emax (%.1f dBi)\n', p.elementGainDbi);

    % ===== 2. shape matching =====
    az = -10:5:10;
    el = -5:5:5;
    [AZ, EL] = ndgrid(az, el);
    G = imtAasElementPattern(AZ, EL, p);
    assert(isequal(size(G), size(AZ)), 'output shape must match input');
    fprintf('  [OK] shape preserved (5x3 grid)\n');

    % ===== 3. front-to-back floor =====
    azFull = -180:30:180;
    elFull = -90:15:90;
    [AZ, EL] = ndgrid(azFull, elFull);
    Gfull = imtAasElementPattern(AZ, EL, p);
    floorDbi = p.elementGainDbi - p.frontToBackDb;
    assert(all(Gfull(:) >= floorDbi - tol), ...
        'all gains must be >= G_Emax - A_m = %g dBi', floorDbi);
    assert(all(Gfull(:) <= p.elementGainDbi + tol), ...
        'no gain may exceed G_Emax');
    fprintf('  [OK] gain bounded in [G_Emax - A_m, G_Emax] = [%.1f, %.1f]\n', ...
        floorDbi, p.elementGainDbi);

    % ===== 4. finiteness =====
    assert(all(isfinite(Gfull(:))), 'all element gains must be finite');
    fprintf('  [OK] all gains finite over full sphere sample\n');

    % ===== 5. az/el symmetry =====
    gPlus  = imtAasElementPattern( 30,  10, p);
    gMinus = imtAasElementPattern(-30,  10, p);
    assert(abs(gPlus - gMinus) < tol, ...
        'pattern must be even in az: got %g vs %g', gPlus, gMinus);
    gP2 = imtAasElementPattern(20,  15, p);
    gM2 = imtAasElementPattern(20, -15, p);
    assert(abs(gP2 - gM2) < tol, ...
        'pattern must be even in el: got %g vs %g', gP2, gM2);
    fprintf('  [OK] pattern is even in azimuth and elevation\n');

    % ===== 6. size-mismatch error =====
    threw = false;
    try
        imtAasElementPattern([0 1 2], [0 1], p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasElementPattern:sizeMismatch'), ...
            'expected imtAasElementPattern:sizeMismatch, got %s', err.identifier);
    end
    assert(threw, 'mismatched-size input must error');
    fprintf('  [OK] size-mismatched inputs raise sizeMismatch\n');

    % ===== 7. non-finite input error =====
    threw = false;
    try
        imtAasElementPattern(Inf, 0, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasElementPattern:nonFiniteInput'), ...
            'expected imtAasElementPattern:nonFiniteInput, got %s', ...
            err.identifier);
    end
    assert(threw, 'Inf input must error');
    fprintf('  [OK] non-finite inputs raise nonFiniteInput\n');

    results.passed = true;
    fprintf('--- test_imtAasElementPattern PASSED ---\n');
end
