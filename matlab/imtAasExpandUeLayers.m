function expanded = imtAasExpandUeLayers(beams, sector, layeringCfg)
%IMTAASEXPANDUELAYERS Expand an N-UE beam set into an L-layer (rank/MU-MIMO) set.
%
%   EXPANDED = imtAasExpandUeLayers(BEAMS, SECTOR, LAYERINGCFG)
%
%   Replaces the implicit "N co-scheduled beams = N rank-1 UEs" assumption
%   with a rank / MU-MIMO layering model consistent with the 3GPP TS 38.214
%   V19.2.0 framework. Each of the N UE directions carried in BEAMS is
%   served with a RANK r_u (number of MIMO layers, 1..8). The N UEs are
%   expanded into L = sum(r_u) layer-pointing directions:
%
%       * layer 1 of UE u points exactly at the UE direction (unchanged);
%       * layers 2..r_u of UE u are placed in a small angular cone around
%         that UE direction (a statistical stand-in for the channel's
%         angular spread -- there is NO channel model in this repo), each
%         clamped back to the sector / R23 steering envelope.
%
%   The per-layer power split and the incoherent linear-mW summation are
%   NOT performed here: they happen automatically downstream in
%   imtAasSectorEirpGridFromBeams, which derives
%   perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(numel(steerAzDeg)) from
%   the (now length-L) steering vectors. Expanding the beam list to L
%   entries therefore yields, per Monte Carlo draw, the correct per-layer
%   power (sectorEirp - 10*log10(L)) and the correct incoherent power sum
%   with no other change to the aggregation path.
%
%   3GPP grounding (TS 38.214 V19.2.0). This is a STATISTICAL model of gNB
%   behaviour, NOT a normative 38.214 algorithm (cf. the imt_aas_dft_codebook
%   "not a literal standardized PMI table lookup" framing):
%       * Clause 5.1.1.1   -- transmission scheme 1: up to 8 transmission
%                             layers on antenna ports 1000-1023. Bounds
%                             maxTotalLayers for the single-panel case.
%       * Clause 5.1.6.2   -- DM-RS reception / layer-to-DM-RS-port mapping
%                             that physically bounds simultaneous layers to
%                             the available ports.
%       * Clause 5.2.2.5.1 -- UE assumptions for CQI/PMI/RI: the RI (rank
%                             indicator) the UE reports; rank is channel-
%                             dependent (cell-edge -> rank 1; high-SNR /
%                             low-correlation -> higher rank).
%       * Clause 5.2.2.2.x -- the codebook (PMI per layer); CSI-RS port
%                             counts bound the maximum number of layers.
%   TS 38.214 specifies the UE-side assumptions (the rank it reports, the
%   ports it assumes). The gNB's actual co-scheduling, power split and rank
%   selection are IMPLEMENTATION-DEFINED, so this layer is a statistical
%   model of gNB behaviour consistent with the 38.214 framework. The SU-MIMO
%   layer angular spread is a stand-in for channel angular spread (no channel
%   model), and layers are summed INCOHERENTLY in linear mW downstream, to
%   match this repo's existing multi-beam convention (no coherent field
%   superposition, no inter-layer interference, no SINR-based rank adaptation).
%
%   Inputs:
%       BEAMS        struct from imtAasGenerateBeamSet. Must contain the
%                    column-vector fields steerAzDeg / steerElDeg (the N UE
%                    directions). When present, beams.azLimitsDeg /
%                    beams.elLimitsDeg define the steering envelope the
%                    spread layers are clamped to (so the no-elevation-clamp
%                    [-Inf, Inf] case is honoured); otherwise the SECTOR
%                    limits are used.
%       SECTOR       sector struct (azLimitsDeg / elLimitsDeg) used by the
%                    imtAasApplyBeamLimits clamp for the spread layers.
%       LAYERINGCFG  struct. Recognised fields (resolved with defaults):
%         .rank            positive integer scalar -> FIXED rank for every UE
%                          (default 1, the ITU rank-1 baseline); OR a 1xR
%                          probability vector -> rank PMF over ranks 1..R
%                          (nonneg, sums to 1 within tol). A FIXED rank
%                          consumes NO RNG; a PMF draws one rank per UE.
%         .maxTotalLayers  integer >= 1 (default 8, the single-panel port
%                          bound). L = sum(r_u) is capped here.
%         .layerSpreadDeg  scalar OR [sigmaAz sigmaEl] (deg, default 2).
%                          Gaussian std-dev of the offset applied to the
%                          rank>1 layers around the UE direction. 0 => layers
%                          co-located (consumes NO RNG).
%         .clipRule        'greedy' (default). When sum(r_u) > maxTotalLayers,
%                          trim the highest-rank UEs first (decrement the
%                          current highest rank by one) until sum == max.
%         .enable          ignored here (the caller only calls this when the
%                          layer is enabled); tolerated for convenience.
%
%   DEGENERATE GUARANTEE: a FIXED rank of 1 with layerSpreadDeg 0 is an
%   IDENTITY expansion -- it returns the input directions unchanged and
%   consumes ZERO RNG. This makes "enabled + rank 1 + spread 0" reduce
%   byte-for-byte to "disabled", a strong internal-consistency check.
%
%   Output EXPANDED struct (a beams-like struct):
%       .steerAzDeg         Lx1 layer steering azimuth [deg] (column)
%       .steerElDeg         Lx1 layer steering elevation [deg] (column)
%       .wasAzClipped       Lx1 logical (spread layers only can clip; the
%                           layer-1 UE directions are passed through)
%       .wasElClipped       Lx1 logical
%       .azLimitsDeg        1x2 envelope used [deg]
%       .elLimitsDeg        1x2 envelope used [deg]
%       .realizedRankPerUe  1xN realized rank per UE (after clipping)
%       .totalLayers        scalar L = sum(realizedRankPerUe)
%       .layerUeIndex       Lx1, which UE each layer serves
%       .clipped            scalar count of layers trimmed by clipRule
%       .config             resolved + validated config (auditable)
%       .specReference      citation string
%       (plus the input BEAMS fields are carried through, with steerAzDeg /
%        steerElDeg / wasAzClipped / wasElClipped overwritten to length L.)
%
%   Errors (mirroring the repo validation style):
%       imtAasExpandUeLayers:invalidBeams
%       imtAasExpandUeLayers:invalidRank
%       imtAasExpandUeLayers:invalidRankPmf
%       imtAasExpandUeLayers:invalidMaxLayers
%       imtAasExpandUeLayers:invalidSpread
%       imtAasExpandUeLayers:invalidClipRule
%
%   See also: imtAasGenerateBeamSet, imtAasSectorEirpGridFromBeams,
%             imtAasApplyBeamLimits, runR23AasEirpCdfGrid.

    if nargin < 1 || isempty(beams) || ~isstruct(beams)
        error('imtAasExpandUeLayers:invalidBeams', ...
            'BEAMS must be a struct from imtAasGenerateBeamSet.');
    end
    if ~isfield(beams, 'steerAzDeg') || ~isfield(beams, 'steerElDeg')
        error('imtAasExpandUeLayers:invalidBeams', ...
            'BEAMS must contain fields steerAzDeg and steerElDeg.');
    end
    if nargin < 2 || isempty(sector)
        if isfield(beams, 'sector') && ~isempty(beams.sector)
            sector = beams.sector;
        else
            sector = imtAasSingleSectorParams();
        end
    end
    if nargin < 3 || isempty(layeringCfg)
        layeringCfg = struct();
    end
    if ~isstruct(layeringCfg)
        error('imtAasExpandUeLayers:invalidRank', ...
            'LAYERINGCFG must be a struct (or [] for defaults).');
    end

    az = double(beams.steerAzDeg(:));
    el = double(beams.steerElDeg(:));
    if numel(az) ~= numel(el)
        error('imtAasExpandUeLayers:invalidBeams', ...
            'BEAMS.steerAzDeg and BEAMS.steerElDeg must have equal length.');
    end
    N = numel(az);

    % ---- resolve + validate config ----------------------------------
    [rankMode, fixedRank, rankPmf, maxRank] = resolveRank(getf(layeringCfg, 'rank', 1));
    maxTotalLayers = resolveMaxLayers(getf(layeringCfg, 'maxTotalLayers', 8));
    [sigmaAz, sigmaEl] = resolveSpread(getf(layeringCfg, 'layerSpreadDeg', 2));
    clipRule = resolveClipRule(getf(layeringCfg, 'clipRule', 'greedy'));

    % ---- steering envelope for the spread-layer clamp ---------------
    % Prefer the envelope the UE beams already carry so the spread layers
    % honour exactly the same gate (including the no-elevation-clamp
    % [-Inf, Inf] case); fall back to the sector limits otherwise.
    if isfield(beams, 'azLimitsDeg') && ~isempty(beams.azLimitsDeg)
        azLim = double(beams.azLimitsDeg);
    else
        azLim = double(sector.azLimitsDeg);
    end
    if isfield(beams, 'elLimitsDeg') && ~isempty(beams.elLimitsDeg)
        elLim = double(beams.elLimitsDeg);
    else
        elLim = double(sector.elLimitsDeg);
    end
    clampElevation = all(isfinite(elLim));   % [-Inf, Inf] => elevation gate off

    % ---- pass 1: determine rank per UE (RNG only for PMF) -----------
    if strcmp(rankMode, 'fixed')
        ranks = repmat(fixedRank, N, 1);     % no RNG
    else
        ranks = drawRanksFromPmf(rankPmf, N); % one rand per UE
    end

    % ---- greedy clipping so L = sum(ranks) <= maxTotalLayers --------
    % Trim the highest-rank UEs first: decrement the current maximum rank
    % by one until the total equals maxTotalLayers. Tracks the number of
    % layers trimmed. Done BEFORE generating spread offsets so trimmed
    % layers consume no RNG.
    clipped = 0;
    if strcmp(clipRule, 'greedy')
        while sum(ranks) > maxTotalLayers
            [~, iMax] = max(ranks);
            ranks(iMax) = ranks(iMax) - 1;   % may reach 0 (UE dropped) if N > max
            clipped = clipped + 1;
        end
    end

    L = sum(ranks);
    if L < 1
        % Guard: the runner needs at least one beam. With maxTotalLayers >= 1
        % and N >= 1 this cannot happen, but keep the invariant explicit.
        error('imtAasExpandUeLayers:invalidMaxLayers', ...
            'Resolved total layer count is zero; maxTotalLayers must be >= 1.');
    end

    % ---- pass 2: emit layer directions (RNG only for spread > 0) ----
    steerAz    = zeros(L, 1);
    steerEl    = zeros(L, 1);
    layerUeIdx = zeros(L, 1);
    isSpread   = false(L, 1);
    c = 0;
    for u = 1:N
        ru = ranks(u);
        if ru < 1
            continue;   % UE dropped by clipping
        end
        % layer 1: exactly at the UE direction (unchanged)
        c = c + 1;
        steerAz(c)    = az(u);
        steerEl(c)    = el(u);
        layerUeIdx(c) = u;
        % layers 2..ru: Gaussian-spread cone around the UE direction
        for j = 2:ru
            c = c + 1;
            if sigmaAz > 0, aOff = sigmaAz * randn; else, aOff = 0; end
            if sigmaEl > 0, eOff = sigmaEl * randn; else, eOff = 0; end
            steerAz(c)    = az(u) + aOff;
            steerEl(c)    = el(u) + eOff;
            layerUeIdx(c) = u;
            isSpread(c)   = true;
        end
    end

    % ---- clamp the spread layers to the steering envelope -----------
    % Reuse imtAasApplyBeamLimits (the repo clamp). The layer-1 UE
    % directions are already within the envelope and are NOT re-clamped, so
    % they remain byte-identical to the input.
    wasAzClipped = false(L, 1);
    wasElClipped = false(L, 1);
    if any(isSpread)
        clampBeam = struct( ...
            'rawSteerAzDeg', steerAz(isSpread), ...
            'rawSteerElDeg', steerEl(isSpread), ...
            'sector',        sector);
        clamped = imtAasApplyBeamLimits(clampBeam, sector, ...
            struct('clampElevation', clampElevation));
        steerAz(isSpread)      = clamped.steerAzDeg(:);
        steerEl(isSpread)      = clamped.steerElDeg(:);
        wasAzClipped(isSpread) = clamped.wasAzClipped(:);
        wasElClipped(isSpread) = clamped.wasElClipped(:);
    end

    % ---- resolved config (auditable) --------------------------------
    config = struct();
    config.rankMode       = rankMode;
    if strcmp(rankMode, 'fixed')
        config.rank   = fixedRank;
        config.rankPmf = [];
    else
        config.rank    = [];
        config.rankPmf = rankPmf;
    end
    config.maxRank        = maxRank;
    config.maxTotalLayers = maxTotalLayers;
    config.layerSpreadDeg = [sigmaAz, sigmaEl];
    config.clipRule       = clipRule;

    % ---- assemble expanded beams-like struct ------------------------
    expanded                   = beams;            % carry input fields through
    expanded.steerAzDeg        = steerAz;
    expanded.steerElDeg        = steerEl;
    expanded.wasAzClipped      = wasAzClipped;
    expanded.wasElClipped      = wasElClipped;
    expanded.azLimitsDeg       = azLim;
    expanded.elLimitsDeg       = elLim;
    expanded.realizedRankPerUe = ranks(:).';
    expanded.totalLayers       = L;
    expanded.layerUeIndex      = layerUeIdx;
    expanded.clipped           = clipped;
    expanded.config            = config;
    expanded.specReference     = [ ...
        '3GPP TS 38.214 V19.2.0: Clause 5.1.1.1 (transmission scheme 1, ', ...
        'up to 8 layers on ports 1000-1023), Clause 5.1.6.2 (DM-RS ', ...
        'port mapping bound), Clause 5.2.2.5.1 (RI / rank reporting), ', ...
        'Clause 5.2.2.2.x (PMI codebook / CSI-RS port bound). Statistical ', ...
        'gNB-behaviour model, NOT a normative 38.214 scheduling algorithm; ', ...
        'layer angular spread stands in for channel angular spread (no ', ...
        'channel model); layers summed incoherently in linear mW.'];
