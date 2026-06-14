function out = imtAasPrbWeights(layerUeIndex, prbCfg)
%IMTAASPRBWEIGHTS Per-UE PRB / bandwidth power-share weights (SENSITIVITY ONLY).
%
%   OUT = imtAasPrbWeights(LAYERUEINDEX, PRBCFG)
%
%   Pure-except-for-RNG weight generator for the optional, default-off
%   opts.prbWeighting sensitivity layer in runR23AasEirpCdfGrid. It replaces
%   the uniform per-beam power split (every co-scheduled UE gets an equal
%   1/N share of the sector power) with an UNEQUAL per-UE bandwidth (PRB)
%   weighting: each UE u is allocated a fractional bandwidth share f_u with
%   sum(f_u) = 1, and -- at constant EPRE (3GPP TS 38.214 V19.2.0 Clause
%   4.1) -- its band-integrated power is proportional to its PRB share. The
%   caller maps the returned per-beam linear power-fraction wBeam to the
%   per-beam peak EIRP via perBeamEirp = sectorEirp + 10*log10(wBeam) (the
%   dB conversion is NOT done here; this stays a pure weight generator).
%   Equal shares f_u = 1/N recover the current uniform model exactly.
%
%   *** SENSITIVITY ONLY -- DEPARTS FROM THE ITU M.2101 BASELINE ***
%   The ITU IMT characteristics (Table A-2, Note 1) specify that the
%   co-scheduled UEs SHARE THE CHANNEL BANDWIDTH EQUALLY (each UE is
%   allocated 1/N of the channel bandwidth). Equal split is a DEFINING
%   ASSUMPTION of the ITU reference, not an incidental default. Unequal PRB
%   weighting is therefore an explicitly-labelled sensitivity scenario that
%   is NOT ITU-compliant: the equal-split ITU case remains THE reference and
%   weighted results are to be presented ALONGSIDE (never INSTEAD OF) the
%   baseline.
%
%   PHYSICS / SCOPE. This is band-integrated power redistribution only. At
%   constant EPRE, allocating UE u a fraction f_u of the PRBs gives it a
%   fraction f_u of the TOTAL band-integrated power; with sum(f_u) = 1
%   (fully loaded) this is a PURE SPATIAL REDISTRIBUTION OF A CONSERVED
%   TOTAL POWER (some beam directions get hotter, others cooler, the sector
%   total is unchanged), directly comparable to the equal-split ITU baseline
%   at the same total power. The model is valid for a BAND-INTEGRATED
%   (full-bandwidth) observer. Frequency-selective occupancy -- a UE with
%   fewer PRBs occupying a NARROWER sub-band so a narrowband victim at a
%   specific frequency sees only the beams present on that frequency -- is
%   OUT OF SCOPE here (that is the separate subband / PRG item); this layer
%   does NOT change the channel bandwidth or the dBm/MHz normalization basis.
%
%   3GPP grounding (TS 38.214 V19.2.0), a STATISTICAL model, NOT a normative
%   scheduling algorithm:
%       * Clause 5.1.2.2          -- PDSCH frequency-domain resource
%                                    allocation (the mechanism by which a UE
%                                    is assigned a subset of the PRBs).
%       * Clause 5.1.2.2.1/.2     -- resource allocation type 0 (RBG bitmap)
%                                    / type 1 (contiguous RIV).
%       * Clause 4.1              -- downlink EPRE: power is allocated per RE,
%                                    so a UE's band-integrated power is
%                                    proportional to its PRB count at
%                                    constant EPRE (the basis for
%                                    +10*log10(f_u)).
%   The scheduler's ACTUAL per-UE PRB allocation is IMPLEMENTATION-DEFINED
%   (driven by traffic, QoS, buffer state, channel); this is a statistical
%   model of unequal allocation consistent with the 38.214 framework, not a
%   normative algorithm.
%
%   Composition with opts.layering (per-UE semantics). PRB allocation is PER
%   UE (a UE gets a bandwidth share; its MIMO layers reuse the same time-
%   frequency resources). LAYERUEINDEX (Lx1) gives, for each beam/layer,
%   which UE it serves (as produced by imtAasExpandUeLayers). UE u's power
%   f_u is divided EQUALLY among its r_u layers, so each of its layers gets
%   a per-beam fraction f_u / r_u. Without layering the caller passes
%   LAYERUEINDEX = (1:numBeams).', so each beam is its own UE (r_u = 1) and
%   wBeam = f. In both cases sum(wBeam) = sum(f_u) = 1 (power conserved).
%
%   Inputs:
%       LAYERUEINDEX  Lx1 (or 1xL) positive-integer vector: which UE each of
%                     the L beams/layers serves. Nue = max(LAYERUEINDEX).
%                     Contiguity is NOT required -- if opts.layering clipping
%                     drops a UE entirely (rank -> 0), wBeam is renormalized
%                     over the PRESENT UEs so total power stays conserved.
%       PRBCFG        struct (resolved + validated). Recognised fields:
%         .enable     ignored here (the caller only calls this when enabled);
%                     tolerated for convenience.
%         .mode       'fixed' | 'random' (default 'random').
%         .weights    1xNue per-UE shares (mode 'fixed'). Validated nonneg /
%                     finite, not all zero; NORMALIZED to sum 1 internally.
%                     No RNG.
%         .spread     scalar sigma >= 0 (mode 'random'). Log-normal share
%                     spread. sigma = 0 -> equal shares (recovers the ITU
%                     baseline; consumes NO RNG); larger sigma -> more
%                     unequal allocation. Default 0.5.
%
%   Random mode (log-normal softmax, toolbox-free, fixed RNG count):
%       if sigma > 0:  e = exp(sigma .* randn(1, Nue)); f = e ./ sum(e);
%       else:          f = ones(1, Nue) ./ Nue;            (NO RNG)
%   This consumes exactly Nue randn draws per call when sigma > 0
%   (deterministic count -- NOT a rejection sampler), is toolbox-free (no
%   gamrnd / Statistics Toolbox), and sigma is a clean concentration knob
%   (0 = equal, large = one UE dominates). No Dirichlet / Gamma sampler.
%
%   Output OUT struct:
%       .wBeam              Lx1 per-beam linear power-fraction (column),
%                           sum(wBeam) = 1 across ALL beams.
%                           wBeam(l) = f(layerUeIndex(l)) / (number of layers
%                           whose layerUeIndex == layerUeIndex(l)).
%       .ueShares           1xNue per-UE share vector f (sum = 1).
%       .participationRatio 1 / sum(f.^2), the EFFECTIVE number of UEs (a
%                           compact concentration summary: Nue for equal
%                           shares, -> 1 as one UE dominates).
%       .config             resolved + validated config (auditable):
%                           .mode, .spread, .weights (normalized, [] for
%                           random), .numUes.
%       .specReference      citation string.
%
%   DEGENERATE GUARANTEE: equal shares (mode 'fixed' with equal weights, or
%   mode 'random' with spread == 0) consume ZERO RNG and yield wBeam =
%   1 / (Nue * r_u) per beam.
%
%   Errors (mirroring the repo validation style):
%       imtAasPrbWeights:invalidLayerUeIndex
%       imtAasPrbWeights:invalidMode
%       imtAasPrbWeights:invalidWeights
%       imtAasPrbWeights:invalidSpread
%
%   See also: imtAasExpandUeLayers, imtAasSectorEirpGridFromBeams,
%             runR23AasEirpCdfGrid, imtAasEpreOffsets.

    % ---- validate layerUeIndex --------------------------------------
    if nargin < 1 || isempty(layerUeIndex) || ~isnumeric(layerUeIndex) || ...
            ~isreal(layerUeIndex) || ~isvector(layerUeIndex)
        error('imtAasPrbWeights:invalidLayerUeIndex', ...
            'LAYERUEINDEX must be a non-empty real numeric vector.');
    end
    ueIdx = double(layerUeIndex(:));
    if any(~isfinite(ueIdx)) || any(ueIdx < 1) || any(ueIdx ~= floor(ueIdx))
        error('imtAasPrbWeights:invalidLayerUeIndex', ...
            'LAYERUEINDEX entries must be positive integers.');
    end
    Nue = max(ueIdx);
    % Contiguity is NOT required: opts.layering greedy-clipping can drop a
    % UE entirely (rank -> 0) when N > maxTotalLayers, leaving a gap in the
    % UE indices. wBeam is renormalized over the PRESENT UEs below so total
    % power is conserved (sum wBeam == 1) regardless of gaps.

    if nargin < 2 || isempty(prbCfg)
        prbCfg = struct();
    end
    if ~isstruct(prbCfg)
        error('imtAasPrbWeights:invalidMode', ...
            'PRBCFG must be a struct (or [] for defaults).');
    end

    % ---- resolve + validate config ----------------------------------
    mode   = resolveMode(getf(prbCfg, 'mode', 'random'));
    spread = getf(prbCfg, 'spread', 0.5);

    % ---- per-UE share vector f (1 x Nue, sum = 1) -------------------
    switch mode
        case 'fixed'
            if ~isfield(prbCfg, 'weights') || isempty(prbCfg.weights)
                error('imtAasPrbWeights:invalidWeights', ...
                    'prbWeighting.weights is required in mode ''fixed''.');
            end
            f = resolveFixedWeights(prbCfg.weights, Nue);   % no RNG
            normalizedWeights = f;
        case 'random'
            sigma = resolveSpread(spread);
            if sigma > 0
                e = exp(sigma .* randn(1, Nue));            % RNG: exactly Nue draws
                f = e ./ sum(e);
            else
                f = ones(1, Nue) ./ Nue;                    % NO RNG (equal shares)
            end
            normalizedWeights = [];
        otherwise
            % resolveMode already guards this; defensive only.
            error('imtAasPrbWeights:invalidMode', ...
                'prbWeighting.mode must be ''fixed'' or ''random''.');
    end
    f = f(:).';                                            % 1 x Nue row

    % ---- per-beam linear power-fraction wBeam (sum = 1) -------------
    % Split each UE's share equally across the layers serving that UE so the
    % L per-beam fractions sum to sum(f) = 1 (power conserved). Without
    % layering each UE has exactly one beam, so wBeam = f(ueIdx).
    layerCountPerUe = accumarray(ueIdx, 1, [Nue, 1]);      % Nue x 1
    fCol  = f(:);                                          % Nue x 1 (force column)
    wBeam = fCol(ueIdx) ./ layerCountPerUe(ueIdx);         % L x 1 (both column-indexed)
    wBeam = wBeam(:);

    % Guard power conservation when some UE index is absent (a UE dropped by
    % opts.layering clipping): renormalize over the present UEs so
    % sum(wBeam) == 1. When every UE 1..Nue is present this is a no-op (the
    % shares already sum to 1), so the contiguous path is left untouched.
    if numel(unique(ueIdx)) < Nue
        wBeam = wBeam ./ sum(wBeam);
        % Re-express the per-UE shares over the present UEs (renormalized).
        f = accumarray(ueIdx, wBeam, [Nue, 1]).';
    end

    % ---- diagnostics ------------------------------------------------
    participationRatio = 1 / sum(f .^ 2);                  % effective # of UEs

    config = struct();
    config.mode    = mode;
    config.spread  = spreadForConfig(mode, spread);
    config.weights = normalizedWeights;                    % normalized (fixed) or [] (random)
    config.numUes  = Nue;

    % ---- assemble ---------------------------------------------------
    out = struct();
    out.wBeam              = wBeam(:);                      % column
    out.ueShares           = f;                            % 1 x Nue, sum = 1
    out.participationRatio = participationRatio;
    out.config             = config;
    out.specReference = ['3GPP TS 38.214 V19.2.0: Clause 5.1.2.2 (PDSCH ', ...
        'frequency-domain resource allocation), Clause 5.1.2.2.1 / .2 ', ...
        '(resource allocation type 0 / type 1), Clause 4.1 (downlink EPRE: ', ...
        'band-integrated power proportional to PRB count at constant EPRE). ', ...
        'Statistical model of unequal PRB allocation, NOT a normative ', ...
        'scheduling algorithm; DEPARTS from the ITU M.2101 equal-bandwidth ', ...
        'assumption (sensitivity scenario only). Band-integrated only ', ...
        '(narrowband / per-subband behaviour is a separate item).'];
