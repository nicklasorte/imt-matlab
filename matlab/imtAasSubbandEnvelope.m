function result = imtAasSubbandEnvelope(azGridDeg, elGridDeg, beams, params, cfg)
%IMTAASSUBBANDENVELOPE Narrowband (per-subband) worst-case EIRP density grid.
%
%   RESULT = imtAasSubbandEnvelope(AZGRIDDEG, ELGRIDDEG, BEAMS, PARAMS)
%   RESULT = imtAasSubbandEnvelope(AZGRIDDEG, ELGRIDDEG, BEAMS, PARAMS, CFG)
%
%   Builds the per-(az, el) NARROWBAND (per-subband) worst-case EIRP DENSITY
%   envelope [dBm / MHz] for one IMT AAS sector serving the BEAMS beam set.
%   This is the frequency-selective-occupancy / narrowband-victim view that
%   complements the band-integrated (wideband-victim) EIRP grid: it is a
%   SEPARATE output and never reshapes the band-integrated CDF.
%
%   PHYSICS (the whole point - read before using the output):
%     The band-integrated grid spreads the sector conducted power across all
%     N co-scheduled UEs, so each beam carries the per-beam split
%     sectorEirp - 10*log10(N). At constant EPRE (3GPP TS 38.214 V19.2.0
%     Clause 4.1) the gNB radiates a constant power per resource element, so
%     under frequency-division scheduling (OFDMA - the ITU "each UE gets
%     1/N of the channel bandwidth" picture taken literally) any NARROW slice
%     of spectrum is occupied by a SINGLE UE's beam radiating at the FULL
%     per-RE EPRE density - NOT the band-split power. A narrowband victim at
%     direction theta therefore sees, in the worst sub-band, the best-aligned
%     co-scheduled beam at the FULL conducted-power density. The per-subband
%     density is consequently ABOUT 10*log10(N) HIGHER than the
%     band-integrated dBm/MHz density at a beam center; the band-integrated
%     map understates the narrowband worst case by exactly that much.
%
%   POWER-SPLIT INDEPENDENCE:
%     Because a narrowband victim sees ONE beam at full EPRE regardless of
%     how the band-integrated power was split, this density depends only on
%     the beam DIRECTIONS, not on any power split. It is therefore
%     independent of opts.prbWeighting and of the opts.layering power split,
%     and composes with opts.layering's L layer directions automatically (it
%     uses the layer-expanded BEAMS as given). No RNG is consumed.
%
%   COMPUTATION (foolproof / fallback path):
%     Every beam is evaluated at the FULL sector EIRP (no power split, any
%     per-beam power vector on BEAMS is overridden) by calling
%     imtAasSectorEirpGridFromBeams with SPLITSECTORPOWER = false; the
%     per-cell max-over-beams envelope is the best-aligned beam at full EPRE.
%     The density is then the band-normalized envelope:
%
%         perSubbandDensityEnvelope_dBmPerMHz
%             = maxEnvelopeEirpDbm(full EPRE) - 10*log10(bandwidthMHz)
%
%     This reuses the existing antenna engine (no new antenna math) and is
%     exact: for a single beam it equals the band-integrated aggregate grid
%     (dBm) minus 10*log10(bandwidthMHz). The equivalent efficient form
%     conductedPowerDensity_dBmPerMHz + maxEnvelopeGainDbi(theta), with
%     conductedPowerDensity = (sectorEirp - peakCompositeGainDbi)
%     - 10*log10(bandwidthMHz), is documented in CONFIG for reference.
%
%   This is antenna-face EIRP only: NO path loss, NO receiver antenna gain,
%   NO I / N, NO propagation. It is the narrowband POWER concentration; it
%   does NOT model per-subband precoding / PRG angular variation, per-RE EPRE
%   boosts (that is opts.epre), or guard bands.
%
%   Inputs:
%       AZGRIDDEG, ELGRIDDEG  observation grid vectors [deg].
%       BEAMS                 struct with steerAzDeg / steerElDeg (the
%                             possibly layer-expanded beam directions). Any
%                             perBeamPeakEirpDbm field is IGNORED here (full
%                             EPRE is forced).
%       PARAMS                imtAasDefaultParams-shaped struct (default
%                             imtAasDefaultParams()).
%       CFG                   optional struct:
%                               .subbandMHz   victim reference bandwidth
%                                             [MHz], 0 < x <= bandwidthMHz
%                                             (default 1).
%                               .bandwidthMHz channel bandwidth [MHz]
%                                             (default params.bandwidthMHz).
%                               .sectorEirpDbm sector peak EIRP [dBm]
%                                             (default params.sectorEirpDbm).
%                               .peakCompositeGainDbi peak composite gain the
%                                             EIRP grid normalizes to [dBi]
%                                             (default params.peakGainDbi);
%                                             reference / config only.
%
%   Output RESULT struct:
%       .perSubbandDensityEnvelope_dBmPerMHz  Naz x Nel [dBm / MHz]
%       .perSubbandPeak_dBmPerMHz   scalar headline boresight density
%                                   = sectorEirp - 10*log10(bandwidthMHz)
%       .perSubband_dBm             Naz x Nel EIRP IN the sub-band
%                                   = density + 10*log10(subbandMHz)
%       .perSubbandPeakInBand_dBm   scalar = perSubbandPeak + 10*log10(subbandMHz)
%       .subbandMHz / .bandwidthMHz scalars [MHz]
%       .numBeams                   scalar (numel of the beam set used)
%       .validity                   struct: single-beam-per-subband bound
%                                   subbandMHz <= bandwidthMHz / numBeams and
%                                   the spansMultipleUeAllocations flag.
%       .config                     resolved config (audit).
%       .notes                      narrowband-worst-case caveat string.
%       .specReference              citation string.
%
%   See also: imtAasSectorEirpGridFromBeams, runR23AasEirpCdfGrid,
%             imtAasApplyEpreEnvelope, eirp_percentile_maps.

    if nargin < 3 || isempty(beams) || ~isstruct(beams)
        error('imtAasSubbandEnvelope:badBeams', ...
            'BEAMS must be a struct with steerAzDeg / steerElDeg.');
    end
    if nargin < 4 || isempty(params)
        params = imtAasDefaultParams();
    end
    if nargin < 5 || isempty(cfg) || ~isstruct(cfg)
        cfg = struct();
    end

    % ---- resolve config ---------------------------------------------
    bandwidthMHz = getf(cfg, 'bandwidthMHz', double(params.bandwidthMHz));
    if ~(isnumeric(bandwidthMHz) && isscalar(bandwidthMHz) && ...
            isreal(bandwidthMHz) && isfinite(bandwidthMHz) && bandwidthMHz > 0)
        error('imtAasSubbandEnvelope:invalidBandwidthMHz', ...
            'bandwidthMHz must be a finite positive scalar [MHz].');
    end
    bandwidthMHz = double(bandwidthMHz);

    subbandMHz = getf(cfg, 'subbandMHz', 1);
    validateSubbandMHz(subbandMHz, bandwidthMHz);
    subbandMHz = double(subbandMHz);

    if isfield(params, 'sectorEirpDbm') && ~isempty(params.sectorEirpDbm)
        defSectorEirp = double(params.sectorEirpDbm);
    else
        defSectorEirp = 78.3;
    end
    sectorEirpDbm = double(getf(cfg, 'sectorEirpDbm', defSectorEirp));
    if ~(isscalar(sectorEirpDbm) && isreal(sectorEirpDbm) && isfinite(sectorEirpDbm))
        error('imtAasSubbandEnvelope:invalidSectorEirp', ...
            'sectorEirpDbm must be a finite real scalar [dBm].');
    end

    if isfield(params, 'peakGainDbi') && ~isempty(params.peakGainDbi)
        defPeakGain = double(params.peakGainDbi);
    else
        defPeakGain = NaN;
    end
    peakCompositeGainDbi = double(getf(cfg, 'peakCompositeGainDbi', defPeakGain));

    % ---- full-EPRE max-over-beams envelope (no power split) ----------
    % SPLITSECTORPOWER = false forces every beam to peak at the full sector
    % EIRP, overriding any per-beam power vector on BEAMS, so the per-cell
    % max-over-beams envelope is the best-aligned co-scheduled beam at the
    % full conducted-power density. computeGain = false: only the EIRP
    % envelope is needed. Pure (no RNG); reuses the existing antenna engine.
    sectorOpts = struct( ...
        'splitSectorPower', false, ...
        'returnPerBeam',    false, ...
        'sectorEirpDbm',    sectorEirpDbm, ...
        'computeGain',      false);
    sec = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, beams, params, sectorOpts);

    bandOffsetDb = 10 * log10(bandwidthMHz);
    perSubbandDensityEnvelope_dBmPerMHz = sec.maxEnvelopeEirpDbm - bandOffsetDb;

    % ---- headline scalars -------------------------------------------
    % Boresight narrowband density: best beam at full EPRE, band-normalized.
    perSubbandPeak_dBmPerMHz = sectorEirpDbm - bandOffsetDb;
    subbandOffsetDb          = 10 * log10(subbandMHz);
    perSubband_dBm           = perSubbandDensityEnvelope_dBmPerMHz + subbandOffsetDb;
    perSubbandPeakInBand_dBm = perSubbandPeak_dBmPerMHz + subbandOffsetDb;

    numBeams = numel(sec.beams.steerAzDeg);

    % ---- single-beam-per-subband validity bound ---------------------
    % The single-beam worst case holds when N disjoint sub-bands fit under
    % equal split, i.e. subbandMHz <= bandwidthMHz / N. Above that the
    % sub-band would span more than one UE's allocation and the single-beam
    % worst case is optimistic.
    boundMHz = bandwidthMHz / max(numBeams, 1);
    spansMultipleUeAllocations = subbandMHz > boundMHz + 1e-12;
    validity = struct( ...
        'subbandMHz',                   subbandMHz, ...
        'bandwidthMHz',                 bandwidthMHz, ...
        'numBeams',                     numBeams, ...
        'singleBeamPerSubbandBoundMHz', boundMHz, ...
        'spansMultipleUeAllocations',   spansMultipleUeAllocations, ...
        'note', ['single-beam worst case valid when subbandMHz <= ', ...
                 'bandwidthMHz / numBeams; above the bound the sub-band ', ...
                 'spans >1 UE allocation and the worst case is optimistic.']);

    % ---- config (audit) ---------------------------------------------
    config = struct( ...
        'subbandMHz',                  subbandMHz, ...
        'bandwidthMHz',                bandwidthMHz, ...
        'sectorEirpDbm',               sectorEirpDbm, ...
        'peakCompositeGainDbi',        peakCompositeGainDbi, ...
        'conductedPowerDensity_dBmPerMHz', sectorEirpDbm - peakCompositeGainDbi - bandOffsetDb, ...
        'computationPath',             'fallback_full_epre_maxEnvelope', ...
        'numBeams',                    numBeams);

    % ---- assemble ---------------------------------------------------
    result = struct();
    result.perSubbandDensityEnvelope_dBmPerMHz = perSubbandDensityEnvelope_dBmPerMHz;
    result.perSubbandPeak_dBmPerMHz = perSubbandPeak_dBmPerMHz;
    result.perSubband_dBm           = perSubband_dBm;
    result.perSubbandPeakInBand_dBm = perSubbandPeakInBand_dBm;
    result.subbandMHz               = subbandMHz;
    result.bandwidthMHz             = bandwidthMHz;
    result.numBeams                 = numBeams;
    result.validity                 = validity;
    result.config                   = config;
    result.notes = ['Narrowband (per-subband) worst-case EIRP DENSITY ', ...
        'under a frequency-division assumption (one beam per occupied ', ...
        'sub-band at full EPRE, the victim sub-band assumed occupied by ', ...
        'the best-aligned beam). A SEPARATE view from the band-integrated ', ...
        'ITU result, which remains THE reference; the per-subband density ', ...
        'is ~10*log10(N) above the band-integrated dBm/MHz density at a ', ...
        'beam center. Power-split-independent (depends only on beam ', ...
        'directions). Statistical model consistent with the TS 38.214 ', ...
        'framework, NOT a normative scheduling result. NOT additive with ', ...
        'the band-integrated dBm/MHz CDF.'];
    result.specReference = ['3GPP TS 38.214 V19.2.0 Clause 5.1.2.2 (PDSCH ', ...
        'frequency-domain resource allocation, type 0 / type 1), Clause ', ...
        '5.1.2.3 (PRB bundling / precoding resource block group, PRG), ', ...
        'Clause 4.1 (downlink EPRE).'];
end

% =====================================================================

function validateSubbandMHz(subbandMHz, bandwidthMHz)
%VALIDATESUBBANDMHZ Strict check 0 < subbandMHz <= bandwidthMHz.
    if ~(isnumeric(subbandMHz) && isscalar(subbandMHz) && isreal(subbandMHz) && ...
            isfinite(subbandMHz) && subbandMHz > 0 && subbandMHz <= bandwidthMHz)
        error('imtAasSubbandEnvelope:invalidSubbandMHz', ...
            ['subbandMHz must be a finite real scalar with ', ...
             '0 < subbandMHz <= bandwidthMHz (%g); got %s.'], ...
            bandwidthMHz, mat2str(subbandMHz));
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
