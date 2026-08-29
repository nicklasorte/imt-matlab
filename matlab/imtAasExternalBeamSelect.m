function [beamIdx, gainAtDirDbi] = imtAasExternalBeamSelect(steerAzDeg, ...
        steerElDeg, beamset, mode)
%IMTAASEXTERNALBEAMSELECT Pick external beam(s) for panel-frame direction(s).
%
%   BEAMIDX = imtAasExternalBeamSelect(STEERAZDEG, STEERELDEG, BEAMSET)
%   [BEAMIDX, GAINATDIRDBI] = imtAasExternalBeamSelect(..., MODE)
%
%   Returns, for each requested PANEL-FRAME direction, the index of the beam
%   an external beam set would form there, plus that beam's gain AT the
%   requested direction (not its peak gain -- see the note below).
%
%   This is the single definition of the external beam-selection rule. Both
%   imtAasExternalBeamGain (the gain path) and the runR23AasEirpCdfGrid
%   beam-coverage diagnostic call it, so the diagnostic can never drift from
%   the selection the gain path actually performed.
%
%   MODE:
%     'exhaustive' (default) -- evaluate EVERY beam's gain at the requested
%         direction and take the argmax: the real PMI-feedback rule. PMI
%         index ordering is arbitrary in the delivered files, so index
%         arithmetic is never used. Vectorized: the four bracketing grid
%         indices are resolved once per direction and combined across the
%         whole beam dimension in one shot.
%     'nearestPeak' -- nearest recorded peak direction (great circle).
%
%   STEERAZDEG / STEERELDEG may be scalars or equal-sized arrays; BEAMIDX
%   and GAINATDIRDBI come back the same size.
%
%   NOTE on interpreting the outputs: GAINATDIRDBI is the gain of the
%   selected beam at the STEERING direction. It is NOT the peak of that
%   beam, and it is NOT what sets the peak of a rendered EIRP/gain heatmap.
%   The heatmap paints the selected beam's WHOLE pattern onto the output
%   grid, so the achievable map peak is governed by
%   max(BEAMSET.peakGainDbi(unique(BEAMIDX))) -- the best peak among the
%   beams that were actually selected. Confusing the two makes a selected-
%   but-off-peak beam look like it contributed nothing.
%
%   Errors:
%       imtAasExternalBeamSelect:notEnoughInputs
%       imtAasExternalBeamSelect:invalidBeamset
%       imtAasExternalBeamSelect:sizeMismatch
%       imtAasExternalBeamSelect:invalidMode
%
%   See also imtAasExternalBeamGain, imtAasLoadExternalBeamset,
%   runR23AasEirpCdfGrid.

    if nargin < 3
        error('imtAasExternalBeamSelect:notEnoughInputs', ...
            'imtAasExternalBeamSelect requires steerAzDeg, steerElDeg and beamset.');
    end
    if nargin < 4 || isempty(mode)
        mode = 'exhaustive';
    end
    mode = resolveMode(mode);

    if ~isstruct(beamset) || ~isscalar(beamset) || ...
            ~isfield(beamset, 'gainDbi') || ~isfield(beamset, 'azDeg') || ...
            ~isfield(beamset, 'elDeg') || ~isfield(beamset, 'gainFloorDbi')
        error('imtAasExternalBeamSelect:invalidBeamset', ...
            ['beamset must be a scalar struct from imtAasLoadExternalBeamset ', ...
             'with gainDbi / azDeg / elDeg / gainFloorDbi.']);
    end
    if ~isequal(size(steerAzDeg), size(steerElDeg))
        error('imtAasExternalBeamSelect:sizeMismatch', ...
            'steerAzDeg and steerElDeg must have the same size.');
    end

    az = beamset.azDeg(:).';
    el = beamset.elDeg(:).';
    G  = beamset.gainDbi;
    floorDbi = beamset.gainFloorDbi;

    n = numel(steerAzDeg);
    beamIdx = zeros(size(steerAzDeg));
    gainAtDirDbi = zeros(size(steerAzDeg));

    for k = 1:n
        aq = wrapIntoDomain(steerAzDeg(k), az);
        eq = steerElDeg(k);
        switch mode
            case 'exhaustive'
                g = beamGainsAtPoint(G, az, el, aq, eq, floorDbi);
                [bg, bi] = max(g);
            case 'nearestPeak'
                bi = nearestPeakBeam(beamset, aq, eq);
                g  = beamGainsAtPoint(G, az, el, aq, eq, floorDbi, bi);
                bg = g(1);
        end
        beamIdx(k) = bi;
        gainAtDirDbi(k) = bg;
    end
end

% =====================================================================

function gains = beamGainsAtPoint(G, az, el, aq, eq, floorDbi, beamSubset)
%BEAMGAINSATPOINT Bilinear gain of every beam at ONE (az, el) point.
    numBeams = size(G, 3);
    if nargin >= 7 && ~isempty(beamSubset)
        beamIdx = beamSubset;
    else
        beamIdx = 1:numBeams;
    end
    [i0, i1, ta, okA] = bracket(az, aq);
    [j0, j1, tb, okE] = bracket(el, eq);
    if ~(okA && okE)
        gains = repmat(floorDbi, numel(beamIdx), 1);
        return;
    end
    g00 = reshape(G(i0, j0, beamIdx), [], 1);
    g10 = reshape(G(i1, j0, beamIdx), [], 1);
    g01 = reshape(G(i0, j1, beamIdx), [], 1);
    g11 = reshape(G(i1, j1, beamIdx), [], 1);
    gains = (1 - ta) * (1 - tb) * g00 + ta * (1 - tb) * g10 + ...
            (1 - ta) * tb       * g01 + ta * tb       * g11;
end

function [i0, i1, t, ok] = bracket(axisVec, q)
    n = numel(axisVec); ok = true;
    if q < axisVec(1) || q > axisVec(end)
        i0 = 1; i1 = 1; t = 0; ok = false; return;
    end
    if n == 1
        i0 = 1; i1 = 1; t = 0; return;
    end
    i0 = find(axisVec <= q, 1, 'last');
    if i0 >= n, i0 = n - 1; end
    i1 = i0 + 1;
    den = axisVec(i1) - axisVec(i0);
    if den <= 0, t = 0; else, t = (q - axisVec(i0)) / den; end
end

function idx = nearestPeakBeam(beamset, aq, eq)
    pa = beamset.peakAzDeg(:); pe = beamset.peakElDeg(:);
    cosSep = sind(pe) * sind(eq) + cosd(pe) .* cosd(eq) .* cosd(pa - aq);
    [~, idx] = max(cosSep);
end

function q = wrapIntoDomain(q, axisVec)
%WRAPINTODOMAIN Wrap azimuth into the delivered domain when it spans 360.
    span = axisVec(end) - axisVec(1);
    if abs(span - 360) > 1e-6, return; end
    lo = axisVec(1);
    q = lo + mod(q - lo, 360);
    q(q < lo) = lo;
end

function mode = resolveMode(mode)
    if isstring(mode) && isscalar(mode), mode = char(mode); end
    if ~ischar(mode)
        error('imtAasExternalBeamSelect:invalidMode', ...
            'mode must be a char/string scalar.');
    end
    switch lower(mode)
        case 'exhaustive',  mode = 'exhaustive';
        case 'nearestpeak', mode = 'nearestPeak';
        otherwise
            error('imtAasExternalBeamSelect:invalidMode', ...
                'mode must be ''exhaustive'' or ''nearestPeak'' (got ''%s'').', mode);
    end
end