end

% =====================================================================

function m = resolveMode(m)
%RESOLVEMODE Validate prbWeighting.mode ('fixed' | 'random').
    if isstring(m) && isscalar(m)
        m = char(m);
    end
    if ~ischar(m)
        error('imtAasPrbWeights:invalidMode', ...
            'prbWeighting.mode must be a char/string scalar (''fixed'' or ''random'').');
    end
    m = lower(m);
    if ~ismember(m, {'fixed', 'random'})
        error('imtAasPrbWeights:invalidMode', ...
            'prbWeighting.mode must be ''fixed'' or ''random'' (got ''%s'').', m);
    end
end

function f = resolveFixedWeights(w, Nue)
%RESOLVEFIXEDWEIGHTS Validate + normalize fixed per-UE weights (no RNG).
    if ~(isnumeric(w) && isreal(w) && isvector(w))
        error('imtAasPrbWeights:invalidWeights', ...
            'prbWeighting.weights must be a real numeric vector.');
    end
    w = double(w(:).');
    if numel(w) ~= Nue
        error('imtAasPrbWeights:invalidWeights', ...
            ['prbWeighting.weights must have one entry per UE (expected ', ...
             '%d, got %d).'], Nue, numel(w));
    end
    if any(~isfinite(w)) || any(w < 0)
        error('imtAasPrbWeights:invalidWeights', ...
            'prbWeighting.weights must be nonnegative and finite.');
    end
    s = sum(w);
    if s <= 0
        error('imtAasPrbWeights:invalidWeights', ...
            'prbWeighting.weights must not be all zero.');
    end
    f = w ./ s;
end

function sigma = resolveSpread(s)
%RESOLVESPREAD Validate prbWeighting.spread (scalar sigma >= 0).
    if ~(isnumeric(s) && isreal(s) && isscalar(s) && isfinite(s) && s >= 0)
        error('imtAasPrbWeights:invalidSpread', ...
            'prbWeighting.spread must be a nonnegative finite scalar.');
    end
    sigma = double(s);
end

function s = spreadForConfig(mode, spread)
%SPREADFORCONFIG Echo the spread used (validated for random, [] for fixed).
    if strcmp(mode, 'random')
        s = resolveSpread(spread);
    else
        s = [];
    end
end

function v = getf(s, name, default)
%GETF Struct field read with default for missing / empty fields.
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
