function [compositeGainDbi, sel] = imtAasExternalBeamGain(azGridDeg, ...
        elGridDeg, steerAzDeg, steerElDeg, beamset, opts)
%IMTAASEXTERNALBEAMGAIN Composite gain from an external PMI beam set.
%
%   COMPOSITEGAINDBI = imtAasExternalBeamGain(AZGRIDDEG, ELGRIDDEG, ...
%                          STEERAZDEG, STEERELDEG, BEAMSET)
%   [COMPOSITEGAINDBI, SEL] = imtAasExternalBeamGain(..., OPTS)
%
%   Given a PANEL-FRAME steering direction, selects one beam from an
%   external beam set (see imtAasLoadExternalBeamset) and returns that
%   beam's ABSOLUTE composite gain in dBi over the requested az/el grid.
%
%   The return contract matches imtAasCompositeGain's: an absolute
%   composite gain in dBi, NOT an array-factor contribution. Nothing is
%   added to it downstream -- the delivered patterns already include the
%   element pattern, the sub-array factor and the array factor.
%
%   FRAME: STEERAZDEG / STEERELDEG and AZGRIDDEG / ELGRIDDEG are all
%   PANEL-FRAME, pre-mechanical-tilt, matching the delivered beam set's
%   own convention (metadata tilt fields are 0). imtAasCompositeGain
%   performs the sector->panel rotation before calling this function; the
%   pattern is never rotated again here.
%
%   BEAM SELECTION (OPTS.mode):
%     'exhaustive' (DEFAULT) -- evaluate EVERY beam's gain at the single
%         requested (steerAz, steerEl) and take the argmax. This is the
%         real-world PMI-feedback selection rule and mirrors the
%         'exhaustive' max-gain validation mode of imt_aas_codebook_select.
%         PMI index ordering is arbitrary in the delivered files (the
%         vendor's own doc comment says so), so index arithmetic is never
%         used to pick a beam.
%         Vectorized: the four bracketing grid indices are resolved once
%         and a single bilinear combination is taken ACROSS the beam
%         dimension, so cost is O(numBeams), not numBeams interp2 calls.
%     'nearestPeak' -- pick the beam whose recorded peak direction is
%         nearest the request (great-circle angle). Cheaper, and analogous
%         to imt_aas_codebook_select's 'nearest' mode, but it ignores
%         pattern shape and can differ from the true max-gain beam.
%
%   OUT-OF-DOMAIN HANDLING:
%   Azimuth is WRAPPED into the delivered az domain when that domain spans
%   a full 360 deg (the delivered files span -180..180), because a wrapped
%   direction is physically inside the pattern, not outside it. Any point
%   that still falls outside the delivered az/el domain returns
%   BEAMSET.gainFloorDbi -- the delivered floor/null sentinel (-300 dBi in
%   the delivered files), NEVER 0 dBi. Returning 0 would be read
%   downstream as a real 0 dBi gain.
%
%   INPUTS:
%       AZGRIDDEG, ELGRIDDEG  grid spec, same handling as
%                             imtAasCompositeGain (scalar / vector / 2-D),
%                             normalized via imtAasNormalizeGrid.
%       STEERAZDEG, STEERELDEG  real finite scalars [deg], panel frame.
%       BEAMSET               struct from imtAasLoadExternalBeamset with
%                             .type = 'patterns'.
%       OPTS                  optional struct:
%                               mode  'exhaustive' (default) | 'nearestPeak'
%
%   OUTPUTS:
%       COMPOSITEGAINDBI  absolute composite gain [dBi], size of the
%                         normalized az/el grid.
%       SEL               struct: beamIndex, gainAtSteerDbi,
%                         peakGainDbi, peakAzDeg, peakElDeg, mode,
%                         steerAzDeg, steerElDeg (as evaluated, wrapped).
%
%   ERROR IDENTIFIERS:
%       imtAasExternalBeamGain:notEnoughInputs
%       imtAasExternalBeamGain:invalidBeamset
%       imtAasExternalBeamGain:unsupportedType
%       imtAasExternalBeamGain:invalidSteer
%       imtAasExternalBeamGain:invalidMode
%
%   See also imtAasLoadExternalBeamset, imtAasCompositeGain,
%   imt_aas_codebook_select.

    if nargin < 5
        error('imtAasExternalBeamGain:notEnoughInputs', ...
            ['imtAasExternalBeamGain requires azGridDeg, elGridDeg, ', ...
             'steerAzDeg, steerElDeg and beamset.']);
    end
    if nargin < 6 || isempty(opts)
        opts = struct();
    end

    validateBeamset(beamset);
    mode = resolveMode(opts);
    validateSteerAngle(steerAzDeg, -180, 180, 'steerAzDeg');
    validateSteerAngle(steerElDeg,  -90,  90, 'steerElDeg');

    az = beamset.azDeg(:).';
    el = beamset.elDeg(:).';
    G  = beamset.gainDbi;            % [nAz x nEl x numBeams]
    floorDbi = beamset.gainFloorDbi;

    % ---- resolve the steering direction into the delivered domain ----
    steerAzEval = wrapIntoDomain(steerAzDeg, az);
    steerElEval = steerElDeg;

    % ---- beam selection ----------------------------------------------
    switch mode
        case 'exhaustive'
            gainsAtSteer = beamGainsAtPoint(G, az, el, ...
                steerAzEval, steerElEval, floorDbi);
            [bestGain, beamIndex] = max(gainsAtSteer);
        case 'nearestPeak'
            beamIndex = nearestPeakBeam(beamset, steerAzEval, steerElEval);
            gainsAtSteer = beamGainsAtPoint(G, az, el, ...
                steerAzEval, steerElEval, floorDbi, beamIndex);
            bestGain = gainsAtSteer(1);
    end

    % ---- evaluate the selected beam over the full requested grid ------
    [AZ, EL] = imtAasNormalizeGrid(azGridDeg, elGridDeg);
    AZq = wrapIntoDomain(AZ, az);

    % gainDbi(:,:,beamIndex) is [nAz x nEl]; interp2 wants V as
    % [numel(Y) x numel(X)], so transpose to [nEl x nAz] with X=az, Y=el.
    page = G(:, :, beamIndex).';
    compositeGainDbi = interp2(az, el, page, AZq, EL, 'linear', floorDbi);

    if nargout > 1
        sel = struct( ...
            'beamIndex',      beamIndex, ...
            'gainAtSteerDbi', bestGain, ...
            'peakGainDbi',    beamset.peakGainDbi(beamIndex), ...
            'peakAzDeg',      beamset.peakAzDeg(beamIndex), ...
            'peakElDeg',      beamset.peakElDeg(beamIndex), ...
            'mode',           mode, ...
            'steerAzDeg',     steerAzEval, ...
            'steerElDeg',     steerElEval);
    end
end

% =====================================================================

function gains = beamGainsAtPoint(G, az, el, aq, eq, floorDbi, beamSubset)
%BEAMGAINSATPOINT Bilinear gain of every beam at ONE (az, el) point.
%   Resolves the bracketing cell once and combines the four corners across
%   the whole beam dimension in a single vectorized expression. This is
%   the hot path: it runs once per steering direction per Monte Carlo
%   draw, so it must never loop over beams or call interp2 per beam.
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
%BRACKET Index pair and fractional weight for a query on a sorted axis.
    n = numel(axisVec);
    ok = true;
    if q < axisVec(1) || q > axisVec(end)
        i0 = 1; i1 = 1; t = 0; ok = false;
        return;
    end
    if n == 1
        i0 = 1; i1 = 1; t = 0;
        return;
    end
    i0 = find(axisVec <= q, 1, 'last');
    if i0 >= n
        i0 = n - 1;
    end
    i1 = i0 + 1;
    den = axisVec(i1) - axisVec(i0);
    if den <= 0
        t = 0;
    else
        t = (q - axisVec(i0)) / den;
    end
end

function idx = nearestPeakBeam(beamset, aq, eq)
%NEARESTPEAKBEAM Great-circle nearest recorded peak direction.
    pa = beamset.peakAzDeg(:);
    pe = beamset.peakElDeg(:);
    cosSep = sind(pe) * sind(eq) + cosd(pe) .* cosd(eq) .* cosd(pa - aq);
    [~, idx] = max(cosSep);
end

function q = wrapIntoDomain(q, axisVec)
%WRAPINTODOMAIN Wrap azimuth into the delivered domain when it spans 360.
%   The delivered files span az = -180..180, so a request at e.g. +181 deg
%   is physically inside the pattern at -179 deg, not out of domain. Only
%   applied when the axis genuinely spans a full circle; a partial-sector
%   beam set is left alone so its true domain edges still floor.
    span = axisVec(end) - axisVec(1);
    if abs(span - 360) > 1e-6
        return;
    end
    lo = axisVec(1);
    q = lo + mod(q - lo, 360);
    % mod maps the top edge to the bottom; keep an exact top-edge request.
    q(q < lo) = lo;
end

function validateBeamset(beamset)
    if ~isstruct(beamset) || ~isscalar(beamset)
        error('imtAasExternalBeamGain:invalidBeamset', ...
            'beamset must be a scalar struct from imtAasLoadExternalBeamset.');
    end
    required = {'type', 'numBeams', 'gainFloorDbi'};
    for i = 1:numel(required)
        if ~isfield(beamset, required{i})
            error('imtAasExternalBeamGain:invalidBeamset', ...
                'beamset is missing required field "%s".', required{i});
        end
    end
    if ~strcmp(beamset.type, 'patterns')
        error('imtAasExternalBeamGain:unsupportedType', ...
            ['imtAasExternalBeamGain supports beamset.type = ''patterns'' ', ...
             '(the delivered PMI layout); got ''%s''. Weight- and ', ...
             'direction-type beam sets are parsed and validated by ', ...
             'imtAasLoadExternalBeamset but have no gain path in this ', ...
             'change.'], char(string(beamset.type)));
    end
    needed = {'gainDbi', 'azDeg', 'elDeg', 'peakGainDbi', 'peakAzDeg', 'peakElDeg'};
    for i = 1:numel(needed)
        if ~isfield(beamset, needed{i}) || isempty(beamset.(needed{i}))
            error('imtAasExternalBeamGain:invalidBeamset', ...
                'beamset.%s is required and must be non-empty for type ''patterns''.', ...
                needed{i});
        end
    end
    if ndims(beamset.gainDbi) ~= 3
        error('imtAasExternalBeamGain:invalidBeamset', ...
            'beamset.gainDbi must be 3-D [nAz x nEl x numBeams].');
    end
end

function mode = resolveMode(opts)
    mode = 'exhaustive';
    if isstruct(opts) && isfield(opts, 'mode') && ~isempty(opts.mode)
        mode = opts.mode;
    end
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('imtAasExternalBeamGain:invalidMode', ...
            'opts.mode must be a char/string scalar.');
    end
    switch lower(mode)
        case 'exhaustive'
            mode = 'exhaustive';
        case 'nearestpeak'
            mode = 'nearestPeak';
        otherwise
            error('imtAasExternalBeamGain:invalidMode', ...
                ['opts.mode must be ''exhaustive'' or ''nearestPeak'' ', ...
                 '(got ''%s'').'], mode);
    end
end

function validateSteerAngle(value, lo, hi, name)
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('imtAasExternalBeamGain:invalidSteer', ...
            '%s must be a real finite scalar.', name);
    end
    if value < lo || value > hi
        error('imtAasExternalBeamGain:invalidSteer', ...
            '%s = %g is outside the supported range [%g, %g] deg.', ...
            name, value, lo, hi);
    end
end
