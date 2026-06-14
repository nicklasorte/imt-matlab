function offsets = imtAasEpreOffsets(cfg)
%IMTAASEPREOFFSETS DL per-RE EPRE offsets per 3GPP TS 38.214 Clause 4.1.
%
%   OFFSETS = imtAasEpreOffsets(CFG)
%
%   Pure, deterministic table lookup of the downlink per-resource-element
%   (per-RE) Energy-Per-Resource-Element (EPRE) offsets defined in 3GPP
%   TS 38.214 V19.2.0 Clause 4.1:
%
%       * DM-RS power boost   (Table 4.1-1, PDSCH-to-DM-RS EPRE ratio)
%       * PT-RS power boost   (Tables 4.1-2 / 4.1-2A, PT-RS-to-PDSCH EPRE)
%       * CSI-RS-vs-SSB offset (powerControlOffsetSS)
%
%   These offsets describe how a fixed symbol power is concentrated onto
%   fewer occupied REs (DM-RS / PT-RS boost) or a configured CSI-RS vs SSB
%   power difference. They are POWER-CONSERVING over a slot and over the
%   channel bandwidth (DM-RS / PT-RS), so they do NOT raise the band-
%   integrated EIRP in dBm/100 MHz; they raise only the INSTANTANEOUS
%   per-RE EIRP density. This function performs NO antenna math and NO
%   randomness -- just the Clause 4.1 table lookups. The per-RE envelope
%   that consumes these offsets is built in imtAasApplyEpreEnvelope.
%
%   CFG fields (all optional; defaults match a single-layer PDSCH with the
%   minimal DM-RS boost). Every value cites the TS 38.214 V19.2.0 clause /
%   table it is derived from:
%
%     .dmrsConfigType        1 | 2 (default 1). DM-RS configuration type
%                            (Table 4.1-1). Type 1 supports 1..2 CDM groups
%                            without data; type 2 supports 1..3.
%     .dmrsCdmGroupsNoData   1 | 2 | 3 (default 2). Number of CDM groups
%                            without data (Table 4.1-1). The DM-RS BOOST is
%                            the negation of the tabulated PDSCH-to-DM-RS
%                            EPRE ratio: 1->0 dB, 2->3 dB, 3->4.77 dB.
%     .includePtrs           logical (default false). When false the PT-RS
%                            boost is 0 dB (PT-RS not present).
%     .dmrsTypeEnh           logical (default false). Selects PT-RS Table
%                            4.1-2 (false) vs Table 4.1-2A (true). Table
%                            4.1-2A (enhanced DM-RS type) is required for
%                            7..8 PDSCH layers.
%     .pdschLayers           1..8 (default 1). Number of PDSCH layers
%                            associated with the PT-RS port (Tables 4.1-2 /
%                            4.1-2A). 7..8 require .dmrsTypeEnh = true.
%     .epreRatioState        0 | 1 (default 0). PT-RS EPRE ratio state
%                            (ptrs-EpreRatio). State 0 uses the per-layer
%                            table; state 1 is 0 dB for all layers. States
%                            2 and 3 are reserved -> error.
%     .csirsPowerOffsetSsDb  scalar dB (default 0). powerControlOffsetSS,
%                            the configured CSI-RS-to-SSB EPRE offset. Passed
%                            through and surfaced (applied only to the
%                            CSI-RS / sweep class envelope, never to the
%                            traffic baseline).
%
%   Output OFFSETS struct:
%     .dmrsBoostDb     DM-RS EPRE boost over PDSCH data EPRE [dB] (>= 0)
%     .ptrsBoostDb     PT-RS EPRE over PDSCH per-layer EPRE [dB] (0 when
%                      .includePtrs is false)
%     .csirsOffsetDb   powerControlOffsetSS passthrough [dB]
%     .hottestBoostDb  max(dmrsBoostDb, ptrsBoostDb) -- the hottest occupied
%                      RE, used to build the per-RE worst-case envelope
%     .config          resolved CFG (echoed, with defaults applied)
%     .specReference   citation string
%
%   Errors (mirroring the validation style used elsewhere in the repo):
%     imtAasEpreOffsets:invalidDmrsConfigType
%     imtAasEpreOffsets:invalidCdmGroups
%     imtAasEpreOffsets:invalidPdschLayers
%     imtAasEpreOffsets:invalidEpreRatioState
%     imtAasEpreOffsets:reservedEpreRatioState
%     imtAasEpreOffsets:layersRequireEnhancedDmrs
%     imtAasEpreOffsets:invalidCsirsOffset
%     imtAasEpreOffsets:invalidFlag
%
%   See also: imtAasApplyEpreEnvelope, runR23AasEirpCdfGrid,
%             imtAasDlFrameTimeBudget.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end
    if ~isstruct(cfg)
        error('imtAasEpreOffsets:badCfg', ...
            'CFG must be a struct (or [] for defaults).');
    end

    % ---- resolve CFG with defaults ----------------------------------
    dmrsConfigType      = getf(cfg, 'dmrsConfigType',      1);
    dmrsCdmGroupsNoData = getf(cfg, 'dmrsCdmGroupsNoData', 2);
    includePtrs         = logicalFlag(getf(cfg, 'includePtrs', false), 'includePtrs');
    dmrsTypeEnh         = logicalFlag(getf(cfg, 'dmrsTypeEnh', false), 'dmrsTypeEnh');
    pdschLayers         = getf(cfg, 'pdschLayers',         1);
    epreRatioState      = getf(cfg, 'epreRatioState',      0);
    csirsPowerOffsetSsDb = getf(cfg, 'csirsPowerOffsetSsDb', 0);

    % ---- DM-RS boost (TS 38.214 V19.2.0 Table 4.1-1) -----------------
    % PDSCH-to-DM-RS EPRE ratio (the value tabulated): 1 CDM group -> 0 dB,
    % 2 -> -3 dB, 3 -> -4.77 dB. The DM-RS BOOST (DM-RS EPRE relative to
    % PDSCH data EPRE) is the negation, hence non-negative. Config type 1
    % supports only 1..2 CDM groups without data; config type 2 supports
    % 1..3 (3 CDM groups is type-2 only).
    if ~ismember(dmrsConfigType, [1 2])
        error('imtAasEpreOffsets:invalidDmrsConfigType', ...
            'dmrsConfigType must be 1 or 2 (got %g).', dmrsConfigType);
    end
    if ~(isscalar(dmrsCdmGroupsNoData) && isfinite(dmrsCdmGroupsNoData) && ...
            ismember(dmrsCdmGroupsNoData, [1 2 3]))
        error('imtAasEpreOffsets:invalidCdmGroups', ...
            ['dmrsCdmGroupsNoData must be 1, 2 or 3 (got %g). TS 38.214 ', ...
             'Table 4.1-1.'], dmrsCdmGroupsNoData);
    end
    if dmrsConfigType == 1 && dmrsCdmGroupsNoData == 3
        error('imtAasEpreOffsets:invalidCdmGroups', ...
            ['DM-RS configuration type 1 supports only 1..2 CDM groups ', ...
             'without data; 3 requires config type 2 (TS 38.214 ', ...
             'Table 4.1-1).']);
    end
    dmrsBoostTable = [0, 3, 4.77];           % CDM groups 1, 2, 3 -> boost [dB]
    dmrsBoostDb    = dmrsBoostTable(dmrsCdmGroupsNoData);

    % ---- PT-RS boost (TS 38.214 V19.2.0 Tables 4.1-2 / 4.1-2A) -------
    % PT-RS-to-PDSCH EPRE per layer, indexed by epreRatioState and the
    % number of PDSCH layers associated with the PT-RS port. State 0 uses
    % the per-layer table (4.1-2 for non-enhanced DM-RS, 4.1-2A for
    % enhanced DM-RS); state 1 is 0 dB for all layers. States 2 and 3 are
    % reserved. Layers 7..8 exist only in Table 4.1-2A (dmrsTypeEnh = true).
    if ~(isscalar(pdschLayers) && isfinite(pdschLayers) && ...
            pdschLayers >= 1 && pdschLayers <= 8 && pdschLayers == floor(pdschLayers))
        error('imtAasEpreOffsets:invalidPdschLayers', ...
            'pdschLayers must be an integer in 1..8 (got %g).', pdschLayers);
    end
    if ~(isscalar(epreRatioState) && isfinite(epreRatioState))
        error('imtAasEpreOffsets:invalidEpreRatioState', ...
            'epreRatioState must be a scalar 0 or 1.');
    end
    if ismember(epreRatioState, [2 3])
        error('imtAasEpreOffsets:reservedEpreRatioState', ...
            ['epreRatioState %g is reserved (TS 38.214 Tables 4.1-2 / ', ...
             '4.1-2A); only states 0 and 1 are defined.'], epreRatioState);
    end
    if ~ismember(epreRatioState, [0 1])
        error('imtAasEpreOffsets:invalidEpreRatioState', ...
            'epreRatioState must be 0 or 1 (got %g).', epreRatioState);
    end

    if includePtrs
        % Layers 7..8 are only tabulated in Table 4.1-2A.
        if pdschLayers >= 7 && ~dmrsTypeEnh
            error('imtAasEpreOffsets:layersRequireEnhancedDmrs', ...
                ['PT-RS for %d PDSCH layers requires dmrsTypeEnh = true ', ...
                 '(TS 38.214 Table 4.1-2A; Table 4.1-2 covers 1..6 ', ...
                 'layers only).'], pdschLayers);
        end
        if epreRatioState == 1
            ptrsBoostDb = 0;                 % state 1: 0 dB for all layers
        else
            if dmrsTypeEnh
                ptrsTable = [0, 3, 4.77, 6, 7, 7.78, 8.45, 9];   % Table 4.1-2A
            else
                ptrsTable = [0, 3, 4.77, 6, 7, 7.78];            % Table 4.1-2
            end
            ptrsBoostDb = ptrsTable(pdschLayers);
        end
    else
        ptrsBoostDb = 0;                     % PT-RS not present
    end

    % ---- CSI-RS vs SSB offset (powerControlOffsetSS) -----------------
    if ~(isscalar(csirsPowerOffsetSsDb) && isreal(csirsPowerOffsetSsDb) && ...
            isfinite(csirsPowerOffsetSsDb))
        error('imtAasEpreOffsets:invalidCsirsOffset', ...
            'csirsPowerOffsetSsDb must be a finite real scalar [dB].');
    end
    csirsOffsetDb = double(csirsPowerOffsetSsDb);

    % ---- hottest occupied RE ----------------------------------------
    hottestBoostDb = max(dmrsBoostDb, ptrsBoostDb);

    % ---- resolved config (auditable) --------------------------------
    config = struct();
    config.dmrsConfigType       = double(dmrsConfigType);
    config.dmrsCdmGroupsNoData  = double(dmrsCdmGroupsNoData);
    config.includePtrs          = includePtrs;
    config.dmrsTypeEnh          = dmrsTypeEnh;
    config.pdschLayers          = double(pdschLayers);
    config.epreRatioState       = double(epreRatioState);
    config.csirsPowerOffsetSsDb = csirsOffsetDb;

    % ---- assemble ---------------------------------------------------
    offsets = struct();
    offsets.dmrsBoostDb    = dmrsBoostDb;
    offsets.ptrsBoostDb    = ptrsBoostDb;
    offsets.csirsOffsetDb  = csirsOffsetDb;
    offsets.hottestBoostDb = hottestBoostDb;
    offsets.config         = config;
    offsets.specReference  = ['3GPP TS 38.214 V19.2.0 Clause 4.1: ', ...
        'Table 4.1-1 (PDSCH-to-DM-RS EPRE ratio), ', ...
        'Table 4.1-2 / 4.1-2A (PT-RS-to-PDSCH EPRE per layer), ', ...
        'powerControlOffsetSS (CSI-RS-to-SSB EPRE offset).'];
end

% =====================================================================

function v = logicalFlag(x, name)
%LOGICALFLAG Coerce a scalar logical-like flag, erroring on bad input.
    if islogical(x) && isscalar(x)
        v = x;
    elseif isnumeric(x) && isscalar(x) && isfinite(x) && ismember(x, [0 1])
        v = logical(x);
    else
        error('imtAasEpreOffsets:invalidFlag', ...
            '%s must be a logical scalar (or 0/1).', name);
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
