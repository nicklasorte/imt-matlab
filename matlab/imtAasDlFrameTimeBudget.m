function budget = imtAasDlFrameTimeBudget(cfg)
%IMTAASDLFRAMETIMEBUDGET DL OFDM-symbol time budget per 3GPP TS 38.214.
%
%   BUDGET = imtAasDlFrameTimeBudget(CFG)
%
%   Counts OFDM symbols/second for every downlink (DL) emission described
%   by TS 38.214 and collapses them onto the TWO spatial map classes used
%   by the time-weighted EIRP heatmap:
%
%       * "sweep" class -- cell-wide broadcast emitted over the always-on
%         SSB beam sweep (SSB + SIB1 + CSS-PDCCH + TRS + beam-management
%         CSI-RS + PRS). Spatially this rides the SSB sweep tiers.
%       * "ue" class    -- UE-directed unicast (PDSCH + USS-PDCCH +
%         per-UE periodic CSI-RS). Spatially this rides the served-beam
%         traffic grid.
%
%   The duty-cycle fractions ALPHASWEEP / ALPHAUE / ALPHAIDLE are the
%   fraction of OFDM symbols (over ALL symbols, DL + UL + idle) spent in
%   each class, so they sum to <= 1 with the remainder being idle/UL time.
%
%   This is a *time-accounting* helper only: it does NOT evaluate the
%   antenna pattern, path loss, receiver gain or I / N. It is consumed by
%   imtAasTimeWeightedGrid to weight the (already antenna-face) sweep and
%   traffic EIRP grids.
%
%   CFG fields (all optional; defaults match the R23 macro reference and
%   the headline 30 kHz DDDSU example). Every rate term cites the TS
%   38.214 V19.2.0 clause / table it is derived from:
%
%     .scs_kHz          sub-carrier spacing [kHz], default 30 (= 15*2^mu)
%     .loadFactor       network load in [0,1], default 0.20. Gates the
%                       USS-PDCCH and PDSCH (unicast) terms only.
%     .tdd              TDD slot split (TS 38.213 clause 11.1):
%                         .dlSlots          full DL slots / period (3)
%                         .specialDlSymbols DL symbols in the special slot (10)
%                         .ulSlots          full UL slots / period (1)
%                         .periodSlots      slots per TDD period (5; DDDSU)
%     .ssb              SS/PBCH burst set (TS 38.213 clause 4.1):
%                         .L                # SS/PBCH blocks (= sweep beams), 8
%                         .symbolsPerBlock  OFDM symbols per SSB (4)
%                         .period_ms        SSB burst period [ms] (20)
%     .sib              SIB1 / Msg2 broadcast (TS 38.214 Table 5.1.2.1.1-2
%                       row 1):
%                         .enable           default true
%                         .symbolsPerSsbPeriod  PDSCH symbols / SSB period (12)
%     .pdcch            CORESET (TS 38.211 7.3.2.2; TS 38.213 clauses 10/13):
%                         .coresetSymbols   CORESET duration, valid 1..3 (1)
%                         .broadcastShare   CSS share of CORESET load (0.2)
%     .trs              tracking reference signal (TS 38.214 5.1.6.1.1):
%                         .enable           default true
%                         .numSets          NZP-CSI-RS resource sets (1)
%                         .symbolsPerSet    OFDM symbols per set (4)
%                         .period_ms        TRS period [ms] (20)
%                         .mapClass         'sweep' (QCL'd to ssb-Index) or
%                                           'ue'. Default 'sweep'.
%     .csirsUe          per-UE periodic CSI-RS (TS 38.214 5.1.6.1.1):
%                         .enable           default true
%                         .numUes           served UEs (= numUesPerSector)
%                         .symbolsPerUe     OFDM symbols per UE (1)
%                         .period_slots     CSI-RS period [slots] (40)
%     .csirsBeamMgmt    CSI-RS for beam management (TS 38.214 5.1.6.1.1):
%                         .enable           default false
%                         .symbolsPerPeriod OFDM symbols / period (8)
%                         .period_ms        period [ms] (20)
%     .prs              positioning reference signal (TS 38.214 5.1.6.5):
%                         .enable           default false
%                         .symbolsPerPeriod OFDM symbols / period (0)
%                         .period_slots     PRS period [slots] (320)
%     .pdsch            unicast PDSCH (TS 38.214 Table 5.1.2.1-1):
%                         .mappingType      'A' or 'B' (default 'A')
%                         .L                allocation length [symbols] (12).
%                                           Validated vs Table 5.1.2.1-1
%                                           normal CP (Type A: 3..14,
%                                           Type B: 2..13) -> warning if
%                                           outside.
%
%   Output BUDGET struct:
%     .alphaSweep   sweep-class duty-cycle fraction (load-independent)
%     .alphaUe      UE-class duty-cycle fraction (scales with loadFactor)
%     .alphaIdle    max(1 - alphaSweep - alphaUe, 0)
%     .breakdown    per-term struct, each with .symbolsPerSec and .alpha,
%                   for: ssb, sib, pdcchCss, trs, csirsBeamMgmt, prs,
%                   pdsch, pdcchUss, csirsUe.
%     .dwell        .ssbBeam_us    = symbolsPerBlock * Tsym * 1e6
%                   .pdschAlloc_us = pdsch.L        * Tsym * 1e6
%     .frame        resolved cfg + .Tsym_us + .dlSymbolFraction
%                   + .symRate + .slotsPerSec + .mu + .specReference.
%
%   See also: imtAasTimeWeightedGrid, imtAasSsbOption, runR23AasEirpCdfGrid.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end
    if ~isstruct(cfg)
        error('imtAasDlFrameTimeBudget:badCfg', ...
            'CFG must be a struct (or [] for defaults).');
    end

    % ---- numerology (TS 38.211 clause 4.2; mu = log2(scs/15)) --------
    scs_kHz     = getf(cfg, 'scs_kHz', 30);
    mu          = log2(scs_kHz / 15);
    slotsPerSec = 2^mu * 1000;          % slots / s  (1 ms / 2^mu per slot)
    symRate     = slotsPerSec * 14;     % OFDM symbols / s (14 sym/slot, normal CP)
    Tsym        = 1 / symRate;          % OFDM symbol duration [s]

    % ---- TDD slot split (TS 38.213 clause 11.1, e.g. DDDSU) ----------
    tdd              = getf(cfg, 'tdd', struct());
    dlSlots          = getf(tdd, 'dlSlots',          3);
    specialDlSymbols = getf(tdd, 'specialDlSymbols', 10);
    % ulSlots documents the DDDSU pattern; it is not used directly because
    % the DL accounting below is expressed against the full TDD period.
    ulSlots          = getf(tdd, 'ulSlots',          1); %#ok<NASGU>
    periodSlots      = getf(tdd, 'periodSlots',      5);

    % DL OFDM-symbol fraction: full DL slots (14 sym each) + the DL symbols
    % carried in the special slot, over the whole TDD period.
    dlSymbolFraction = (dlSlots * 14 + specialDlSymbols) / (periodSlots * 14);
    dlSymRate        = symRate * dlSymbolFraction;
    % DL slot opportunities / s: a slot that can host a CORESET = full DL
    % slots + the special slot when it carries any DL symbols.
    dlSlotRate       = slotsPerSec * (dlSlots + double(specialDlSymbols > 0)) / periodSlots;

    % ---- SSB burst set (TS 38.213 clause 4.1) ------------------------
    ssb             = getf(cfg, 'ssb', struct());
    ssbL            = getf(ssb, 'L',               8);   % SS/PBCH blocks = sweep beams
    ssbSymbolsBlock = getf(ssb, 'symbolsPerBlock', 4);   % 4 OFDM symbols / SS/PBCH block
    ssbPeriod_ms    = getf(ssb, 'period_ms',       20);  % 20 ms default SSB period
    r_ssb = ssbL * ssbSymbolsBlock / (ssbPeriod_ms * 1e-3);

    % ---- SIB1 broadcast PDSCH (TS 38.214 Table 5.1.2.1.1-2 row 1) ----
    sib                = getf(cfg, 'sib', struct());
    sibEnable          = logical(getf(sib, 'enable', true));
    sibSymPerSsbPeriod = getf(sib, 'symbolsPerSsbPeriod', 12);
    if sibEnable
        r_sib = sibSymPerSsbPeriod / (ssbPeriod_ms * 1e-3);
    else
        r_sib = 0;
    end

    % ---- PDCCH CORESET (TS 38.211 7.3.2.2; TS 38.213 clauses 10/13) --
    pdcch          = getf(cfg, 'pdcch', struct());
    coresetSymbols = getf(pdcch, 'coresetSymbols', 1);   % CORESET duration, 1..3
    broadcastShare = getf(pdcch, 'broadcastShare', 0.2); % CSS fraction of CORESET load
    if ~(isscalar(coresetSymbols) && coresetSymbols >= 1 && coresetSymbols <= 3)
        warning('imtAasDlFrameTimeBudget:coresetSymbolsOutOfRange', ...
            ['pdcch.coresetSymbols = %g is outside the valid CORESET ', ...
             'duration 1..3 OFDM symbols (TS 38.211 7.3.2.2).'], coresetSymbols);
    end
    loadFactor = getf(cfg, 'loadFactor', 0.20);
    r_pdcchAll = coresetSymbols * dlSlotRate;            % all PDCCH CORESET symbols
    r_pdcchCss = broadcastShare * r_pdcchAll;            % common search space (always on)
    r_pdcchUss = (1 - broadcastShare) * r_pdcchAll * loadFactor;  % UE search space (load gated)

    % ---- TRS / tracking NZP-CSI-RS (TS 38.214 clause 5.1.6.1.1) ------
    trs          = getf(cfg, 'trs', struct());
    trsEnable    = logical(getf(trs, 'enable', true));
    trsNumSets   = getf(trs, 'numSets',      1);
    trsSymPerSet = getf(trs, 'symbolsPerSet', 4);        % 2 slots x 2 symbols
    trsPeriod_ms = getf(trs, 'period_ms',    20);
    trsMapClass  = lower(char(getf(trs, 'mapClass', 'sweep')));  % 'sweep' (QCL=ssb-Index) | 'ue'
    if trsEnable
        r_trs = trsNumSets * trsSymPerSet / (trsPeriod_ms * 1e-3);
    else
        r_trs = 0;
    end

    % ---- per-UE periodic CSI-RS (TS 38.214 clause 5.1.6.1.1) ---------
    csirsUe            = getf(cfg, 'csirsUe', struct());
    csirsUeEnable      = logical(getf(csirsUe, 'enable', true));
    csirsUeNumUes      = getf(csirsUe, 'numUes',       3);
    csirsUeSymPerUe    = getf(csirsUe, 'symbolsPerUe', 1);
    csirsUePeriodSlots = getf(csirsUe, 'period_slots', 40);
    if csirsUeEnable
        r_csirsUe = csirsUeNumUes * csirsUeSymPerUe / (csirsUePeriodSlots / slotsPerSec);
    else
        r_csirsUe = 0;
    end

    % ---- CSI-RS for beam management (TS 38.214 clause 5.1.6.1.1) -----
    csirsBm        = getf(cfg, 'csirsBeamMgmt', struct());
    bmEnable       = logical(getf(csirsBm, 'enable', false));
    bmSymPerPeriod = getf(csirsBm, 'symbolsPerPeriod', 8);
    bmPeriod_ms    = getf(csirsBm, 'period_ms',        20);
    if bmEnable
        r_bm = bmSymPerPeriod / (bmPeriod_ms * 1e-3);
    else
        r_bm = 0;
    end

    % ---- PRS positioning reference signal (TS 38.214 clause 5.1.6.5) -
    prs            = getf(cfg, 'prs', struct());
    prsEnable      = logical(getf(prs, 'enable', false));
    prsSymPerPeriod = getf(prs, 'symbolsPerPeriod', 0);
    prsPeriodSlots = getf(prs, 'period_slots', 320);
    if prsEnable
        r_prs = prsSymPerPeriod / (prsPeriodSlots / slotsPerSec);
    else
        r_prs = 0;
    end

    % ---- PDSCH unicast (TS 38.214 Table 5.1.2.1-1 time-domain alloc) -
    pdsch        = getf(cfg, 'pdsch', struct());
    pdschMapping = upper(char(getf(pdsch, 'mappingType', 'A')));
    pdschL       = getf(pdsch, 'L', 12);
    validatePdschLength(pdschMapping, pdschL);

    % ---- always-on vs traffic accounting ----------------------------
    % Always-on terms are emitted regardless of load. r_csirsUe is periodic
    % (load-independent) so it counts as always-on for the PDSCH headroom,
    % yet it is spatially UE-directed so it maps to the UE class below.
    r_alwaysOn = r_ssb + r_sib + r_pdcchCss + r_trs + r_bm + r_prs + r_csirsUe;
    % PDSCH fills the remaining DL symbols, gated by load.
    r_pdsch = max(dlSymRate - r_alwaysOn - r_pdcchUss, 0) * loadFactor;

    % ---- collapse onto the two heatmap spatial map classes ----------
    r_sweep = r_ssb + r_sib + r_pdcchCss + r_bm + r_prs;
    if strcmp(trsMapClass, 'sweep')
        r_sweep = r_sweep + r_trs;     % TRS QCL'd to ssb-Index -> rides the sweep
    end
    r_ue = r_pdsch + r_pdcchUss + r_csirsUe;
    if strcmp(trsMapClass, 'ue')
        r_ue = r_ue + r_trs;           % TRS QCL'd to a UE TCI -> rides the traffic grid
    end

    alphaSweep = r_sweep / symRate;
    alphaUe    = r_ue / symRate;
    alphaIdle  = max(1 - alphaSweep - alphaUe, 0);

    % ---- per-term breakdown -----------------------------------------
    breakdown = struct();
    breakdown.ssb           = termStruct(r_ssb,      symRate);
    breakdown.sib           = termStruct(r_sib,      symRate);
    breakdown.pdcchCss      = termStruct(r_pdcchCss, symRate);
    breakdown.trs           = termStruct(r_trs,      symRate);
    breakdown.csirsBeamMgmt = termStruct(r_bm,       symRate);
    breakdown.prs           = termStruct(r_prs,      symRate);
    breakdown.pdsch         = termStruct(r_pdsch,    symRate);
    breakdown.pdcchUss      = termStruct(r_pdcchUss, symRate);
    breakdown.csirsUe       = termStruct(r_csirsUe,  symRate);

    % ---- dwell times ------------------------------------------------
    dwell = struct();
    dwell.ssbBeam_us    = ssbSymbolsBlock * Tsym * 1e6;  % per-SSB-beam dwell
    dwell.pdschAlloc_us = pdschL          * Tsym * 1e6;  % per-PDSCH-allocation dwell

    % ---- resolved frame (auditable) ---------------------------------
    frame = struct();
    frame.scs_kHz          = scs_kHz;
    frame.mu               = mu;
    frame.slotsPerSec      = slotsPerSec;
    frame.symRate          = symRate;
    frame.Tsym_us          = Tsym * 1e6;
    frame.loadFactor       = loadFactor;
    frame.tdd              = struct('dlSlots', dlSlots, ...
                                    'specialDlSymbols', specialDlSymbols, ...
                                    'ulSlots', getf(tdd, 'ulSlots', 1), ...
                                    'periodSlots', periodSlots);
    frame.dlSymbolFraction = dlSymbolFraction;
    frame.dlSymRate        = dlSymRate;
    frame.dlSlotRate       = dlSlotRate;
    frame.ssb              = struct('L', ssbL, 'symbolsPerBlock', ssbSymbolsBlock, ...
                                    'period_ms', ssbPeriod_ms);
    frame.sib              = struct('enable', sibEnable, ...
                                    'symbolsPerSsbPeriod', sibSymPerSsbPeriod);
    frame.pdcch            = struct('coresetSymbols', coresetSymbols, ...
                                    'broadcastShare', broadcastShare);
    frame.trs              = struct('enable', trsEnable, 'numSets', trsNumSets, ...
                                    'symbolsPerSet', trsSymPerSet, ...
                                    'period_ms', trsPeriod_ms, 'mapClass', trsMapClass);
    frame.csirsUe          = struct('enable', csirsUeEnable, 'numUes', csirsUeNumUes, ...
                                    'symbolsPerUe', csirsUeSymPerUe, ...
                                    'period_slots', csirsUePeriodSlots);
    frame.csirsBeamMgmt    = struct('enable', bmEnable, ...
                                    'symbolsPerPeriod', bmSymPerPeriod, ...
                                    'period_ms', bmPeriod_ms);
    frame.prs              = struct('enable', prsEnable, ...
                                    'symbolsPerPeriod', prsSymPerPeriod, ...
                                    'period_slots', prsPeriodSlots);
    frame.pdsch            = struct('mappingType', pdschMapping, 'L', pdschL);
    frame.specReference    = ['3GPP TS 38.214 V19.2.0: Tables 5.1.2.1-1, ', ...
                              '5.1.2.1.1-2; clauses 5.1.6.1.1, 5.1.6.5. ', ...
                              'Numerology TS 38.211 4.2; TDD TS 38.213 11.1; ', ...
                              'SSB TS 38.213 4.1; CORESET TS 38.211 7.3.2.2.'];

    % ---- assemble ---------------------------------------------------
    budget = struct();
    budget.alphaSweep = alphaSweep;
    budget.alphaUe    = alphaUe;
    budget.alphaIdle  = alphaIdle;
    budget.breakdown  = breakdown;
    budget.dwell      = dwell;
    budget.frame      = frame;
end

% =====================================================================

function t = termStruct(symbolsPerSec, symRate)
%TERMSTRUCT One breakdown entry: rate [sym/s] and duty-cycle fraction.
    t = struct('symbolsPerSec', symbolsPerSec, 'alpha', symbolsPerSec / symRate);
end

function validatePdschLength(mappingType, L)
%VALIDATEPDSCHLENGTH Warn if pdsch.L violates TS 38.214 Table 5.1.2.1-1.
%   Normal cyclic prefix: PDSCH mapping Type A allocation length L is
%   3..14 OFDM symbols; Type B is 2..13.
    switch mappingType
        case 'A'
            lo = 3; hi = 14;
        case 'B'
            lo = 2; hi = 13;
        otherwise
            warning('imtAasDlFrameTimeBudget:pdschMappingType', ...
                ['pdsch.mappingType ''%s'' is not recognised ', ...
                 '(expected ''A'' or ''B'').'], mappingType);
            return;
    end
    if ~(isscalar(L) && isfinite(L) && L >= lo && L <= hi)
        warning('imtAasDlFrameTimeBudget:pdschLengthOutOfRange', ...
            ['pdsch.L = %g is outside the valid range %d..%d for PDSCH ', ...
             'mapping type %s (TS 38.214 Table 5.1.2.1-1, normal CP).'], ...
            L, lo, hi, mappingType);
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
