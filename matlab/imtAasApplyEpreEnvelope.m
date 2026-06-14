function result = imtAasApplyEpreEnvelope(stats, offsets, applyOpts)
%IMTAASAPPLYEPREENVELOPE Per-RE worst-case EIRP envelope from EPRE offsets.
%
%   RESULT = imtAasApplyEpreEnvelope(STATS, OFFSETS)
%   RESULT = imtAasApplyEpreEnvelope(STATS, OFFSETS, APPLYOPTS)
%
%   Builds the per-RE worst-case EIRP DENSITY envelope by adding the
%   hottest 3GPP TS 38.214 Clause 4.1 per-RE EPRE boost (DM-RS or PT-RS,
%   whichever is larger) on top of the streaming traffic aggregator's
%   per-cell peak EIRP:
%
%       perRePeakEnvelope_dBm = STATS.max_dBm + OFFSETS.hottestBoostDb
%
%   STATS is the streaming traffic aggregator from runR23AasEirpCdfGrid and
%   is READ-ONLY here: this function never writes back to it, so the
%   traffic-only band-integrated path (stats / percentileMaps / power
%   self-check) is untouched.
%
%   POWER SEMANTICS (read this before using the output):
%     The per-RE envelope is a per-RE EIRP DENSITY worst case, NOT a band-
%     integrated dBm/100 MHz or dBm/MHz quantity. DM-RS / PT-RS boosts are
%     power-conserving over a slot and over the channel bandwidth, so they
%     do NOT raise the band-integrated EIRP and are deliberately kept off
%     STATS, off the percentile maps, and out of the band-integrated
%     sector-peak self-check. The per-RE envelope is ALLOWED to exceed the
%     78.3 dBm band-integrated sector peak by design (a hotter density on a
%     boosted RE) and is NOT clamped to it.
%
%   The CSI-RS-vs-SSB offset (powerControlOffsetSS) is a configured power
%   difference between CSI-RS and SSB (not power-conserving). It is applied
%   ONLY to a CSI-RS / sweep-class envelope, never to the traffic baseline.
%   When a sweep envelope is supplied via APPLYOPTS.sweepEnvelope_dBm (e.g.
%   from the opts.ssb sweep) the CSI-RS-class envelope is returned as
%   sweepEnvelope + csirsOffsetDb; otherwise only the scalar offset is
%   surfaced and the CSI-RS-class envelope is [].
%
%   APPLYOPTS fields (all optional):
%     .percentiles         percentile vector for the per-RE-envelope
%                          percentile maps. When present (and non-empty),
%                          eirp_percentile_maps is re-run on a COPY of STATS
%                          whose bin edges are shifted by hottestBoostDb
%                          (a constant-dB shift of every cell's EIRP
%                          distribution). The baseline histogram is never
%                          mutated. When absent, perRePeakPercentileMaps is
%                          left empty.
%     .sweepEnvelope_dBm   Naz x Nel sweep-class EIRP envelope [dBm] (e.g.
%                          out.ssb.envelope_dBm). When present, the CSI-RS-
%                          class envelope csirsClassEnvelope_dBm is computed.
%
%   Output RESULT struct:
%     .dmrsBoostDb              [dB] passthrough
%     .ptrsBoostDb              [dB] passthrough
%     .csirsOffsetDb            [dB] passthrough
%     .hottestBoostDb           [dB] passthrough
%     .perRePeakEnvelope_dBm    Naz x Nel per-RE worst-case density [dBm]
%     .perRePeakPercentileMaps  percentile maps of the shifted envelope
%                               (empty struct values when not requested)
%     .csirsClassEnvelope_dBm   Naz x Nel CSI-RS-class envelope [dBm] or []
%     .notes                    explicit per-RE-density caveat string
%     .specReference            citation string (from OFFSETS)
%
%   See also: imtAasEpreOffsets, runR23AasEirpCdfGrid, eirp_percentile_maps.

    if nargin < 2 || isempty(offsets) || ~isstruct(offsets)
        error('imtAasApplyEpreEnvelope:badOffsets', ...
            'OFFSETS must be the struct returned by imtAasEpreOffsets.');
    end
    if nargin < 3 || isempty(applyOpts) || ~isstruct(applyOpts)
        applyOpts = struct();
    end
    if ~isstruct(stats) || ~isfield(stats, 'max_dBm')
        error('imtAasApplyEpreEnvelope:badStats', ...
            'STATS must be the streaming aggregator (with field max_dBm).');
    end

    hottestBoostDb = double(offsets.hottestBoostDb);
    csirsOffsetDb  = double(offsets.csirsOffsetDb);

    % ---- per-RE worst-case EIRP density envelope --------------------
    % Constant-dB add on the per-cell traffic peak. STATS is read-only.
    perRePeakEnvelope_dBm = stats.max_dBm + hottestBoostDb;

    % ---- optional per-RE-envelope percentile maps -------------------
    % A constant-dB shift of every cell's EIRP distribution is exactly a
    % shift of the histogram bin edges. We run eirp_percentile_maps on a
    % COPY of STATS with shifted edges (counts untouched), so the baseline
    % histogram / percentile maps are never mutated.
    percentiles = getf(applyOpts, 'percentiles', []);
    if ~isempty(percentiles)
        shiftedStats          = stats;
        shiftedStats.binEdges = stats.binEdges + hottestBoostDb;
        perRePeakPercentileMaps = eirp_percentile_maps(shiftedStats, percentiles);
    else
        perRePeakPercentileMaps = struct( ...
            'percentiles', [], 'azGrid', getf(stats, 'azGrid', []), ...
            'elGrid', getf(stats, 'elGrid', []), 'values', [], 'binEdges', []);
    end

    % ---- CSI-RS / sweep-class offset envelope (never the traffic) ---
    sweepEnvelope_dBm = getf(applyOpts, 'sweepEnvelope_dBm', []);
    if ~isempty(sweepEnvelope_dBm)
        csirsClassEnvelope_dBm = sweepEnvelope_dBm + csirsOffsetDb;
    else
        csirsClassEnvelope_dBm = [];
    end

    % ---- assemble ---------------------------------------------------
    result = struct();
    result.dmrsBoostDb             = double(offsets.dmrsBoostDb);
    result.ptrsBoostDb             = double(offsets.ptrsBoostDb);
    result.csirsOffsetDb           = csirsOffsetDb;
    result.hottestBoostDb          = hottestBoostDb;
    result.perRePeakEnvelope_dBm   = perRePeakEnvelope_dBm;
    result.perRePeakPercentileMaps = perRePeakPercentileMaps;
    result.csirsClassEnvelope_dBm  = csirsClassEnvelope_dBm;
    result.notes = ['per-RE worst-case EIRP density; power-conserving ', ...
        'over a slot/BW; NOT additive with the band-integrated dBm/MHz ', ...
        'CDF; may exceed the 78.3 dBm band-integrated sector peak by design.'];
    if isfield(offsets, 'specReference')
        result.specReference = offsets.specReference;
    else
        result.specReference = '3GPP TS 38.214 V19.2.0 Clause 4.1.';
    end
end

% =====================================================================

function v = getf(s, name, default)
%GETF Struct field read with default for missing / empty fields.
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