end

% =====================================================================

function [mode, fixedRank, pmf, maxRank] = resolveRank(rank)
%RESOLVERANK Disambiguate a fixed integer rank vs a rank PMF, with validation.
%   A scalar is always interpreted as a FIXED rank and must be a positive
%   integer (imtAasExpandUeLayers:invalidRank). A length>=2 vector is
%   interpreted as a rank PMF over ranks 1..R and must be nonneg + finite
%   and sum to 1 within tol (imtAasExpandUeLayers:invalidRankPmf).
    mode = 'fixed';
    fixedRank = 1;
    pmf = [];
    maxRank = 1;

    if isscalar(rank)
        if ~(isnumeric(rank) && isreal(rank) && isfinite(rank) && ...
                rank >= 1 && rank == floor(rank))
            error('imtAasExpandUeLayers:invalidRank', ...
                ['layering.rank (fixed) must be a positive integer scalar ', ...
                 '(got %g). Use a 1xR probability vector for a rank PMF.'], ...
                valForMsg(rank));
        end
        mode      = 'fixed';
        fixedRank = double(rank);
        maxRank   = fixedRank;
        return;
    end

    if isnumeric(rank) && isreal(rank) && isvector(rank) && numel(rank) >= 2
        pmf = double(rank(:).');
        if any(~isfinite(pmf)) || any(pmf < 0) || abs(sum(pmf) - 1) > 1e-9
            error('imtAasExpandUeLayers:invalidRankPmf', ...
                ['layering.rank PMF must be a nonnegative finite vector ', ...
                 'summing to 1 (got sum %g).'], sum(pmf));
        end
        mode    = 'pmf';
        maxRank = numel(pmf);
        return;
    end

    error('imtAasExpandUeLayers:invalidRank', ...
        ['layering.rank must be a positive integer scalar (fixed rank) or ', ...
         'a 1xR probability vector (rank PMF).']);
end

function ranks = drawRanksFromPmf(pmf, N)
%DRAWRANKSFROMPMF Draw N ranks (1..numel(pmf)) from a PMF. One rand per UE.
    cdf = cumsum(pmf(:).');
    cdf(end) = 1;                       % guard against fp drift at the top
    u = rand(N, 1);                     % RNG: exactly N draws
    ranks = zeros(N, 1);
    for k = 1:N
        ranks(k) = find(u(k) <= cdf, 1, 'first');
    end
end

function m = resolveMaxLayers(m)
%RESOLVEMAXLAYERS Validate maxTotalLayers (integer >= 1).
    if ~(isnumeric(m) && isreal(m) && isscalar(m) && isfinite(m) && ...
            m >= 1 && m == floor(m))
        error('imtAasExpandUeLayers:invalidMaxLayers', ...
            'layering.maxTotalLayers must be an integer >= 1 (got %g).', ...
            valForMsg(m));
    end
    m = double(m);
end

function [sigmaAz, sigmaEl] = resolveSpread(s)
%RESOLVESPREAD Validate layerSpreadDeg (scalar OR [sigmaAz sigmaEl], >= 0).
    if ~(isnumeric(s) && isreal(s) && all(isfinite(s(:))) && all(s(:) >= 0) && ...
            any(numel(s) == [1 2]))
        error('imtAasExpandUeLayers:invalidSpread', ...
            ['layering.layerSpreadDeg must be a nonnegative finite scalar ', ...
             'or a [sigmaAz sigmaEl] pair of nonnegative finite values.']);
    end
    s = double(s(:).');
    if isscalar(s)
        sigmaAz = s;
        sigmaEl = s;
    else
        sigmaAz = s(1);
        sigmaEl = s(2);
    end
end

function r = resolveClipRule(r)
%RESOLVECLIPRULE Validate clipRule ('greedy' only for now).
    if isstring(r) && isscalar(r)
        r = char(r);
    end
    if ~ischar(r) || ~strcmpi(r, 'greedy')
        error('imtAasExpandUeLayers:invalidClipRule', ...
            'layering.clipRule must be ''greedy''.');
    end
    r = 'greedy';
end

function v = valForMsg(x)
%VALFORMSG Coerce x to a printable scalar for error messages.
    if isnumeric(x) && isscalar(x)
        v = double(x);
    else
        v = NaN;
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
