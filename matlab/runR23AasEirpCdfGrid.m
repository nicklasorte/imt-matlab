function out = runR23AasEirpCdfGrid(varargin)
%RUNR23AASEIRPCDFGRID R23 7/8 GHz Extended AAS EIRP CDF-grid generator.
%
%   OUT = runR23AasEirpCdfGrid()
%   OUT = runR23AasEirpCdfGrid(OPTS)
%   OUT = runR23AasEirpCdfGrid(PARAMS)
%   OUT = runR23AasEirpCdfGrid('Name', Value, ...)
%   OUT = runR23AasEirpCdfGrid(PARAMS, 'Name', Value, ...)
%
%   Source-aligned MVP entry point for the R23 7.125-8.4 GHz Extended AAS
%   per-(azimuth, elevation) EIRP CDF-grid generator. For each Monte
%   Carlo draw the runner samples NUMUESPERSECTOR UE-driven beam
%   steering angles, builds the aggregate antenna-face sector EIRP grid
%   via imtAasSectorEirpGridFromBeams (linear-mW summed over the
%   simultaneous beams), and updates a streaming per-cell histogram and
%   pointing-angle aggregator. The full per-draw EIRP cube is NEVER
%   materialised.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO FS / FSS receiver logic, NO
%   coordination distance, and NO multi-site aggregation in this slice.
%
%   Three input styles are supported:
%
%   1) Flat OPTS struct (legacy):
%        opts.numMc, opts.azGridDeg, opts.elGridDeg, opts.binEdgesDbm,
%        opts.percentiles, opts.seed, opts.deployment, opts.numBeams,
%        opts.splitSectorPower, opts.progressEvery, opts.mcChunkSize,
%        opts.outputCsvPath, opts.outputMetadataPath,
%        opts.numUesPerSector, opts.maxEirpPerSector_dBm,
%        opts.environment, opts.computePointingHeatmap,
%        opts.computePointingHistogram, opts.pointingAzBinEdgesDeg,
%        opts.pointingElBinEdgesDeg,
%        opts.clampElevation, opts.beamSelection, opts.codebookOversample,
%        opts.outputDomain, opts.gainBinEdgesDbi,
%        opts.activityWeightedCdf, opts.activityModel,
%        opts.activityOffFloorUses, opts.tddActivityFactor,
%        opts.networkLoadingFactor, opts.activityOffFloorDbm.
%      The flat OPTS struct also accepts the same AAS geometry fields as
%      the name-value form:
%        opts.aasGeometryPreset,
%        opts.arrayRows, opts.arrayCols,
%        opts.subarrayElementRows, opts.subarrayElementCols,
%        opts.subarrayElementVerticalSpacingLambda,
%        opts.radiatingSubarrayHorizontalSpacingLambda,
%        opts.radiatingSubarrayVerticalSpacingLambda,
%        opts.subarrayDowntiltDeg, opts.mechanicalDowntiltDeg,
%        opts.elementGainDbi,
%        opts.sectorEirpDbm, opts.conductedPowerDbm.
%      When both the flat-opts and name-value forms supply the same
%      geometry field in one call, the name-value form wins (matches the
%      override-merge semantics used for the non-geometry fields).
%
%   2) Nested PARAMS struct as built by r23DefaultParams. The runner
%      auto-detects fields .deployment / .ue / .bs / .aas / .sim and
%      flattens to internal opts. Per-call overrides may then be passed
%      as additional name-value pairs.
%
%   3) Name-value pairs e.g.
%        runR23AasEirpCdfGrid('numUesPerSector', 10, ...
%                             'maxEirpPerSector_dBm', 75, ...
%                             'environment', 'suburban')
%
%   AAS geometry preset (transmit-side antenna only):
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'r23_1x3_default')
%           -> source-aligned R23/ITU Extended AAS baseline (default).
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'ctia_7ghz_1x6')
%           -> CTIA 7 GHz 1x6 AAS sensitivity case (4x16 sub-array,
%              6 elements per sub-array, 768 total elements across two
%              polarizations, ~32.2 dBi antenna gain, ~90.8 dBm sector
%              EIRP at 58.6 dBm conducted power).
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'r23_micro_8x8', ...
%                            'environment', 'microUrban')
%           -> ITU-R R23 7.125-8.4 GHz Small cell outdoor / Micro urban
%              reference (8x8 ELEMENT array, no sub-array, ~24.46 dBi
%              antenna gain, 61.5 dBm sector EIRP, 6 m BS height,
%              [-30, 0] elevation coverage, 10 deg mechanical tilt).
%              The geometry preset and the environment are independent
%              knobs, but the 'r23_micro_8x8' preset is intended to be
%              paired with environment 'microUrban' / 'microSuburban'.
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'custom', ...
%                            'arrayRows', 4, 'arrayCols', 16, ...
%                            'subarrayElementRows', 6, ...)
%           -> explicit geometry sensitivity. All required geometry
%              fields must be supplied. See aasGeometryPreset for the
%              full list of override names.
%
%   Beam selection (non-breaking; default 'ideal'):
%       runR23AasEirpCdfGrid('beamSelection', 'codebook', ...
%                            'codebookOversample', [4 4])
%       opts.beamSelection ('ideal' | 'codebook', default 'ideal'):
%           'ideal'    -> each beam points exactly at its served UE
%                         (continuous steering; historical behavior,
%                          byte-identical default).
%           'codebook' -> each beam is snapped to the nearest 3GPP
%                         TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I
%                         single-panel oversampled-DFT (PMI) codebook
%                         beam, i.e. the quantized beam a real gNB would
%                         form from a reported PMI. Applied in the PANEL
%                         frame after the mechanical-tilt transform
%                         inside imtAasArrayFactor.
%       opts.codebookOversample: positive integer scalar or [O_H O_V]
%           pair, default [4 4] (TS 38.214 Table 5.2.2.2.1-2 default).
%       Surfaced in out.metadata.beamSelection / out.metadata.beamCodebook.
%       See imt_aas_dft_codebook / imt_aas_codebook_select for the
%       construction, the max-gain == nearest-bin property, and the
%       aliasing (grating lobe) caveat for the d_V = 2.1 lambda stack.
%
%   Output domain (non-breaking; default 'eirp'):
%       opts.outputDomain ('eirp' | 'gain' | 'both', default 'eirp'):
%           'eirp' -> EIRP CDF-grid only (historical behavior, byte-
%                     identical default; gain is not computed).
%           'gain' -> additionally compute the antenna GAIN heatmap, i.e.
%                     the realized served-beam composite gain in dBi per
%                     direction, combined as the MAX over simultaneous
%                     beams (an envelope, NOT a power sum). Geometry-
%                     agnostic: works unchanged for every aasGeometryPreset
%                     because the geometry already rides params.
%           'both' -> both of the above (EIRP is nearly free).
%       opts.gainBinEdgesDbi: histogram bin edges for the gain accumulator
%           [dBi], default -100:0.5:40. Surfaced via out.gainStats /
%           out.gainPercentileMaps and out.metadata.outputDomain /
%           .computeGain / .gainAggregation / .peakRealizedGainDbi.
%
%   Per-RE EPRE-offset layer (non-breaking; default OFF):
%       opts.epre absent / [] -> disabled, and stats / percentileMaps /
%           selfCheck (and any opts.ssb out.ssb / out.timeWeighted) are
%           byte-identical to today for a fixed seed.
%       opts.epre = struct(...) -> enables the 3GPP TS 38.214 V19.2.0
%           Clause 4.1 downlink per-resource-element EPRE-offset layer:
%           DM-RS power boost (Table 4.1-1), optional PT-RS power boost
%           (Tables 4.1-2 / 4.1-2A), and the CSI-RS-vs-SSB power offset
%           powerControlOffsetSS. Fields (resolved + validated by
%           imtAasEpreOffsets):
%             .dmrsConfigType        1 | 2          (default 1)
%             .dmrsCdmGroupsNoData   1 | 2 | 3       (default 2)
%             .includePtrs           logical        (default false)
%             .dmrsTypeEnh           logical        (default false)
%             .pdschLayers           1..8           (default 1, PT-RS only)
%             .epreRatioState        0 | 1          (default 0, PT-RS only)
%             .csirsPowerOffsetSsDb  scalar dB      (default 0)
%       The ITU band-integrated baseline (78.3 dBm/100 MHz sector EIRP)
%       is and remains the baseline: DM-RS / PT-RS boosts are POWER-
%       CONSERVING over a slot and over the channel bandwidth, so they
%       are NOT added to stats / percentileMaps / the band-integrated CDF
%       and are NOT fed into the band-integrated sector-peak self-check.
%       Instead a SEPARATE per-RE worst-case EIRP DENSITY envelope is
%       surfaced (out.epre.perRePeakEnvelope_dBm = stats.max_dBm +
%       hottestBoostDb). That envelope is ALLOWED to exceed the 78.3 dBm
%       band-integrated sector peak by design (a hotter density on a
%       boosted RE) and is not clamped to it. See imtAasEpreOffsets and
%       imtAasApplyEpreEnvelope.
%
%   Rank / MU-MIMO layering layer (non-breaking; default OFF):
%       opts.layering absent / [] -> disabled, and every existing output
%           (stats, percentileMaps, the power self-check, opts.ssb,
%           opts.epre) is BYTE-IDENTICAL to today for a fixed seed (the
%           layer adds NO RNG draws when off).
%       opts.layering = struct(...) -> enables a rank / MU-MIMO layering
%           model consistent with the 3GPP TS 38.214 V19.2.0 framework that
%           REPLACES the implicit "N beams = N rank-1 UEs, each at
%           sectorEirp - 10*log10(N)" assumption. Each of the
%           numUesPerSector co-scheduled UEs is served with a RANK r_u
%           (1..8 layers); the total layer count L = sum(r_u) is capped at
%           maxTotalLayers (single-panel port bound); the sector power is
%           split across L LAYERS (perLayer = sectorEirp - 10*log10(L));
%           and the r_u > 1 layers of a UE are placed in a small Gaussian
%           angular cone around that UE's direction (a stand-in for channel
%           angular spread -- there is NO channel model in this repo).
%           Fields (resolved + validated by imtAasExpandUeLayers):
%             .rank            positive integer -> FIXED rank (default 1)
%                              OR 1xR prob vector -> rank PMF over 1..R
%             .maxTotalLayers  integer >= 1 (default 8)
%             .layerSpreadDeg  scalar OR [sigmaAz sigmaEl] (default 2 deg;
%                              0 => layers co-located)
%             .clipRule        'greedy' (default; trim highest-rank UEs
%                              first when sum(r_u) > maxTotalLayers)
%       UNLIKE opts.epre (a post-hoc per-RE envelope that never touches the
%       band-integrated CDF), opts.layering changes the per-draw BEAM SET,
%       so when enabled it DOES reshape stats / percentileMaps / the EIRP
%       CDF -- that is the point. This is an explicitly-labelled ALTERNATIVE
%       SCENARIO for sensitivity, not the new default: the ITU 3-UE /
%       rank-1 baseline (IMT characteristics Table A-2, Note 1: "the AAS BS
%       beamforms towards each UE using the entire array") is recovered
%       EXACTLY by leaving opts.layering off. Total radiated power is
%       conserved (L layers at sectorEirp - 10*log10(L) sum to sectorEirp),
%       so the band-integrated sector peak and the power self-check are
%       unchanged in BOUND; only the SPATIAL distribution of the EIRP
%       changes. Layers are summed INCOHERENTLY in linear mW (the existing
%       multi-beam convention). The scheduler / rank / power-split model is
%       STATISTICAL (gNB co-scheduling, power split and rank selection are
%       implementation-defined in TS 38.214), NOT a normative 38.214
%       algorithm. ENABLED + rank 1 + layerSpreadDeg 0 is an IDENTITY
%       expansion, byte-identical to OFF. See imtAasExpandUeLayers.
%
%   PRB / bandwidth weighting layer (non-breaking; default OFF;
%   SENSITIVITY ONLY -- DEPARTS FROM ITU):
%       opts.prbWeighting absent / [] -> disabled, and every existing output
%           (stats, percentileMaps, the power self-check, opts.ssb,
%           opts.epre, opts.layering) is BYTE-IDENTICAL to today for a fixed
%           seed because the layer adds NO RNG draws when off
%           (imtAasPrbWeights is not called at all). out.prbWeighting = [],
%           out.metadata.includesPrbWeighting = false.
%       opts.prbWeighting = struct(...) -> enables an UNEQUAL per-UE
%           bandwidth (PRB) weighting that REPLACES the uniform per-beam
%           power split (every beam at sectorEirp - 10*log10(N)) with
%           perBeamEirp_u = sectorEirp + 10*log10(f_u), where f_u is UE u's
%           fractional bandwidth share (sum f_u = 1). At constant EPRE (TS
%           38.214 Clause 4.1) band-integrated power is proportional to PRB
%           share. Fields (resolved + validated by imtAasPrbWeights):
%             .enable   logical (default true when the struct is present)
%             .mode     'fixed' | 'random' (default 'random')
%             .weights  1xNue per-UE shares (mode 'fixed'); nonneg/finite,
%                       not all zero; NORMALIZED to sum 1 internally
%             .spread   scalar sigma >= 0 (mode 'random'); log-normal share
%                       spread. sigma = 0 -> equal shares (recovers the ITU
%                       baseline; consumes NO RNG); larger sigma -> more
%                       unequal allocation. Default 0.5.
%       *** SENSITIVITY ONLY -- DEPARTS FROM THE ITU M.2101 BASELINE. ***
%       Unlike opts.layering (which reshapes the CDF but keeps the ITU power-
%       split PHILOSOPHY) and unlike opts.epre (a separate per-RE envelope
%       that never touches the baseline), opts.prbWeighting departs from the
%       ITU equal-bandwidth ASSUMPTION itself (IMT characteristics Table A-2,
%       Note 1: "UEs share equally the channel bandwidth"). It is therefore
%       NOT ITU-compliant and must NEVER be the default: the equal-split ITU
%       case is recovered by leaving it off and REMAINS the reference;
%       weighted results are to be presented ALONGSIDE (never INSTEAD OF) the
%       baseline. Like opts.layering, enabling it RESHAPES stats /
%       percentileMaps / the EIRP CDF (it changes per-beam power). Total
%       power is conserved (sum f_u = 1), so the band-integrated sector peak
%       and the power self-check are unchanged in BOUND; only the SPATIAL
%       distribution of the power changes. Band-integrated only: narrowband /
%       per-subband (frequency-selective occupancy) behaviour is the separate
%       subband / PRG item and is OUT OF SCOPE here -- the channel bandwidth
%       and the dBm/MHz normalization basis are NOT changed. Composition with
%       opts.layering is per-UE: UE u's power f_u is divided equally among its
%       r_u layers (perLayerEirp = sectorEirp + 10*log10(f_u / r_u)). The
%       scheduler / PRB-allocation model is STATISTICAL (implementation-
%       defined in TS 38.214), NOT a normative algorithm. See imtAasPrbWeights.
%
%   Activity-weighted EIRP CDF layer (non-breaking; default OFF):
%       opts.activityWeightedCdf (logical, default false) -> EXPLICIT
%           trigger. When false (default), out.activityWeightedPercentileMaps
%           is [] and every existing output is byte-identical for a fixed
%           seed (the layer is computed post-hoc and adds no RNG draws).
%       When true, a STATISTICAL "% of time" activity-weighted EIRP CDF-grid
%       is derived from the always-on histogram in stats by treating
%           p = tddActivityFactor * networkLoadingFactor
%       as a PROBABILITY OF TRANSMISSION (M.2101-style activity factor): the
%       sector radiates at its FULL peak EIRP a fraction p of the time and
%       is off the rest. This reshapes the CDF (correct for a "% of time"
%       exceedance criterion) and is NOT a flat dB power-reduction offset --
%       it does not shift the whole distribution down. The requested output
%       percentile Pout maps to the always-on percentile
%           Pon = 100 - (100 - Pout) / p
%       (exact under eirp_percentile_maps); requested percentiles in the off
%       region (Pon < 0, i.e. Pout <= 100*(1-p)) take opts.activityOffFloorDbm.
%       p = 1 reproduces the raw percentileMaps exactly. p is geometry-
%       independent, so this works for every aasGeometryPreset.
%       opts.activityModel ('legacy' | 'frame', default 'legacy') selects
%           the activity SOURCE so this CDF view and the opts.ssb time-
%           weighted grid can share ONE model:
%           'legacy' (default) -> p = tddActivityFactor*networkLoadingFactor
%               (byte-identical historical behaviour). When BOTH this layer
%               and opts.ssb are enabled but p disagrees with the frame-
%               budget alphaUe, a one-shot
%               runR23AasEirpCdfGrid:activityModelMismatch warning fires
%               (see imtAasActivityFrameConsistency).
%           'frame'            -> p = alphaUe from the symbol-counted TS
%               38.214 frame budget (imtAasDlFrameTimeBudget) -- the SAME
%               budget the time-weighted grid uses -- and the off region
%               radiates the always-on per-cell SSB sweep level instead of a
%               scalar floor, so F(x) = (1-p)*sweepFloor(az,el) + p*F_on,
%               consistent with timeWeighted.avg_dBm. The frame is
%               opts.ssb.timeBudget.frame when present, else a default frame
%               with frame.ssb.L = sweep beam count and frame.csirsUe.numUes
%               = numUesPerSector. With opts.ssb disabled, the default frame
%               budget is still built for p, but the off floor falls back to
%               the scalar opts.activityOffFloorDbm with an
%               runR23AasEirpCdfGrid:activityFrameNoSweepFloor warning.
%       opts.activityOffFloorUses ('timeAvg' | 'envelope', default
%           'timeAvg') -> which per-cell SSB sweep level the 'frame' off
%           region uses: 'timeAvg' = out.ssb.timeAvg_dBm, 'envelope' =
%           out.ssb.envelope_dBm.
%       Fields (all default to nestedParams.bs / -Inf):
%           opts.tddActivityFactor    finite scalar in (0,1] (default 0.75)
%           opts.networkLoadingFactor finite scalar in (0,1] (default 0.20;
%               the ITU example overrides to 0.25 -> p = 0.1875). Used by the
%               'legacy' model only; tagged legacy under 'frame'.
%           opts.activityOffFloorDbm  off-region percentile value (default
%               -Inf). Validated only when activityWeightedCdf is true.
%       The raw percentileMaps remain the always-on PEAK distribution; the
%       gain maps are NOT affected.
%
%   Power semantics (R23 macro 7.125-8.4 GHz):
%       maxEirpPerSector_dBm = 78.3   sector peak EIRP [dBm / 100 MHz]
%       conductedPower_dBm   = 46.1   conducted BS power [dBm / 100 MHz]
%       peakGain_dBi         = 32.2   peak composite gain [dBi]
%       46.1 + 32.2 = 78.3
%
%   maxEirpPerSector_dBm is the SECTOR peak EIRP and is split across
%   simultaneous beams via perBeamPeakEirpDbm = sectorEirp - 10*log10(N)
%   when splitSectorPower = true (default). Conducted power and gain are
%   never both added on top of an already-stated sector EIRP.
%
%   Output (OUT struct):
%       .params             imtAasDefaultParams-shaped struct used.
%       .nestedParams       full nested r23DefaultParams struct used (for
%                           reproduction / metadata).
%       .sector             imtAasSingleSectorParams(deployment, params).
%       .opts               resolved flat opts struct (with defaults).
%       .stats              streaming aggregator (counts, sum_lin_mW,
%                           min_dBm, max_dBm, mean_dBm, ...).
%       .percentileMaps     struct from eirp_percentile_maps.
%       .gainStats          gain accumulator (same shape as .stats but in
%                           dBi; the realized served-beam composite gain,
%                           max over beams). Empty ([]) unless
%                           opts.outputDomain is 'gain' or 'both'.
%       .gainPercentileMaps gain percentile maps (.values in dBi). Always
%                           present; .values is empty unless gain was
%                           computed. See opts.outputDomain.
%       .activityWeightedPercentileMaps  STATISTICAL "% of time" activity-
%                           weighted EIRP percentile maps (opt-in only; []
%                           unless opts.activityWeightedCdf). Same shape as
%                           percentileMaps with .values Naz x Nel x P in
%                           dBm/100MHz, plus .activeFraction (p),
%                           .tddActivityFactor, .networkLoadingFactor,
%                           .onPercentileEquivalent (Pon), .inOnRegion,
%                           .offFloorDbm (scalar for 'legacy', per-cell
%                           Naz x Nel SSB sweep floor for 'frame'),
%                           .activityModel, .offFloorUses, .note and (frame
%                           only) .frameBudget. The raw percentileMaps remain
%                           the always-on peak distribution; gain maps are
%                           unaffected. The on-fraction p is either the
%                           legacy tdd*load or the frame-budget alphaUe -- see
%                           opts.activityModel / opts.activityWeightedCdf.
%       .pointing           pointing-angle aggregator (when computed):
%                             .azimuthDegGrid       Naz x Nel [deg]
%                             .elevationDegGrid     Naz x Nel [deg]
%                             .summaryStatistic     'meanAcrossSnapshots'
%                             .azWrappedConvention  'circular mean atan2d'
%                             .numSamples           Naz x Nel uint32
%       .pointingHistogram  joint (steering az, steering el) pointing-angle
%                           distribution over ALL beams and ALL snapshots
%                           (enabled by opts.computePointingHistogram).
%                           Distinct from .pointing, which is the per-cell
%                           MEAN pointing direction; this is the PMF of
%                           where the array actually points. It is NOT
%                           time-weighted (see metadata.notes). Fields:
%                             .counts           nAzBin x nElBin (az = rows)
%                             .pmf              counts / numInRange
%                             .azEdges/.elEdges bin edges [deg]
%                             .azCenters/.elCenters bin centers [deg]
%                             .azMarginalCounts sum over el (nAzBin x 1)
%                             .elMarginalCounts sum over az (nElBin x 1)
%                             .numSamples       numBeams * numMc
%                             .numInRange       samples landing in a bin
%                             .numOutOfRange    samples dropped by binning
%                                               (numInRange + numOutOfRange
%                                                == numSamples; no silent
%                                                drops)
%                           When disabled, counts/pmf/marginals are empty
%                           and edges/centers are still populated.
%       .selfCheck          power-semantics self-check struct:
%                             .powerSemantics       expected vs observed
%                                                   sector / per-beam peak
%                                                   EIRP, status field is
%                                                   'pass' / 'warn' / 'fail'
%                                                   (HARD FAIL on EIRP
%                                                    exceeding sector peak,
%                                                    SOFT WARN on coarse-
%                                                    grid undershoot).
%       .epre               per-RE EPRE-offset layer (TS 38.214 Clause
%                           4.1) when opts.epre is enabled, else []:
%                             .dmrsBoostDb / .ptrsBoostDb / .csirsOffsetDb
%                             .hottestBoostDb = max(dmrsBoostDb, ptrsBoostDb)
%                             .perRePeakEnvelope_dBm  Naz x Nel per-RE
%                                 worst-case EIRP density [dBm] =
%                                 stats.max_dBm + hottestBoostDb (a
%                                 SEPARATE quantity from the band-integrated
%                                 maps; may exceed the 78.3 dBm sector peak)
%                             .perRePeakPercentileMaps  percentile maps of
%                                 the shifted envelope (baseline histogram
%                                 never mutated)
%                             .csirsClassEnvelope_dBm  CSI-RS-class envelope
%                                 (sweep envelope + csirsOffsetDb) or []
%                             .notes / .specReference
%                           out.metadata.includesEpre / .epreConfig record
%                           whether the layer ran and the resolved config.
%       .layering           rank / MU-MIMO layering diagnostics when
%                           opts.layering is enabled, else []:
%                             .realizedTotalLayers  struct .min/.mean/.max of
%                                 the per-draw total layer count L
%                             .realizedRankTally    struct .rankValues (1..R)
%                                 and .counts (ranks observed across all
%                                 UE-draws)
%                             .perLayerPeakEirpDbm   struct .min/.mean/.max of
%                                 the realized per-layer peak EIRP
%                                 (sectorEirp - 10*log10(L))
%                             .clipCount   total layers trimmed by clipRule
%                             .config      resolved layering config
%                             .notes / .specReference
%                           out.metadata.includesLayering / .layeringConfig
%                           record whether the layer ran and the resolved
%                           config. Enabling layering RESHAPES stats /
%                           percentileMaps (alternative scenario); the ITU
%                           3-UE / rank-1 baseline is recovered with it off.
%       .prbWeighting       PRB / bandwidth-weighting diagnostics when
%                           opts.prbWeighting is enabled, else []
%                           (SENSITIVITY ONLY, departs from ITU):
%                             .perBeamPeakEirpDbm   struct .min/.mean/.max of
%                                 the realized per-beam EIRP across draws
%                             .participationRatio   struct .min/.mean/.max of
%                                 the effective number of UEs (1/sum f_u^2)
%                             .config / .notes / .specReference
%                           out.metadata.includesPrbWeighting / .prbWeightingConfig
%                           record whether the layer ran and the resolved
%                           config. Enabling RESHAPES stats / percentileMaps
%                           (NOT ITU-compliant); the equal-split ITU baseline
%                           is recovered with it off and remains the reference.
%       .percentileTable    optional table from
%                           export_eirp_percentile_table when
%                           opts.outputCsvPath is provided.
%       .metadata           struct describing the run (generator, model,
%                           scope, no-path-loss/no-receiver caveats,
%                           environment, numUesPerSector,
%                           maxEirpPerSector_dBm, sourceDefault, ...).
%                           Provenance fields (best-effort, never fatal):
%                             .repoCommitSha          git HEAD or 'unknown'
%                             .matlabVersion          version + release tag
%                             .platform               os-arch identifier
%                             .validationTimestampUtc ISO 8601 UTC string
%
%   See also: r23DefaultParams, imtAasDefaultParams,
%             imtAasSingleSectorParams, imtAasGenerateBeamSet,
%             imtAasSectorEirpGridFromBeams, update_eirp_histograms,
%             eirp_percentile_maps, plotR23AasEirpCdfGrid,
%             plotR23AasPointingHeatmap, plotR23AasPointingHistogram,
%             imtAasPointingHistogram.

    % ---- argument resolution ----------------------------------------
    [opts, nestedParams, geom] = resolveInputs(varargin);

    % ---- apply AAS geometry preset to nested params -----------------
    % The preset selects the radiating-subarray geometry (R23 1x3 default
    % or CTIA 7 GHz 1x6) and the corresponding sector EIRP / conducted
    % power. It is purely a transmit-side antenna change: no propagation,
    % no clutter, no receiver, no laydown is touched.
    nestedParams = applyGeometryPresetToNested(nestedParams, geom);

    params = r23ToImtAasParams(nestedParams);

    % ---- output frame (non-breaking; default 'global') --------------
    % Resolve + validate opts.outputFrame and propagate it as
    % params.observationFrame so it rides the params struct down through
    % imtAasSectorEirpGridFromBeams -> imtAasEirpGrid -> imtAasCompositeGain.
    %   'global' (default) / 'sector' (alias) -> curved sector-frame maps
    %   'panel'                               -> flat panel-frame maps
    opts.outputFrame = resolveOutputFrame(opts);
    params.observationFrame = opts.outputFrame;

    % ---- beam selection (non-breaking; default 'ideal') --------------
    % Resolve + validate opts.beamSelection / opts.codebookOversample and
    % propagate the result as params.beamCodebook so it rides the params
    % struct down through imtAasSectorEirpGridFromBeams -> imtAasEirpGrid
    % -> imtAasCompositeGain -> imtAasArrayFactor, where the PANEL-FRAME
    % steering spatial frequencies are snapped to the Type I DFT grid
    % (after the mechanical-tilt transform, so the codebook is fixed to
    % the array as on real hardware).
    %   'ideal'    (default) -> continuous steering (historical, no-op)
    %   'codebook'           -> 3GPP TS 38.214 Sec. 5.2.2.2.1 Type I
    %                           single-panel oversampled-DFT (PMI) beams
    [opts.beamSelection, params.beamCodebook] = resolveBeamCodebook(opts);

    % ---- resolve opts with defaults ----------------------------------
    if ~isfield(opts, 'maxEirpPerSector_dBm') || isempty(opts.maxEirpPerSector_dBm)
        opts.maxEirpPerSector_dBm = nestedParams.bs.maxEirpPerSector_dBm;
    end

    % numBeams is the legacy alias for numUesPerSector. Resolution rules:
    %   * both present and equal              -> use it (no-op).
    %   * both present and disagree           -> numUesPerSector wins (warn).
    %   * only numUesPerSector present        -> set numBeams to match.
    %   * only numBeams present               -> set numUesPerSector to match.
    %   * neither present                     -> default from nested params.
    hasNumUes   = isfield(opts, 'numUesPerSector') && ~isempty(opts.numUesPerSector);
    hasNumBeams = isfield(opts, 'numBeams')        && ~isempty(opts.numBeams);
    if hasNumUes && hasNumBeams
        if ~isequal(double(opts.numBeams), double(opts.numUesPerSector))
            warning('runR23AasEirpCdfGrid:numBeamsConflict', ...
                ['opts.numBeams=%g conflicts with opts.numUesPerSector=%g; ' ...
                 'numUesPerSector wins.'], ...
                double(opts.numBeams), double(opts.numUesPerSector));
        end
        opts.numBeams = opts.numUesPerSector;
    elseif hasNumUes
        opts.numBeams = opts.numUesPerSector;
    elseif hasNumBeams
        opts.numUesPerSector = opts.numBeams;
    else
        opts.numUesPerSector = nestedParams.ue.numUesPerSector;
        opts.numBeams        = opts.numUesPerSector;
    end

    opts.numMc       = getOpt(opts, 'numMc',       nestedParams.sim.numSnapshots);
    opts.azGridDeg   = getOpt(opts, 'azGridDeg',   nestedParams.sim.azGrid_deg);
    opts.elGridDeg   = getOpt(opts, 'elGridDeg',   nestedParams.sim.elGrid_deg);
    opts.binEdgesDbm = getOpt(opts, 'binEdgesDbm', nestedParams.sim.binEdges_dBm);
    opts.percentiles = getOpt(opts, 'percentiles', nestedParams.sim.percentiles);
    opts.seed        = getOpt(opts, 'seed',        nestedParams.sim.randomSeed);
    opts.deployment  = getOpt(opts, 'deployment',  ...
                            environmentToDeployment(nestedParams.deployment.environment));
    opts.splitSectorPower    = getOpt(opts, 'splitSectorPower',    ...
                                        nestedParams.sim.splitSectorPower);
    opts.computePointingHeatmap = getOpt(opts, 'computePointingHeatmap', ...
                                        nestedParams.sim.computePointingHeatmap);

    % ---- pointing-angle histogram (non-breaking; default OFF) --------
    % Joint 2-D Monte Carlo distribution of the antenna POINTING ANGLES
    % (steering az/el across all beams and all snapshots). Distinct from
    % the MEAN-pointing heatmap above (out.pointing): this is the
    % probability distribution of where the array actually points. It reads
    % the already-generated beams.steerAzDeg/El (no extra RNG draws, no
    % per-beam EIRP grids), so the default-OFF path is byte-identical.
    %   Az +/-60 spans the sector coverage; el reaches -50 so the default
    %   edges cover BOTH the clamped [-10,0] case and the no-clamp case
    %   where beams steer to ~ -45. Both edge sets are overridable.
    opts.computePointingHistogram = getOpt(opts, 'computePointingHistogram', false);
    opts.pointingAzBinEdgesDeg    = getOpt(opts, 'pointingAzBinEdgesDeg', -60:2:60);
    opts.pointingElBinEdgesDeg    = getOpt(opts, 'pointingElBinEdgesDeg', -50:1:5);

    % ---- output domain (non-breaking; default 'eirp') ---------------
    % 'gain' and 'both' both compute EIRP + gain: EIRP is nearly free (the
    % gain falls straight out of the same per-beam pattern eval) and the
    % rest of the pipeline depends on it, so only 'eirp' (the default)
    % skips the gain accumulator entirely. The gain heatmap is the
    % realized served-beam composite gain in dBi (max over beams envelope).
    opts.outputDomain    = getOpt(opts, 'outputDomain', 'eirp');   % 'eirp' | 'gain' | 'both'
    opts.gainBinEdgesDbi = getOpt(opts, 'gainBinEdgesDbi', -100:0.5:40);
    opts.outputDomain    = validateOutputDomain(opts.outputDomain);
    computeGain = ismember(lower(char(opts.outputDomain)), {'gain', 'both'});

    opts.clampElevation      = getOpt(opts, 'clampElevation',      true);
    opts.progressEvery       = getOpt(opts, 'progressEvery',       0);
    opts.mcChunkSize         = getOpt(opts, 'mcChunkSize',         ...
                                        min(double(opts.numMc), 500));
    opts.outputCsvPath       = getOpt(opts, 'outputCsvPath',       '');
    opts.outputMetadataPath  = getOpt(opts, 'outputMetadataPath',  '');
    opts.environment         = getOpt(opts, 'environment',         ...
                                        nestedParams.deployment.environment);

    % ---- SSB broadcast sweep option (non-breaking; default OFF) ------
    % opts.ssb absent / [] -> disabled, and the traffic-only outputs
    % (stats, percentileMaps, self-check) stay byte-identical. A struct
    % enables the always-on SSB sweep + time-weighted EIRP, attached to
    % NEW output fields (out.ssb / out.timeWeighted) AFTER the streaming
    % aggregator and power self-check are finalised, so neither is touched.
    opts.ssb = resolveSsbOpts(getOpt(opts, 'ssb', []));

    % ---- per-RE EPRE-offset option (non-breaking; default OFF) -------
    % opts.epre absent / [] -> disabled, and every existing output
    % (stats, percentileMaps, the power self-check, and the opts.ssb
    % time-weighted outputs) stays byte-identical for a fixed seed. A
    % struct enables the TS 38.214 Clause 4.1 per-RE EPRE-offset layer,
    % attached to NEW output fields (out.epre) AFTER the streaming
    % aggregator, the power self-check, and the SSB sweep are finalised.
    % The ITU band-integrated baseline (78.3 dBm/100 MHz) is preserved:
    % the EPRE layer only adds a SEPARATE per-RE worst-case density
    % envelope and never mutates the band-integrated path.
    opts.epre = resolveEpreOpts(getOpt(opts, 'epre', []));

    % ---- rank / MU-MIMO layering option (non-breaking; default OFF) --
    % opts.layering absent / [] -> disabled, and every existing output
    % (stats, percentileMaps, the power self-check, opts.ssb, opts.epre)
    % stays byte-identical for a fixed seed because the layer adds NO RNG
    % draws when off (imtAasExpandUeLayers is not called at all). A struct
    % presence enables the layer; opts.layering.enable defaults true. Unlike
    % opts.epre (a post-hoc per-RE envelope), opts.layering changes the
    % per-draw BEAM SET, so when enabled it DOES reshape stats /
    % percentileMaps / the EIRP CDF -- that is the point. Total radiated
    % power is still conserved (L layers at sectorEirp - 10*log10(L) sum to
    % sectorEirp), so the band-integrated sector peak and the self-check are
    % unchanged in BOUND; only the SPATIAL distribution of the power changes.
    % The ITU 3-UE / rank-1 baseline (IMT characteristics Table A-2, Note 1)
    % is recovered exactly by leaving this off. Per-field validation is
    % performed downstream by imtAasExpandUeLayers.
    opts.layering = resolveLayeringOpts(getOpt(opts, 'layering', []));

    % ---- PRB / bandwidth weighting option (non-breaking; default OFF;
    %      SENSITIVITY ONLY -- DEPARTS FROM ITU) ------------------------
    % opts.prbWeighting absent / [] -> disabled, and every existing output
    % (stats, percentileMaps, the power self-check, opts.ssb, opts.epre,
    % opts.layering) stays byte-identical for a fixed seed because the layer
    % adds NO RNG draws when off (imtAasPrbWeights is not called at all). A
    % struct presence enables the layer; opts.prbWeighting.enable defaults
    % true. Unlike opts.layering (which keeps the ITU power-split philosophy)
    % this DEPARTS from the ITU equal-bandwidth ASSUMPTION (Table A-2, Note 1),
    % so it is NOT ITU-compliant and is sensitivity-only: the equal-split ITU
    % baseline is recovered with it off and remains the reference. When on it
    % RESHAPES the per-draw beam set (per-beam power), so stats /
    % percentileMaps / the EIRP CDF change; total power is conserved
    % (sum f_u = 1), so the band-integrated sector peak and self-check are
    % unchanged in BOUND. Per-field validation is performed downstream by
    % imtAasPrbWeights.
    opts.prbWeighting = resolvePrbWeightingOpts(getOpt(opts, 'prbWeighting', []));

    % ---- activity-weighted EIRP CDF option (non-breaking; default OFF)
    % opts.activityWeightedCdf absent/false -> disabled, and stats /
    % percentileMaps / gainPercentileMaps / pointing / timeWeighted are
    % byte-identical for a fixed seed. When true, a STATISTICAL activity-
    % weighted EIRP CDF-grid is computed post-hoc from the always-on
    % histogram by treating p = tddActivityFactor * networkLoadingFactor as
    % a PROBABILITY OF TRANSMISSION (M.2101-style activity factor): the
    % sector radiates at its FULL peak EIRP a fraction p of the time and is
    % off the rest. This reshapes the CDF (correct for a "% of time"
    % exceedance criterion) and is NOT a flat dB power-reduction offset. p
    % is geometry-independent, so this applies to any aasGeometryPreset.
    % activityModel selects the activity SOURCE (non-breaking; default
    % 'legacy'). 'legacy' = the standalone p = tdd*load probability-of-
    % transmission factor (byte-identical historical behaviour). 'frame' =
    % the symbol-counted TS 38.214 frame budget (imtAasDlFrameTimeBudget),
    % so this CDF view and the SSB time-weighted grid share ONE model: the
    % on-fraction becomes alphaUe and the off-region radiates the always-on
    % SSB sweep level instead of a scalar floor. activityOffFloorUses
    % selects which sweep level the 'frame' off-region uses: 'timeAvg'
    % (default, per-cell sweep time-average) or 'envelope' (per-cell sweep
    % worst-case envelope).
    opts.activityWeightedCdf  = getOpt(opts, 'activityWeightedCdf', false);
    opts.activityModel        = getOpt(opts, 'activityModel',        'legacy');
    opts.activityOffFloorUses = getOpt(opts, 'activityOffFloorUses', 'timeAvg');
    opts.tddActivityFactor    = getOpt(opts, 'tddActivityFactor',    nestedParams.bs.tddActivityFactor);
    opts.networkLoadingFactor = getOpt(opts, 'networkLoadingFactor', nestedParams.bs.networkLoadingFactor);
    opts.activityOffFloorDbm  = getOpt(opts, 'activityOffFloorDbm',  -Inf);
    if opts.activityWeightedCdf
        opts.activityModel        = validateActivityModel(opts.activityModel);
        opts.activityOffFloorUses = validateActivityOffFloorUses(opts.activityOffFloorUses);
        validateActivityFactor(opts.tddActivityFactor,    'tddActivityFactor');
        validateActivityFactor(opts.networkLoadingFactor, 'networkLoadingFactor');
    end

    % ---- propagate maxEirpPerSector override into params ------------
    if isnumeric(opts.maxEirpPerSector_dBm) && isscalar(opts.maxEirpPerSector_dBm) ...
            && isfinite(opts.maxEirpPerSector_dBm)
        params.sectorEirpDbm = double(opts.maxEirpPerSector_dBm);
        nestedParams.bs.maxEirpPerSector_dBm = double(opts.maxEirpPerSector_dBm);
    else
        error('runR23AasEirpCdfGrid:badMaxEirp', ...
            'opts.maxEirpPerSector_dBm must be a finite scalar [dBm].');
    end

    % ---- validation -------------------------------------------------
    validateNumUes(opts.numUesPerSector);
    validateNumMc(opts.numMc);

    azGrid = double(opts.azGridDeg(:).');
    elGrid = double(opts.elGridDeg(:).');
    edges  = double(opts.binEdgesDbm(:).');
    Naz    = numel(azGrid);
    Nel    = numel(elGrid);
    Nbin   = numel(edges) - 1;

    % ---- sector geometry --------------------------------------------
    sector = imtAasSingleSectorParams(opts.deployment, params);
    % Override sector geometry from nested params (cellRadius, bsHeight,
    % minUeDistance) so user-provided overrides are respected.
    sector.bsHeight_m       = nestedParams.deployment.bsHeight_m;
    sector.cellRadius_m     = nestedParams.deployment.cellRadius_m;
    sector.minUeDistance_m  = nestedParams.deployment.minUeDistance_m;
    sector.ueHeight_m       = nestedParams.ue.height_m;
    if isfield(nestedParams.deployment, 'sectorHalfWidthDeg') && ...
            ~isempty(nestedParams.deployment.sectorHalfWidthDeg)
        hw = double(nestedParams.deployment.sectorHalfWidthDeg);
        sector.azLimitsDeg  = [-hw, hw];
        sector.sectorWidthDeg = 2 * hw;
    end

    % ---- per-beam peak EIRP for metadata ----------------------------
    numBeams = double(opts.numUesPerSector);
    if opts.splitSectorPower
        perBeamPeakEirpDbm = params.sectorEirpDbm - 10 * log10(numBeams);
    else
        perBeamPeakEirpDbm = params.sectorEirpDbm;
    end

    % ---- init streaming stats ---------------------------------------
    stats = struct();
    stats.azGrid             = azGrid;
    stats.elGrid             = elGrid;
    stats.binEdges           = edges;
    stats.counts             = zeros(Naz, Nel, Nbin, 'uint32');
    stats.sum_lin_mW         = zeros(Naz, Nel);
    stats.min_dBm            =  inf(Naz, Nel);
    stats.max_dBm            = -inf(Naz, Nel);
    stats.numMc              = 0;
    stats.deployment         = sector.deployment;
    stats.environment        = nestedParams.deployment.environment;
    stats.numBeams           = numBeams;
    stats.numUesPerSector    = numBeams;
    stats.sectorEirpDbm      = params.sectorEirpDbm;
    stats.perBeamPeakEirpDbm = perBeamPeakEirpDbm;
    stats.params             = params;
    stats.opts               = opts;

    % ---- init parallel gain accumulator (only when requested) -------
    % Reuses the generic update_eirp_histograms aggregator. Its field
    % names say _dBm / _mW but the math is unit-agnostic; for gainStats
    % those fields hold dBi values (the realized served-beam composite
    % gain, max over beams). The .units / .aggregation tags document this.
    if computeGain
        gainEdges = double(opts.gainBinEdgesDbi(:).');
        NbinGain  = numel(gainEdges) - 1;
        gainStats = struct('azGrid',azGrid, 'elGrid',elGrid, 'binEdges',gainEdges, ...
            'counts',zeros(Naz,Nel,NbinGain,'uint32'), 'sum_lin_mW',zeros(Naz,Nel), ...
            'min_dBm',inf(Naz,Nel), 'max_dBm',-inf(Naz,Nel), 'numMc',0, ...
            'units','dBi', 'aggregation','max_over_beams_envelope');
    end

    % ---- init pointing aggregator -----------------------------------
    computePointing = logical(opts.computePointingHeatmap);
    if computePointing
        pointAgg = struct();
        pointAgg.sumCosAz   = zeros(Naz, Nel);
        pointAgg.sumSinAz   = zeros(Naz, Nel);
        pointAgg.sumEl      = zeros(Naz, Nel);
        pointAgg.numSamples = zeros(Naz, Nel, 'uint32');
    end

    % ---- init pointing-angle histogram aggregator -------------------
    % Independent of computePointing and of returnPerBeam: it bins the
    % applied beam steering directions only. Fixed-size accumulator (no
    % per-draw cube), in the same streaming spirit as stats.
    computePointingHist = logical(opts.computePointingHistogram);
    azEdges = double(opts.pointingAzBinEdgesDeg(:).');
    elEdges = double(opts.pointingElBinEdgesDeg(:).');
    if computePointingHist
        histAgg = struct();
        histAgg.counts        = zeros(numel(azEdges) - 1, numel(elEdges) - 1);
        histAgg.numSamples    = 0;
        histAgg.numOutOfRange = 0;
    end

    % ---- seed once and advance the global stream from there --------
    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    sectorOpts = struct( ...
        'splitSectorPower', logical(opts.splitSectorPower), ...
        'returnPerBeam',    computePointing, ...
        'sectorEirpDbm',    params.sectorEirpDbm, ...
        'computeGain',      computeGain);

    progressEvery = double(opts.progressEvery);
    numMc         = double(opts.numMc);

    % ---- rank / MU-MIMO layering streaming aggregator ---------------
    % Only created when the layer is enabled, so the OFF path is untouched
    % (and consumes no extra RNG). Accumulates running min/mean/max of the
    % realized total layer count L, a tally of realized ranks, the total
    % clipped-layer count, and the realized per-layer peak EIRP range -- all
    % fixed-size (no per-cell or per-draw cube), in the same streaming spirit
    % as `stats`.
    layeringEnabled = isstruct(opts.layering) && ...
        isfield(opts.layering, 'enable') && opts.layering.enable;
    if layeringEnabled
        layAgg = struct( ...
            'totalLayersMin', inf, 'totalLayersMax', -inf, 'totalLayersSum', 0, ...
            'clipSum', 0, 'rankTally', [], 'config', [], ...
            'perLayerMin', inf, 'perLayerMax', -inf, 'perLayerSum', 0);
    end

    % ---- PRB / bandwidth weighting streaming aggregator -------------
    % Only created when the layer is enabled, so the OFF path is untouched
    % (and consumes no extra RNG). Accumulates running min/mean/max of the
    % realized per-beam EIRP and of the participation ratio (effective number
    % of UEs), plus the resolved config -- all fixed-size (no per-cell or
    % per-draw cube), in the same streaming spirit as `stats` / `layAgg`.
    prbWeightingEnabled = isstruct(opts.prbWeighting) && ...
        isfield(opts.prbWeighting, 'enable') && opts.prbWeighting.enable;
    if prbWeightingEnabled
        prbAgg = struct( ...
            'perBeamMin', inf, 'perBeamMax', -inf, 'perBeamSum', 0, 'perBeamCount', 0, ...
            'prMin', inf, 'prMax', -inf, 'prSum', 0, 'config', []);
    end

    tStart = tic;
    [hWaitbar_ml_mc_chunks,hWaitbarMsgQueue_ml_mc_chunks]= ParForWaitbarCreateMH_time('Number of MC: ',numMc);    %%%%%%% Create ParFor Waitbar, this one covers points and chunks
    for it = 1:numMc
        it
        beamGenOpts = struct('clampElevation', logical(opts.clampElevation));
        beams = imtAasGenerateBeamSet(numBeams, sector, beamGenOpts);

        % ---- optional rank / MU-MIMO layer expansion ----------------
        % Gated on opts.layering.enable. When disabled this branch is NOT
        % entered, so imtAasExpandUeLayers consumes ZERO RNG and the loop's
        % RNG stream (and therefore stats) is byte-identical to today. When
        % enabled it expands the N UE beams into L = sum(r_u) layer beams;
        % everything downstream (imtAasSectorEirpGridFromBeams, the pointing
        % histogram, update_eirp_histograms) is unchanged and now sees L
        % layers, with the per-layer power split (sectorEirp - 10*log10(L))
        % and incoherent linear-mW sum falling out automatically.
        if layeringEnabled
            beams = imtAasExpandUeLayers(beams, sector, opts.layering);
            L = double(beams.totalLayers);
            layAgg.totalLayersMin = min(layAgg.totalLayersMin, L);
            layAgg.totalLayersMax = max(layAgg.totalLayersMax, L);
            layAgg.totalLayersSum = layAgg.totalLayersSum + L;
            layAgg.clipSum        = layAgg.clipSum + double(beams.clipped);
            if isempty(layAgg.rankTally)
                layAgg.rankTally = zeros(1, double(beams.config.maxRank));
                layAgg.config    = beams.config;
            end
            rr = beams.realizedRankPerUe;
            for u = 1:numel(rr)
                if rr(u) >= 1 && rr(u) <= numel(layAgg.rankTally)
                    layAgg.rankTally(rr(u)) = layAgg.rankTally(rr(u)) + 1;
                end
            end
            if logical(opts.splitSectorPower)
                perLayerDbm = params.sectorEirpDbm - 10 * log10(L);
            else
                perLayerDbm = params.sectorEirpDbm;
            end
            layAgg.perLayerMin = min(layAgg.perLayerMin, perLayerDbm);
            layAgg.perLayerMax = max(layAgg.perLayerMax, perLayerDbm);
            layAgg.perLayerSum = layAgg.perLayerSum + perLayerDbm;
        end

        % ---- optional PRB / bandwidth weighting (SENSITIVITY ONLY) ---
        % Gated on opts.prbWeighting.enable. Placed AFTER the layering block
        % so it can see beams.layerUeIndex (per-UE composition) when layering
        % is on; without layering each beam is its own UE. When disabled this
        % branch is NOT entered, so imtAasPrbWeights consumes ZERO RNG and the
        % loop's RNG stream (and therefore stats) is byte-identical to today.
        % It attaches a per-beam peak EIRP vector to `beams`, which
        % imtAasSectorEirpGridFromBeams uses INSTEAD of the uniform scalar
        % split (departs from the ITU equal-split baseline). Total power is
        % conserved (sum of the linear power fractions == 1).
        if prbWeightingEnabled
            if isfield(beams, 'layerUeIndex') && ~isempty(beams.layerUeIndex)
                ueIdx = beams.layerUeIndex(:);
            else
                ueIdx = (1:numel(beams.steerAzDeg)).';
            end
            pw = imtAasPrbWeights(ueIdx, opts.prbWeighting);
            if logical(opts.splitSectorPower)
                beams.perBeamPeakEirpDbm = params.sectorEirpDbm + 10 * log10(pw.wBeam(:));
            else
                beams.perBeamPeakEirpDbm = repmat(params.sectorEirpDbm, numel(pw.wBeam), 1);
            end
            pk = beams.perBeamPeakEirpDbm;
            prbAgg.perBeamMin   = min(prbAgg.perBeamMin, min(pk));
            prbAgg.perBeamMax   = max(prbAgg.perBeamMax, max(pk));
            prbAgg.perBeamSum   = prbAgg.perBeamSum + sum(pk);
            prbAgg.perBeamCount = prbAgg.perBeamCount + numel(pk);
            prbAgg.prMin = min(prbAgg.prMin, pw.participationRatio);
            prbAgg.prMax = max(prbAgg.prMax, pw.participationRatio);
            prbAgg.prSum = prbAgg.prSum + pw.participationRatio;
            if isempty(prbAgg.config)
                prbAgg.config = pw.config;
            end
        end

        sectorOut = imtAasSectorEirpGridFromBeams( ...
            azGrid, elGrid, beams, params, sectorOpts);

        stats = update_eirp_histograms(stats, sectorOut.aggregateEirpDbm);

        if computeGain
            % Unit-agnostic accumulator over dBi values (max-over-beams
            % served-beam gain envelope) rather than EIRP dBm.
            gainStats = update_eirp_histograms(gainStats, sectorOut.maxEnvelopeGainDbi);
        end

        if computePointing
            steerAz = double(beams.steerAzDeg(:));
            steerEl = double(beams.steerElDeg(:));
            % Selected beam at each grid cell = argmax along beam axis.
            [~, idx] = max(sectorOut.perBeamEirpDbm, [], 3);
            selAz = steerAz(idx);   % Naz x Nel
            selEl = steerEl(idx);
            pointAgg.sumCosAz   = pointAgg.sumCosAz   + cosd(selAz);
            pointAgg.sumSinAz   = pointAgg.sumSinAz   + sind(selAz);
            pointAgg.sumEl      = pointAgg.sumEl      + selEl;
            pointAgg.numSamples = pointAgg.numSamples + uint32(1);
        end

        if computePointingHist
            % Bin THIS snapshot's applied steering directions (all beams)
            % and fold into the running joint histogram. Reads the beams
            % directly -- no per-beam EIRP grid, no extra RNG.
            hk = imtAasPointingHistogram(beams.steerAzDeg(:), ...
                beams.steerElDeg(:), azEdges, elEdges);
            histAgg.counts        = histAgg.counts + hk.counts;
            histAgg.numSamples    = histAgg.numSamples + numel(beams.steerAzDeg);
            histAgg.numOutOfRange = histAgg.numOutOfRange + hk.numOutOfRange;
        end

        if progressEvery > 0 && mod(it, progressEvery) == 0
            tElapsed   = toc(tStart);
            tPerDraw   = tElapsed / it;
            tRemaining = tPerDraw * (numMc - it);
            fprintf(['[R23-MC] %d / %d (%.1f%%) ' ...
                     'elapsed=%.2fs ETA=%.2fs\n'], ...
                it, numMc, 100 * it / numMc, tElapsed, tRemaining);
        end
        hWaitbarMsgQueue_ml_mc_chunks.send(0);
    end
    delete(hWaitbarMsgQueue_ml_mc_chunks);
    close(hWaitbar_ml_mc_chunks);
    stats.elapsedSeconds = toc(tStart);

    stats.mean_lin_mW = stats.sum_lin_mW ./ max(stats.numMc, 1);
    stats.mean_dBm    = 10 .* log10(stats.mean_lin_mW);

    % ---- pointing summary ------------------------------------------
    tic;
    if computePointing
        ns = double(pointAgg.numSamples);
        nsSafe = max(ns, 1);
        meanCos = pointAgg.sumCosAz ./ nsSafe;
        meanSin = pointAgg.sumSinAz ./ nsSafe;
        meanAz  = atan2d(meanSin, meanCos);
        meanEl  = pointAgg.sumEl ./ nsSafe;
        % Cells with no samples (should be none in this MVP) get NaN.
        noData = (ns == 0);
        meanAz(noData) = NaN;
        meanEl(noData) = NaN;

        pointing = struct();
        pointing.azimuthDegGrid     = meanAz;
        pointing.elevationDegGrid   = meanEl;
        pointing.numSamples         = pointAgg.numSamples;
        pointing.summaryStatistic   = nestedParams.sim.pointingSummaryStatistic;
        pointing.azWrappedConvention = 'circular mean via atan2d(sumSin, sumCos)';
        pointing.azGrid             = azGrid;
        pointing.elGrid             = elGrid;
        pointing.units              = 'degrees';
    else
        pointing = struct( ...
            'azimuthDegGrid',   [], ...
            'elevationDegGrid', [], ...
            'numSamples',       [], ...
            'summaryStatistic', 'disabled', ...
            'azGrid',           azGrid, ...
            'elGrid',           elGrid, ...
            'units',            'degrees');
    end
    tic;

    % ---- pointing-angle histogram finalize --------------------------
    % Joint (az, el) pointing PMF over all beams and all snapshots. When
    % disabled, mirror the `pointing` placeholder: counts/pmf/marginals
    % empty, edges/centers still populated. This is NOT time-weighted
    % (consistent with metadata.notes); it is the Monte Carlo distribution
    % of UE-driven beam pointing directions.
    azCenters = azEdges(1:end-1) + diff(azEdges) / 2;
    elCenters = elEdges(1:end-1) + diff(elEdges) / 2;
    if computePointingHist
        total = sum(histAgg.counts(:));
        pmf   = histAgg.counts ./ max(total, 1);
        pointingHistogram = struct( ...
            'counts',           histAgg.counts, ...
            'pmf',              pmf, ...
            'azEdges',          azEdges, ...
            'elEdges',          elEdges, ...
            'azCenters',        azCenters, ...
            'elCenters',        elCenters, ...
            'azMarginalCounts', sum(histAgg.counts, 2), ...
            'elMarginalCounts', sum(histAgg.counts, 1).', ...
            'numSamples',       histAgg.numSamples, ...
            'numInRange',       total, ...
            'numOutOfRange',    histAgg.numOutOfRange, ...
            'units',            'degrees', ...
            'frame',            'azimuth relative to sector boresight; elevation 0 = horizon', ...
            'aggregation',      'count over all beams and all snapshots');
    else
        pointingHistogram = struct( ...
            'counts',           [], ...
            'pmf',              [], ...
            'azEdges',          azEdges, ...
            'elEdges',          elEdges, ...
            'azCenters',        azCenters, ...
            'elCenters',        elCenters, ...
            'azMarginalCounts', [], ...
            'elMarginalCounts', [], ...
            'numSamples',       0, ...
            'numInRange',       0, ...
            'numOutOfRange',    0, ...
            'units',            'degrees', ...
            'frame',            'azimuth relative to sector boresight; elevation 0 = horizon', ...
            'aggregation',      'count over all beams and all snapshots');
    end

    % ---- percentile maps --------------------------------------------
    'Percentile Maps'
    tic;
    pmaps = eirp_percentile_maps(stats, opts.percentiles);
    toc;

    % NOTE: the activity-weighted EIRP percentile maps are computed LATER
    % (after the optional SSB sweep) so that activityModel='frame' can read
    % the always-on per-cell SSB sweep floor from out.ssb. See the
    % "activity-weighted EIRP percentile maps" block near the end.

    % ---- gain percentile maps (only when requested) -----------------
    % Same generic percentile machinery; .values come out in dBi because
    % gainStats was accumulated over the dBi gain envelope.
    if computeGain
        gainMaps = eirp_percentile_maps(gainStats, opts.percentiles);
        % Tag units to match the disabled-path placeholder (line ~636) so
        % gainPercentileMaps.units is present regardless of outputDomain.
        gainMaps.units = 'dBi';
    end

    % ---- power-semantics self-check ---------------------------------
    % Continuously validate EIRP normalization to guard against future
    % power double-counting / aggregation / normalization regressions.
    %
    %   - HARD FAIL if the observed grid maximum exceeds the sector
    %     peak EIRP by more than a small numerical tolerance: that
    %     means power is being double-counted somewhere.
    %   - SOFT WARN if the observed peak is well below the expected
    %     per-beam peak: coarse grids / random steering may not land
    %     exactly on the beam peak, so this is informational only.
    %   - PASS otherwise.
    finiteMaxStats = stats.max_dBm(isfinite(stats.max_dBm));
    if isempty(finiteMaxStats)
        observedMax_dBm = -Inf;
    else
        observedMax_dBm = max(finiteMaxStats(:));
    end
    selfCheck = struct();
    selfCheck.powerSemantics = r23PowerSemanticsSelfCheck( ...
        observedMax_dBm, params.sectorEirpDbm, perBeamPeakEirpDbm, ...
        logical(opts.splitSectorPower));
    if strcmp(selfCheck.powerSemantics.status, 'fail')
        error('runR23AasEirpCdfGrid:powerSelfCheckFail', ...
            '%s', selfCheck.powerSemantics.message);
    elseif strcmp(selfCheck.powerSemantics.status, 'warn')
        warning('runR23AasEirpCdfGrid:powerSelfCheckWarn', ...
            '%s', selfCheck.powerSemantics.message);
    end

    % ---- metadata ---------------------------------------------------
    metadata = struct();
    metadata.generator             = 'runR23AasEirpCdfGrid';
    metadata.model                 = 'R23 7/8 GHz Extended AAS';
    metadata.scope                 = 'antenna-face EIRP CDF-grid only';
    metadata.aasModel              = nestedParams.metadata.aasModel;
    metadata.environment           = nestedParams.deployment.environment;
    metadata.deployment            = sector.deployment;
    metadata.cellRadius_m          = nestedParams.deployment.cellRadius_m;
    metadata.bsHeight_m            = nestedParams.deployment.bsHeight_m;
    metadata.bandwidthMHz          = params.bandwidthMHz;
    metadata.frequencyMHz          = params.frequencyMHz;
    metadata.numMc                 = double(opts.numMc);
    metadata.numSnapshots          = double(opts.numMc);
    metadata.numBeams              = numBeams;
    metadata.numUesPerSector       = numBeams;
    metadata.maxEirpPerSector_dBm  = params.sectorEirpDbm;
    metadata.sectorEirpDbm         = params.sectorEirpDbm;
    metadata.perBeamPeakEirpDbm    = perBeamPeakEirpDbm;
    metadata.splitSectorPower      = logical(opts.splitSectorPower);
    metadata.txPowerDbmPer100MHz   = params.txPowerDbmPer100MHz;
    metadata.peakGainDbi           = params.peakGainDbi;
    metadata.numRows               = params.numRows;
    metadata.numColumns            = params.numColumns;
    metadata.mechanicalDowntiltDeg = params.mechanicalDowntiltDeg;
    metadata.subarrayDowntiltDeg   = params.subarrayDowntiltDeg;
    metadata.seed                  = opts.seed;
    metadata.randomSeed            = opts.seed;
    metadata.outputFrame           = opts.outputFrame;
    % ---- output domain / gain heatmap (additive) -------------------
    metadata.outputDomain          = lower(char(opts.outputDomain));
    metadata.computeGain           = logical(computeGain);
    metadata.gainAggregation       = 'max_over_beams_envelope';
    metadata.gainBinEdgesDbi       = opts.gainBinEdgesDbi;     % (meaningful when computeGain)
    if computeGain
        metadata.peakRealizedGainDbi = max(gainMaps.values(:));
    else
        metadata.peakRealizedGainDbi = [];
    end
    % ---- activity-weighted CDF (additive; opt-in) ------------------
    % activityActiveFraction is FINALISED in the activity block near the end
    % (the 'frame' model resolves it from the symbol budget alphaUe). It is
    % seeded here with the legacy p = tdd*load so the legacy path is
    % byte-identical; the late block then overwrites out.metadata with the
    % resolved value (a no-op for the legacy model).
    metadata.activityWeightedCdf   = logical(opts.activityWeightedCdf);
    metadata.activityModel         = lower(char(opts.activityModel));
    if opts.activityWeightedCdf
        metadata.activityActiveFraction = opts.tddActivityFactor * opts.networkLoadingFactor;
        metadata.tddActivityFactor      = opts.tddActivityFactor;
        metadata.networkLoadingFactor   = opts.networkLoadingFactor;
    else
        metadata.activityActiveFraction = [];
    end
    metadata.beamSelection         = opts.beamSelection;
    metadata.beamCodebook          = params.beamCodebook;
    metadata.computePointingHeatmap = computePointing;
    metadata.computePointingHistogram = logical(opts.computePointingHistogram);
    metadata.pointingHistogramAzBinsDeg = opts.pointingAzBinEdgesDeg;
    metadata.pointingHistogramElBinsDeg = opts.pointingElBinEdgesDeg;
    metadata.clampElevation        = logical(opts.clampElevation);
    metadata.elevationLimitsDeg    = sector.elLimitsDeg;   % effective nominal gate [-10 0]
    metadata.pointingSummaryStatistic = nestedParams.sim.pointingSummaryStatistic;
    metadata.sourceDefault         = nestedParams.metadata.sourceDefault;
    % Propagate scenario preset metadata when present (set by
    % r23ScenarioPreset). Stays empty/absent for ad-hoc runs.
    if isfield(nestedParams, 'metadata') && isstruct(nestedParams.metadata)
        nm = nestedParams.metadata;
        if isfield(nm, 'scenarioPreset')
            metadata.scenarioPreset = nm.scenarioPreset;
        end
        if isfield(nm, 'scenarioCategory')
            metadata.scenarioCategory = nm.scenarioCategory;
        end
        if isfield(nm, 'sourceReference')
            metadata.sourceReference = nm.sourceReference;
        end
        if isfield(nm, 'reproducible')
            metadata.reproducible = logical(nm.reproducible);
        end
        if isfield(nm, 'presetOverrides')
            metadata.presetOverrides = nm.presetOverrides;
        end
        if isfield(nm, 'referenceOnly')
            metadata.referenceOnly = nm.referenceOnly;
        end
    end
    % ---- resolved AAS geometry preset (auditable) -------------------
    geomMeta = struct();
    geomMeta.aasGeometryPreset                          = geom.presetName;
    geomMeta.arrayRows                                  = double(geom.arrayRows);
    geomMeta.arrayCols                                  = double(geom.arrayCols);
    geomMeta.subarrayElementRows                        = double(geom.subarrayElementRows);
    geomMeta.subarrayElementCols                        = double(geom.subarrayElementCols);
    geomMeta.subarrayElementVerticalSpacingLambda       = double(geom.subarrayElementVerticalSpacingLambda);
    geomMeta.radiatingSubarrayHorizontalSpacingLambda   = double(geom.radiatingSubarrayHorizontalSpacingLambda);
    geomMeta.radiatingSubarrayVerticalSpacingLambda     = double(geom.radiatingSubarrayVerticalSpacingLambda);
    geomMeta.subarrayDowntiltDeg                        = double(geom.subarrayDowntiltDeg);
    geomMeta.mechanicalDowntiltDeg                      = double(geom.mechanicalDowntiltDeg);
    geomMeta.elementGainDbi                             = double(geom.elementGainDbi);
    geomMeta.calculatedSubarrayGainDb                   = double(geom.calculatedSubarrayGainDb);
    geomMeta.calculatedArrayGainDb                      = double(geom.calculatedArrayGainDb);
    geomMeta.calculatedAntennaGainDbi                   = double(geom.calculatedAntennaGainDbi);
    geomMeta.totalPhysicalElementsAcrossPolarizations   = double(geom.totalPhysicalElementsAcrossPolarizations);
    if isfield(geom, 'sectorEirpDbm') && ~isempty(geom.sectorEirpDbm)
        geomMeta.sectorEirpDbm = double(geom.sectorEirpDbm);
    end
    if isfield(geom, 'conductedPowerDbm') && ~isempty(geom.conductedPowerDbm)
        geomMeta.totalConductedPowerDbm = double(geom.conductedPowerDbm);
    end
    metadata.aasGeometry                   = geomMeta;
    metadata.aasGeometryPreset             = geom.presetName;

    metadata.includesPathLoss              = false;
    metadata.includesReceiverAntenna       = false;
    metadata.includesReceiverGain          = false;
    metadata.includesINMetric              = false;
    metadata.includesPropagation           = false;
    metadata.includesCoordinationDistance  = false;
    metadata.includesMultiSiteAggregation  = false;
    metadata.notes = ['R23 Extended AAS antenna-face EIRP CDF-grid only. ', ...
        'No path loss, no receiver antenna gain, no I / N, ', ...
        'no propagation, no coordination distance, no 19-site laydown. ', ...
        'CDF/percentiles describe Monte Carlo source-side snapshots over ', ...
        'UE-driven beam pointings; they are NOT a time-probability ', ...
        'distribution beyond the Monte Carlo ensemble.'];
    metadata.createdAtIso          = iso8601Now();
    metadata.validationTimestampUtc = metadata.createdAtIso;
    metadata.repoCommitSha         = getRepoCommitSha();
    metadata.matlabVersion         = getMatlabVersion();
    metadata.platform              = getPlatformDescription();

    % ---- assemble output --------------------------------------------
    out = struct();
    out.params         = params;
    out.nestedParams   = nestedParams;
    out.sector         = sector;
    out.opts           = opts;
    out.stats          = stats;
    out.percentileMaps = pmaps;
    out.pointing       = pointing;
    out.pointingHistogram = pointingHistogram;
    out.selfCheck      = selfCheck;
    % ---- gain heatmap outputs (always present; empty when not computed)
    % Mirrors the `pointing` disabled-placeholder pattern so the output
    % shape is predictable regardless of opts.outputDomain.
    if computeGain
        out.gainStats          = gainStats;
        out.gainPercentileMaps = gainMaps;          % .values in dBi
    else
        out.gainStats          = [];
        out.gainPercentileMaps = struct('percentiles',opts.percentiles, ...
            'azGrid',azGrid, 'elGrid',elGrid, 'values',[], 'binEdges',[], 'units','dBi');
    end
    % ---- activity-weighted percentile maps (always present; opt-in) -
    % Mirrors the disabled-placeholder pattern (pointing/gain): the field
    % is always populated with a predictable shape so consumers can probe
    % it unconditionally. Seeded empty ([]) here and populated by the
    % activity block AFTER the optional SSB sweep (so activityModel='frame'
    % can read the per-cell sweep floor from out.ssb).
    out.activityWeightedPercentileMaps = [];
    out.metadata       = metadata;

    % ---- optional SSB broadcast sweep + time-weighted EIRP ----------
    % Runs AFTER the streaming aggregator and the power self-check, on
    % NEW output fields only. opts.ssb never mutates stats / percentileMaps
    % (the traffic-only self-check above still validates the traffic path),
    % and the SSB beams are deterministic (no RNG draws), so the OFF path
    % and the fixed-seed traffic outputs are unchanged.
    if isstruct(opts.ssb) && isfield(opts.ssb, 'enable') && opts.ssb.enable
        ssbResult        = imtAasSsbOption(azGrid, elGrid, params, sector, stats, opts.ssb);
        out.ssb          = ssbResult.ssb;
        out.timeWeighted = ssbResult.timeWeighted;
        out.metadata.includesSsbSweep = true;
        out.metadata.ssbConfig        = ssbResult.config;
    else
        out.metadata.includesSsbSweep = false;
    end

    % ---- activity-weighted EIRP percentile maps (opt-in only) --------
    % Statistical "% of time" activity CDF computed POST-HOC from the
    % always-on histogram in `stats` (never mutated). The unconditional CDF
    % is  F(x) = (1-p)*[off floor] + p*F_on(x)  with point mass (1-p) at the
    % off floor, so the requested output percentile Pout maps to the
    % always-on percentile  Pon = 100 - (100 - Pout)/p  (exact under the
    % first-bin-where-cdf>=target lookup in eirp_percentile_maps), and
    % requested percentiles in the off region (Pon < 0) take the off floor.
    % This block runs AFTER the optional SSB sweep so the 'frame' model can
    % source p and the per-cell sweep off floor from the SAME frame budget /
    % out.ssb used by the time-weighted grid.
    %   activityModel='legacy' (default): p = tdd*load, off floor = the
    %       scalar opts.activityOffFloorDbm (byte-identical historical path).
    %   activityModel='frame'           : p = alphaUe from the TS 38.214
    %       frame budget, off floor = the per-cell always-on SSB sweep level.
    if opts.activityWeightedCdf
        activityModel = lower(char(opts.activityModel));
        Pout          = opts.percentiles(:).';
        [NazAw, NelAw, ~] = size(pmaps.values);
        frameBudget   = [];

        if strcmp(activityModel, 'frame')
            % ONE model: the symbol-counted TS 38.214 frame budget. The
            % on-fraction is the UE-class duty cycle alphaUe (NOT tdd*load).
            sweepBeamCount = resolveSweepBeamCount(out, opts);
            frameCfg       = resolveActivityFrameCfg(opts, double(opts.numUesPerSector), sweepBeamCount);
            frameBudget    = imtAasDlFrameTimeBudget(frameCfg);
            p              = frameBudget.alphaUe;
            % Off-region floor = the always-on SSB sweep level per cell.
            useEnvelope = strcmpi(char(opts.activityOffFloorUses), 'envelope');
            if isfield(out, 'ssb') && isstruct(out.ssb)
                if useEnvelope
                    offFloor = out.ssb.envelope_dBm;
                else
                    offFloor = out.ssb.timeAvg_dBm;
                end
            else
                offFloor = opts.activityOffFloorDbm;   % scalar fallback
                warning('runR23AasEirpCdfGrid:activityFrameNoSweepFloor', ...
                    ['activityModel=''frame'' with opts.ssb disabled: no per-cell ', ...
                     'SSB sweep floor is available, so off-region percentiles fall ', ...
                     'back to the scalar opts.activityOffFloorDbm (%g dBm). Enable ', ...
                     'opts.ssb to radiate the always-on sweep level in the off region.'], ...
                    opts.activityOffFloorDbm);
            end
        else
            % Legacy probability-of-transmission factor.
            p        = opts.tddActivityFactor * opts.networkLoadingFactor;
            offFloor = opts.activityOffFloorDbm;       % scalar off floor
            % Warn once when BOTH the activity CDF and the SSB sweep are on
            % but the legacy p disagrees with the frame-budget alphaUe.
            if isstruct(opts.ssb) && isfield(opts.ssb, 'enable') && opts.ssb.enable
                sweepBeamCount = resolveSweepBeamCount(out, opts);
                cmpCfg = resolveActivityFrameCfg(opts, double(opts.numUesPerSector), sweepBeamCount);
                cmpBud = imtAasDlFrameTimeBudget(cmpCfg);
                cons   = imtAasActivityFrameConsistency(cmpBud, p);
                if ~cons.consistent
                    warning('runR23AasEirpCdfGrid:activityModelMismatch', ...
                        ['activityModel=''legacy'': the activity-weighted CDF ', ...
                         'on-fraction p = tdd*load = %.4f disagrees with the ', ...
                         'frame-budget alphaUe = %.4f (delta %.4f). This CDF and the ', ...
                         'SSB time-weighted grid are then sourced from DIFFERENT ', ...
                         'activity factors. Set activityModel=''frame'' to reconcile ', ...
                         'both onto imtAasDlFrameTimeBudget.'], ...
                        p, cmpBud.alphaUe, cons.deltaAlphaUe);
                end
            end
        end

        Pon    = 100 - (100 - Pout) ./ p;
        onMask = Pon >= 0;                              % which requested pct are "on"
        if isscalar(offFloor)
            awVals = repmat(offFloor, NazAw, NelAw, numel(Pout));
        else
            % Per-cell off floor (Naz x Nel) broadcast across percentiles.
            awVals = repmat(offFloor, 1, 1, numel(Pout));
        end
        if any(onMask)
            onMaps = eirp_percentile_maps(stats, Pon(onMask));   % reuse tested engine
            awVals(:, :, onMask) = onMaps.values;                % NaN preserved for empty cells
        end

        awMaps = struct( ...
            'percentiles', Pout, 'azGrid', stats.azGrid, 'elGrid', stats.elGrid, ...
            'values', awVals, ...
            'activeFraction', p, ...
            'activityModel', activityModel, ...
            'tddActivityFactor', opts.tddActivityFactor, 'networkLoadingFactor', opts.networkLoadingFactor, ...
            'onPercentileEquivalent', Pon, 'inOnRegion', onMask, 'offFloorDbm', offFloor, ...
            'offFloorUses', lower(char(opts.activityOffFloorUses)), ...
            'units', 'dBm/100MHz', ...
            'note', activityModelNote(activityModel));
        if ~isempty(frameBudget)
            awMaps.frameBudget = frameBudget;
        end
        out.activityWeightedPercentileMaps = awMaps;

        % Finalise the activeFraction in metadata (no-op for the legacy
        % model, where it already equals tdd*load).
        out.metadata.activityActiveFraction = p;
        out.metadata.tddActivityFactor      = opts.tddActivityFactor;
        out.metadata.networkLoadingFactor   = opts.networkLoadingFactor;
    end

    % ---- optional per-RE EPRE-offset envelope (non-breaking) --------
    % Runs AFTER the streaming aggregator, the power self-check, and the
    % SSB sweep, on NEW output fields only. opts.epre never mutates stats /
    % percentileMaps / selfCheck / out.ssb / out.timeWeighted: the band-
    % integrated ITU baseline (78.3 dBm/100 MHz) is preserved exactly. The
    % EPRE layer surfaces only the SEPARATE per-RE worst-case density
    % envelope (perRePeakEnvelope_dBm = stats.max_dBm + hottestBoostDb),
    % which is ALLOWED to exceed the band-integrated sector peak by design
    % and is deliberately EXCLUDED from the band-integrated self-check.
    if isstruct(opts.epre) && isfield(opts.epre, 'enable') && opts.epre.enable
        epreOffsets = imtAasEpreOffsets(opts.epre);
        epreApplyOpts = struct('percentiles', opts.percentiles);
        if isfield(out, 'ssb') && isstruct(out.ssb) && ...
                isfield(out.ssb, 'envelope_dBm') && ~isempty(out.ssb.envelope_dBm)
            % CSI-RS-class offset rides the sweep-class envelope only.
            epreApplyOpts.sweepEnvelope_dBm = out.ssb.envelope_dBm;
        end
        epreResult = imtAasApplyEpreEnvelope(stats, epreOffsets, epreApplyOpts);

        epre = struct();
        epre.dmrsBoostDb             = epreResult.dmrsBoostDb;
        epre.ptrsBoostDb             = epreResult.ptrsBoostDb;
        epre.csirsOffsetDb           = epreResult.csirsOffsetDb;
        epre.hottestBoostDb          = epreResult.hottestBoostDb;
        epre.perRePeakEnvelope_dBm   = epreResult.perRePeakEnvelope_dBm;
        epre.perRePeakPercentileMaps = epreResult.perRePeakPercentileMaps;
        epre.csirsClassEnvelope_dBm  = epreResult.csirsClassEnvelope_dBm;
        epre.notes                   = epreResult.notes;
        epre.specReference           = epreResult.specReference;
        out.epre = epre;

        out.metadata.includesEpre = true;
        out.metadata.epreConfig   = epreOffsets.config;
    else
        out.epre = [];
        out.metadata.includesEpre = false;
    end

    % ---- optional rank / MU-MIMO layering diagnostics ---------------
    % Attaches NEW output fields only. The per-draw layer expansion has
    % already reshaped stats / percentileMaps (when enabled) -- this block
    % only summarises the streaming layering aggregator. When the layer is
    % off, out.layering = [] and metadata.includesLayering = false, and
    % every existing output is byte-identical to a no-layering run.
    %
    % NOTE: with layering on, the scalar metadata.perBeamPeakEirpDbm
    % (computed pre-loop from the FIXED numUesPerSector) is no longer the
    % realized per-layer power; the realized per-layer power DISTRIBUTION is
    % surfaced in out.layering.perLayerPeakEirpDbm. The band-integrated
    % self-check (observed aggregate max <= sector peak) remains valid
    % because total power is conserved regardless of L.
    if layeringEnabled
        layering = struct();
        layering.realizedTotalLayers = struct( ...
            'min',  layAgg.totalLayersMin, ...
            'mean', layAgg.totalLayersSum / max(numMc, 1), ...
            'max',  layAgg.totalLayersMax);
        layering.realizedRankTally = struct( ...
            'rankValues', 1:numel(layAgg.rankTally), ...
            'counts',     layAgg.rankTally);
        layering.perLayerPeakEirpDbm = struct( ...
            'min',  layAgg.perLayerMin, ...
            'mean', layAgg.perLayerSum / max(numMc, 1), ...
            'max',  layAgg.perLayerMax);
        layering.clipCount     = layAgg.clipSum;
        layering.config        = layAgg.config;
        layering.notes = ['Rank / MU-MIMO layering scenario (alternative ', ...
            'to the ITU 3-UE / rank-1 baseline). Each UE served with a rank ', ...
            'r_u; sector power split across L = sum(r_u) layers ', ...
            '(perLayer = sectorEirp - 10*log10(L)); layers summed ', ...
            'incoherently in linear mW. Total power conserved, so the ', ...
            'band-integrated sector peak and self-check are unchanged in ', ...
            'bound; only the spatial distribution of the EIRP changes. The ', ...
            'scalar metadata.perBeamPeakEirpDbm is the FIXED-N pre-loop ', ...
            'value, NOT the realized per-layer power (see ', ...
            'perLayerPeakEirpDbm). Statistical gNB-behaviour model, NOT a ', ...
            'normative TS 38.214 scheduling algorithm.'];
        layering.specReference = ['3GPP TS 38.214 V19.2.0 Clauses 5.1.1.1, ', ...
            '5.1.6.2, 5.2.2.5.1, 5.2.2.2.x.'];
        out.layering = layering;
        out.metadata.includesLayering = true;
        out.metadata.layeringConfig   = layAgg.config;
    else
        out.layering = [];
        out.metadata.includesLayering = false;
    end

    % ---- optional PRB / bandwidth weighting diagnostics (SENSITIVITY) -
    % Attaches NEW output fields only. The per-draw PRB weighting has already
    % reshaped stats / percentileMaps (when enabled) -- this block only
    % summarises the streaming PRB aggregator. When the layer is off,
    % out.prbWeighting = [] and metadata.includesPrbWeighting = false, and
    % every existing output is byte-identical to a no-prbWeighting run.
    %
    % NOTE: with PRB weighting on, the scalar metadata.perBeamPeakEirpDbm
    % (computed pre-loop from the FIXED numUesPerSector, equal split) is
    % NOMINAL only; the realized per-beam EIRP DISTRIBUTION is surfaced in
    % out.prbWeighting.perBeamPeakEirpDbm. The band-integrated self-check
    % (observed aggregate max <= sector peak) remains valid because total
    % power is conserved (sum of the per-beam linear power fractions == 1).
    % This is a SENSITIVITY SCENARIO that DEPARTS from the ITU equal-split
    % baseline; the equal-split ITU case remains the reference and is
    % recovered by leaving opts.prbWeighting off.
    if prbWeightingEnabled
        prbWeighting = struct();
        prbWeighting.perBeamPeakEirpDbm = struct( ...
            'min',  prbAgg.perBeamMin, ...
            'mean', prbAgg.perBeamSum / max(prbAgg.perBeamCount, 1), ...
            'max',  prbAgg.perBeamMax);
        prbWeighting.participationRatio = struct( ...
            'min',  prbAgg.prMin, ...
            'mean', prbAgg.prSum / max(numMc, 1), ...
            'max',  prbAgg.prMax);
        prbWeighting.config = prbAgg.config;
        prbWeighting.notes = ['PRB / bandwidth weighting scenario ', ...
            '(SENSITIVITY ONLY -- DEPARTS FROM THE ITU M.2101 EQUAL-BANDWIDTH ', ...
            'BASELINE). Each UE gets a fractional bandwidth share f_u ', ...
            '(sum f_u = 1); at constant EPRE its band-integrated power is ', ...
            'proportional to f_u, so perBeamEirp = sectorEirp + 10*log10(f_u) ', ...
            '(divided across a UE''s layers when opts.layering is on). This ', ...
            'is NOT ITU-compliant: the ITU equal-split case (each UE = 1/N of ', ...
            'the bandwidth) remains THE reference and is recovered by leaving ', ...
            'opts.prbWeighting off; weighted results are to be presented ', ...
            'ALONGSIDE, never INSTEAD OF, the baseline. Total power is ', ...
            'conserved (sum f_u = 1), so the band-integrated sector peak and ', ...
            'self-check are unchanged in BOUND; only the SPATIAL distribution ', ...
            'of the EIRP changes. Band-integrated only: narrowband / ', ...
            'per-subband (frequency-selective occupancy) behaviour is a ', ...
            'separate item and is out of scope. The scalar ', ...
            'metadata.perBeamPeakEirpDbm is the FIXED-N equal-split nominal, ', ...
            'NOT the realized per-beam power (see perBeamPeakEirpDbm above). ', ...
            'Statistical PRB-allocation model, NOT a normative TS 38.214 ', ...
            'scheduling algorithm.'];
        prbWeighting.specReference = ['3GPP TS 38.214 V19.2.0 Clauses ', ...
            '5.1.2.2, 5.1.2.2.1 / .2 (PDSCH frequency-domain resource ', ...
            'allocation type 0 / type 1), Clause 4.1 (downlink EPRE).'];
        out.prbWeighting = prbWeighting;
        out.metadata.includesPrbWeighting = true;
        out.metadata.prbWeightingConfig   = prbAgg.config;
    else
        out.prbWeighting = [];
        out.metadata.includesPrbWeighting = false;
    end

    % ---- optional CSV export ----------------------------------------
    if ~isempty(opts.outputCsvPath)
        out.percentileTable = export_eirp_percentile_table( ...
            stats, opts.outputCsvPath);
    end

    % ---- optional metadata sidecar ----------------------------------
    if ~isempty(opts.outputMetadataPath)
        writeMetadataSidecar(metadata, opts.outputMetadataPath);
    end
end

% =====================================================================

function [opts, nestedParams, geom] = resolveInputs(args)
%RESOLVEINPUTS Normalize varargin to (flat opts, nested params, geometry).

    nestedParams = [];
    opts = struct();

    if isempty(args)
        nestedParams = r23DefaultParams();
        geom = aasGeometryPreset('r23_1x3_default');
        return;
    end

    first = args{1};
    rest  = args(2:end);

    if isstruct(first)
        if looksLikeNestedParams(first)
            nestedParams = first;
        else
            opts = first;
        end
    elseif (ischar(first) || (isstring(first) && isscalar(first))) && ...
            mod(numel(args), 2) == 0
        % Pure name-value pair invocation.
        rest = args;
    else
        error('runR23AasEirpCdfGrid:badArgs', ...
            ['First argument must be a struct (flat opts or nested ' ...
             'params from r23DefaultParams) or a name/value string.']);
    end

    % If no nested params yet and an "environment" hint may be in the
    % name-value pairs, peek ahead so we can use the right preset.
    if isempty(nestedParams)
        env = peekNameValue(rest, 'environment');
        if isempty(env)
            envFromOpts = '';
            if isstruct(opts) && isfield(opts, 'environment') && ~isempty(opts.environment)
                envFromOpts = opts.environment;
            elseif isstruct(opts) && isfield(opts, 'deployment') && ~isempty(opts.deployment)
                envFromOpts = opts.deployment;
            end
            if ~isempty(envFromOpts)
                nestedParams = r23DefaultParams(envFromOpts);
            else
                nestedParams = r23DefaultParams();
            end
        else
            nestedParams = r23DefaultParams(env);
        end
    end

    % Strip geometry-related fields out of the flat OPTS struct and
    % convert them to the name-value form the existing geometry path
    % already consumes. They are prepended to `rest` so that any explicit
    % name-value override later in the same call wins (later wins inside
    % extractGeometryNameValues). This keeps the flat-opts and name-value
    % invocation styles bit-equivalent for identical inputs.
    [optsGeomNv, opts] = extractGeometryNvFromOpts(opts);
    rest = [optsGeomNv, rest];

    % Strip geometry-related name-value pairs before storing in opts.
    [geomPresetName, geomOverrides, rest] = extractGeometryNameValues(rest);

    % Apply remaining name-value overrides over the (possibly nested) opts.
    if ~isempty(rest)
        for k = 1:2:numel(rest)
            nm = rest{k};
            if isstring(nm) && isscalar(nm)
                nm = char(nm);
            end
            if ~ischar(nm)
                error('runR23AasEirpCdfGrid:badNV', ...
                    'Name-value names must be char/string scalars.');
            end
            opts.(nm) = rest{k+1};
        end
    end

    % If a nested params field was passed inside flat opts, prefer it.
    if isstruct(opts) && isfield(opts, 'params') && isstruct(opts.params) && ...
            looksLikeNestedParams(opts.params)
        nestedParams = opts.params;
        opts = rmfield(opts, 'params');
    end

    if isempty(geomPresetName)
        geomPresetName = 'r23_1x3_default';
    end
    geomOverrideArgs = structToNameValueCell(geomOverrides);
    geom = aasGeometryPreset(geomPresetName, geomOverrideArgs{:});
end

function [geomNv, opts] = extractGeometryNvFromOpts(opts)
%EXTRACTGEOMETRYNVFROMOPTS Strip geometry-related fields out of flat opts.
%
%   [GEOMNV, OPTS] = extractGeometryNvFromOpts(OPTS)
%
%   Pulls the AAS geometry preset name and per-field geometry overrides
%   out of the flat OPTS struct, returns them as a {name, value, ...}
%   cell array in canonical order (aasGeometryPreset first), and removes
%   them from OPTS. The cell array is fed into the same
%   extractGeometryNameValues path used for the name-value invocation,
%   so both invocation styles reach identical internal geometry state.
    geomNv = {};
    if ~isstruct(opts)
        return;
    end

    geomFieldNames = { ...
        'aasGeometryPreset', ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi', ...
        'sectorEirpDbm', 'conductedPowerDbm'};

    for k = 1:numel(geomFieldNames)
        fld = geomFieldNames{k};
        if isfield(opts, fld)
            geomNv{end+1} = fld;          %#ok<AGROW>
            geomNv{end+1} = opts.(fld);   %#ok<AGROW>
            opts = rmfield(opts, fld);
        end
    end
end

function [presetName, overrides, restOut] = extractGeometryNameValues(rest)
%EXTRACTGEOMETRYNAMEVALUES Strip geometry NV pairs out of generic rest.
    presetName = '';
    overrides  = struct();
    keep       = true(1, numel(rest));

    geomFieldNames = { ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi', ...
        'sectorEirpDbm', 'conductedPowerDbm'};

    for k = 1:2:numel(rest)-1
        nm = rest{k};
        if isstring(nm) && isscalar(nm)
            nm = char(nm);
        end
        if ~ischar(nm)
            continue;
        end
        if strcmpi(nm, 'aasGeometryPreset')
            v = rest{k+1};
            if isstring(v) && isscalar(v)
                v = char(v);
            end
            if ~ischar(v)
                error('runR23AasEirpCdfGrid:badGeometryPreset', ...
                    'aasGeometryPreset must be a char/string scalar.');
            end
            presetName = v;
            keep(k)   = false;
            keep(k+1) = false;
        else
            for f = 1:numel(geomFieldNames)
                if strcmp(nm, geomFieldNames{f})
                    overrides.(geomFieldNames{f}) = rest{k+1};
                    keep(k)   = false;
                    keep(k+1) = false;
                    break;
                end
            end
        end
    end

    restOut = rest(keep);
end

function args = structToNameValueCell(s)
%STRUCTTONAMEVALUECELL Flatten a struct into a {name, value, ...} cell.
    if ~isstruct(s)
        args = {};
        return;
    end
    flds = fieldnames(s);
    args = cell(1, 2 * numel(flds));
    for k = 1:numel(flds)
        args{2*k-1} = flds{k};
        args{2*k}   = s.(flds{k});
    end
end

function nestedParams = applyGeometryPresetToNested(nestedParams, geom)
%APPLYGEOMETRYPRESETTONESTED Push resolved geometry into nestedParams.aas/bs.
%
%   Only writes fields that the geometry preset has resolved. The nested
%   params struct is the single source of truth; downstream conversion
%   (r23ToImtAasParams) reads it.

    if ~isstruct(nestedParams) || ~isfield(nestedParams, 'aas') || ...
            ~isstruct(nestedParams.aas)
        return;
    end

    a = nestedParams.aas;

    a.numRows                                    = double(geom.arrayRows);
    a.numColumns                                 = double(geom.arrayCols);
    a.numElementRowsInSubarray                   = double(geom.subarrayElementRows);
    a.verticalElementSeparationInSubarray_lambda = double(geom.subarrayElementVerticalSpacingLambda);
    a.horizontalSpacing_lambda                   = double(geom.radiatingSubarrayHorizontalSpacingLambda);
    a.verticalSubarraySpacing_lambda             = double(geom.radiatingSubarrayVerticalSpacingLambda);
    a.subarrayDowntilt_deg                       = double(geom.subarrayDowntiltDeg);
    a.mechanicalDowntilt_deg                     = double(geom.mechanicalDowntiltDeg);
    a.elementGain_dBi                            = double(geom.elementGainDbi);
    a.aasGeometryPreset                          = geom.presetName;

    nestedParams.aas = a;

    % peakGain_dBi is metadata only (EIRP grids are renormalized to the
    % actual composite-gain peak inside imtAasEirpGrid), so it is left
    % alone here. The calculated antenna gain is surfaced via
    % out.metadata.aasGeometry.calculatedAntennaGainDbi.
    if isfield(nestedParams, 'bs') && isstruct(nestedParams.bs)
        b = nestedParams.bs;
        if isfield(geom, 'sectorEirpDbm') && ~isempty(geom.sectorEirpDbm) && ...
                isfinite(geom.sectorEirpDbm)
            b.maxEirpPerSector_dBm = double(geom.sectorEirpDbm);
        end
        if isfield(geom, 'conductedPowerDbm') && ~isempty(geom.conductedPowerDbm) && ...
                isfinite(geom.conductedPowerDbm)
            b.conductedPower_dBm = double(geom.conductedPowerDbm);
        end
        nestedParams.bs = b;
    end
end

function tf = looksLikeNestedParams(s)
    tf = isstruct(s) && ...
         (isfield(s, 'aas') && isstruct(s.aas)) && ...
         (isfield(s, 'bs')  && isstruct(s.bs))  && ...
         (isfield(s, 'ue')  && isstruct(s.ue));
end

function v = peekNameValue(rest, name)
    v = '';
    for k = 1:2:numel(rest)-1
        nm = rest{k};
        if isstring(nm) && isscalar(nm)
            nm = char(nm);
        end
        if ischar(nm) && strcmpi(nm, name)
            v = rest{k+1};
            return;
        end
    end
end

function dep = environmentToDeployment(env)
    if isstring(env) && isscalar(env)
        env = char(env);
    end
    switch lower(env)
        case {'urban', 'macrourban'}
            dep = 'macroUrban';
        case {'suburban', 'macrosuburban'}
            dep = 'macroSuburban';
        case {'micro', 'microurban'}
            dep = 'microUrban';
        case {'microsuburban'}
            dep = 'microSuburban';
        otherwise
            dep = char(env);
    end
end

function validateNumUes(N)
    if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N >= 1 && ...
            N == floor(N))
        error('runR23AasEirpCdfGrid:badNumUesPerSector', ...
            'numUesPerSector must be a positive integer.');
    end
end

function validateNumMc(N)
    if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N >= 1 && ...
            N == floor(N))
        error('runR23AasEirpCdfGrid:badNumMc', ...
            'numMc / numSnapshots must be a positive integer.');
    end
end

function validateActivityFactor(v, name)
%VALIDATEACTIVITYFACTOR Require a finite scalar in (0,1] for the activity-
%   weighted CDF probability factors. Only invoked when
%   opts.activityWeightedCdf is true.
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v > 0 && v <= 1)
        error('runR23AasEirpCdfGrid:badActivityFactor', ...
            '%s must be a finite scalar in (0, 1] when activityWeightedCdf is true.', name);
    end
end

function m = validateActivityModel(m)
%VALIDATEACTIVITYMODEL Read + validate opts.activityModel.
%   Default 'legacy' (resolved upstream). Allowed (case-insensitive):
%   'legacy' (standalone p = tdd*load) and 'frame' (TS 38.214 frame budget
%   alphaUe + per-cell SSB sweep off floor). Errors with id
%   'runR23AasEirpCdfGrid:invalidActivityModel'.
    if isstring(m) && isscalar(m)
        m = char(m);
    end
    if ~ischar(m)
        error('runR23AasEirpCdfGrid:invalidActivityModel', ...
            'opts.activityModel must be a char/string scalar (''legacy'' or ''frame'').');
    end
    m = lower(m);
    switch m
        case {'legacy', 'frame'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidActivityModel', ...
                'opts.activityModel must be ''legacy'' or ''frame'' (got ''%s'').', m);
    end
end

function u = validateActivityOffFloorUses(u)
%VALIDATEACTIVITYOFFFLOORUSES Read + validate opts.activityOffFloorUses.
%   Default 'timeAvg'. Allowed (case-insensitive): 'timeAvg' (per-cell SSB
%   sweep time-average) and 'envelope' (per-cell SSB sweep worst-case
%   envelope). Only consulted by the 'frame' activity model. Errors with id
%   'runR23AasEirpCdfGrid:invalidActivityOffFloorUses'.
    if isstring(u) && isscalar(u)
        u = char(u);
    end
    if ~ischar(u)
        error('runR23AasEirpCdfGrid:invalidActivityOffFloorUses', ...
            'opts.activityOffFloorUses must be a char/string scalar (''timeAvg'' or ''envelope'').');
    end
    if strcmpi(u, 'timeavg')
        u = 'timeAvg';
    elseif strcmpi(u, 'envelope')
        u = 'envelope';
    else
        error('runR23AasEirpCdfGrid:invalidActivityOffFloorUses', ...
            'opts.activityOffFloorUses must be ''timeAvg'' or ''envelope'' (got ''%s'').', u);
    end
end

function n = resolveSweepBeamCount(out, opts)
%RESOLVESWEEPBEAMCOUNT Sweep beam count for the frame budget ssb.L default.
%   Prefers the realised out.ssb.numBeams (when the SSB sweep ran);
%   otherwise mirrors the imtAasSsbOption defaults (coarseConf [3 3 2] -> 8,
%   or an explicit azPointsDeg list) so the frame budget matches the sweep
%   that imtAasSsbOption would build.
    n = 8;   % sum([3 3 2]) -- imtAasSsbOption default coarseConf
    if isfield(out, 'ssb') && isstruct(out.ssb) && isfield(out.ssb, 'numBeams') && ...
            ~isempty(out.ssb.numBeams)
        n = double(out.ssb.numBeams);
        return;
    end
    if isstruct(opts.ssb)
        if isfield(opts.ssb, 'coarseConf') && ~isempty(opts.ssb.coarseConf)
            n = sum(double(opts.ssb.coarseConf(:)));
        elseif isfield(opts.ssb, 'azPointsDeg') && ~isempty(opts.ssb.azPointsDeg)
            n = numel(opts.ssb.azPointsDeg);
        end
    end
end

function frameCfg = resolveActivityFrameCfg(opts, numUes, sweepBeamCount)
%RESOLVEACTIVITYFRAMECFG Build the imtAasDlFrameTimeBudget cfg for the
%   'frame' activity model. Uses opts.ssb.timeBudget.frame when present
%   (so the CDF view, the SSB time-weighted grid, and this share the SAME
%   frame); otherwise a default frame. The sweep beam count and per-UE
%   count default into the frame cfg using the SAME defaults
%   imtAasTimeWeightedGrid applies (frame.ssb.L <- sweep beam count,
%   frame.csirsUe.numUes <- numUesPerSector).
    frameCfg = struct();
    if isstruct(opts.ssb) && isfield(opts.ssb, 'timeBudget') && ...
            isstruct(opts.ssb.timeBudget) && isfield(opts.ssb.timeBudget, 'frame') && ...
            isstruct(opts.ssb.timeBudget.frame)
        frameCfg = opts.ssb.timeBudget.frame;
    end
    if ~isfield(frameCfg, 'ssb') || ~isstruct(frameCfg.ssb)
        frameCfg.ssb = struct();
    end
    if ~isfield(frameCfg.ssb, 'L') || isempty(frameCfg.ssb.L)
        frameCfg.ssb.L = sweepBeamCount;
    end
    if ~isfield(frameCfg, 'csirsUe') || ~isstruct(frameCfg.csirsUe)
        frameCfg.csirsUe = struct();
    end
    if ~isfield(frameCfg.csirsUe, 'numUes') || isempty(frameCfg.csirsUe.numUes)
        frameCfg.csirsUe.numUes = numUes;
    end
end

function s = activityModelNote(model)
%ACTIVITYMODELNOTE Human-readable note describing the activity CDF model.
    if strcmp(model, 'frame')
        s = ['Frame-budget activity model: p = alphaUe from ', ...
             'imtAasDlFrameTimeBudget (TS 38.214 symbol counting). The ', ...
             'off region radiates the always-on per-cell SSB sweep floor, ', ...
             'so F(x) = (1-p)*sweepFloor + p*F_on(traffic), consistent with ', ...
             'timeWeighted.avg_dBm. NOT a flat dB shift.'];
    else
        s = ['Probability-of-transmission activity model (p = tdd*load); ', ...
             'full peak EIRP a fraction p of the time. Percentiles below ', ...
             '100*(1-p) fall in the off region. NOT a time-average dB shift.'];
    end
end

function [mode, cb] = resolveBeamCodebook(opts)
%RESOLVEBEAMCODEBOOK Read + validate opts.beamSelection / codebookOversample.
%   Default 'ideal' (continuous steering; the byte-identical historical
%   path). Allowed (case-insensitive): 'ideal', 'codebook'. 'codebook'
%   selects the 3GPP TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I single-panel
%   oversampled-DFT (PMI) beam grid, applied to the panel-frame steering
%   inside imtAasArrayFactor. opts.codebookOversample is a positive
%   integer scalar or an [O_H O_V] pair; default [4 4] (TS 38.214 Table
%   5.2.2.2.1-2 default oversampling O1 = O2 = 4).
%   Errors:
%       runR23AasEirpCdfGrid:invalidBeamSelection
%       runR23AasEirpCdfGrid:invalidCodebookOversample
    mode = 'ideal';
    if isstruct(opts) && isfield(opts, 'beamSelection') && ...
            ~isempty(opts.beamSelection)
        mode = opts.beamSelection;
    end
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('runR23AasEirpCdfGrid:invalidBeamSelection', ...
            'opts.beamSelection must be a char/string scalar.');
    end
    mode = lower(mode);
    switch mode
        case {'ideal', 'codebook'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidBeamSelection', ...
                ['opts.beamSelection must be ''ideal'' or ''codebook'' ', ...
                 '(got ''%s'').'], mode);
    end

    os = [4 4];
    if isstruct(opts) && isfield(opts, 'codebookOversample') && ...
            ~isempty(opts.codebookOversample)
        os = opts.codebookOversample;
    end
    if ~(isnumeric(os) && isreal(os) && all(isfinite(os(:))) && ...
            any(numel(os) == [1 2]) && all(os(:) >= 1) && ...
            all(os(:) == floor(os(:))))
        error('runR23AasEirpCdfGrid:invalidCodebookOversample', ...
            ['opts.codebookOversample must be a positive integer scalar ', ...
             'or an [O_H O_V] pair of positive integers.']);
    end
    os = double(os(:).');
    if isscalar(os)
        os = [os, os];
    end

    if strcmp(mode, 'ideal')
        cb = struct('enable', false);
    else
        cb = struct('enable', true, ...
                    'oversampleH', os(1), ...
                    'oversampleV', os(2));
    end
end

function ssb = resolveSsbOpts(raw)
%RESOLVESSBOPTS Read + normalize the optional opts.ssb struct.
%   [] / absent -> struct('enable', false) (the SSB sweep is OFF and the
%   traffic-only path is byte-identical). A struct presence enables the
%   sweep; opts.ssb.enable defaults to true when the struct is supplied.
    ssb = struct('enable', false);
    if isempty(raw); return; end
    if ~isstruct(raw)
        error('runR23AasEirpCdfGrid:badSsbOpts', ...
            'opts.ssb must be a struct (or empty).');
    end
    ssb = raw;
    if ~isfield(ssb, 'enable') || isempty(ssb.enable); ssb.enable = true; end
    ssb.enable = logical(ssb.enable);
end

function epre = resolveEpreOpts(raw)
%RESOLVEEPREOPTS Read + normalize the optional opts.epre struct.
%   [] / absent -> struct('enable', false) (the per-RE EPRE layer is OFF
%   and every existing output is byte-identical). A struct presence enables
%   the layer; opts.epre.enable defaults to true when the struct is
%   supplied. The TS 38.214 Clause 4.1 field validation itself is performed
%   downstream by imtAasEpreOffsets.
    epre = struct('enable', false);
    if isempty(raw); return; end
    if ~isstruct(raw)
        error('runR23AasEirpCdfGrid:badEpreOpts', ...
            'opts.epre must be a struct (or empty).');
    end
    epre = raw;
    if ~isfield(epre, 'enable') || isempty(epre.enable); epre.enable = true; end
    epre.enable = logical(epre.enable);
end

function layering = resolveLayeringOpts(raw)
%RESOLVELAYERINGOPTS Read + normalize the optional opts.layering struct.
%   [] / absent -> struct('enable', false) (the rank / MU-MIMO layering
%   layer is OFF and every existing output is byte-identical for a fixed
%   seed; no extra RNG is drawn). A struct presence enables the layer;
%   opts.layering.enable defaults to true when the struct is supplied. The
%   per-field validation (rank / rank PMF / maxTotalLayers / layerSpreadDeg /
%   clipRule) is performed downstream by imtAasExpandUeLayers.
    layering = struct('enable', false);
    if isempty(raw); return; end
    if ~isstruct(raw)
        error('runR23AasEirpCdfGrid:badLayeringOpts', ...
            'opts.layering must be a struct (or empty).');
    end
    layering = raw;
    if ~isfield(layering, 'enable') || isempty(layering.enable)
        layering.enable = true;
    end
    layering.enable = logical(layering.enable);
end

function prbWeighting = resolvePrbWeightingOpts(raw)
%RESOLVEPRBWEIGHTINGOPTS Read + normalize the optional opts.prbWeighting struct.
%   [] / absent -> struct('enable', false) (the PRB / bandwidth weighting
%   layer is OFF and every existing output is byte-identical for a fixed
%   seed; no extra RNG is drawn). A struct presence enables the layer;
%   opts.prbWeighting.enable defaults to true when the struct is supplied.
%   The per-field validation (mode / weights / spread) is performed
%   downstream by imtAasPrbWeights. This layer is SENSITIVITY ONLY and
%   DEPARTS from the ITU equal-bandwidth baseline (see the docstring).
    prbWeighting = struct('enable', false);
    if isempty(raw); return; end
    if ~isstruct(raw)
        error('runR23AasEirpCdfGrid:badPrbWeightingOpts', ...
            'opts.prbWeighting must be a struct (or empty).');
    end
    prbWeighting = raw;
    if ~isfield(prbWeighting, 'enable') || isempty(prbWeighting.enable)
        prbWeighting.enable = true;
    end
    prbWeighting.enable = logical(prbWeighting.enable);
end

function frame = resolveOutputFrame(opts)
%RESOLVEOUTPUTFRAME Read + validate the optional opts.outputFrame field.
%   Default 'global'. Allowed (case-insensitive): 'global', 'sector'
%   (alias of global), 'panel'. Errors with id
%   'runR23AasEirpCdfGrid:invalidOutputFrame' on any other value.
    frame = 'global';
    if isstruct(opts) && isfield(opts, 'outputFrame') && ~isempty(opts.outputFrame)
        frame = opts.outputFrame;
    end
    if isstring(frame) && isscalar(frame)
        frame = char(frame);
    end
    if ~ischar(frame)
        error('runR23AasEirpCdfGrid:invalidOutputFrame', ...
            'opts.outputFrame must be a char/string scalar.');
    end
    frame = lower(frame);
    switch frame
        case {'global', 'sector', 'panel'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidOutputFrame', ...
                ['opts.outputFrame must be one of ''global'', ''sector'', ', ...
                 '''panel'' (got ''%s'').'], frame);
    end
end

function domain = validateOutputDomain(domain)
%VALIDATEOUTPUTDOMAIN Read + validate the optional opts.outputDomain field.
%   Allowed (case-insensitive): 'eirp' (default), 'gain', 'both'. Returns
%   the lowercased value. Errors with id
%   'runR23AasEirpCdfGrid:invalidOutputDomain' on any other value.
    if isstring(domain) && isscalar(domain)
        domain = char(domain);
    end
    if ~ischar(domain)
        error('runR23AasEirpCdfGrid:invalidOutputDomain', ...
            'opts.outputDomain must be a char/string scalar.');
    end
    domain = lower(domain);
    switch domain
        case {'eirp', 'gain', 'both'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidOutputDomain', ...
                ['opts.outputDomain must be one of ''eirp'', ''gain'', ', ...
                 '''both'' (got ''%s'').'], domain);
    end
end

function v = getOpt(opts, name, defaultVal)
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
    else
        v = defaultVal;
    end
end

function s = iso8601Now()
    try
        s = char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    catch
        s = datestr(now, 'yyyy-mm-ddTHH:MM:SS'); %#ok<DATST,TNOW1>
    end
end

function sha = getRepoCommitSha()
%GETREPOCOMMITSHA Best-effort `git rev-parse HEAD` for run provenance.
%   Returns 'unknown' when git or the repo are not available. Never
%   raises -- provenance is observability, not a hard precondition.
    sha = 'unknown';
    thisFile = mfilename('fullpath');
    if isempty(thisFile)
        return;
    end
    matlabDir = fileparts(thisFile);
    repoRoot  = fileparts(matlabDir);
    if isempty(repoRoot) || exist(repoRoot, 'dir') ~= 7
        return;
    end
    try
        cmd = sprintf('git -C "%s" rev-parse HEAD 2>/dev/null', repoRoot);
        [status, raw] = system(cmd);
        if status == 0
            tok = strtrim(raw);
            if ~isempty(tok)
                sha = tok;
            end
        end
    catch
        % Leave as 'unknown' on any failure.
    end
end

function v = getMatlabVersion()
%GETMATLABVERSION Compact MATLAB version string (e.g. '25.2 (R2025b)').
    v = 'unknown';
    try
        relStr = '';
        try
            r = version('-release');
            if ~isempty(r)
                relStr = sprintf(' (R%s)', r);
            end
        catch
        end
        v = sprintf('%s%s', version, relStr);
    catch
    end
end

function p = getPlatformDescription()
%GETPLATFORMDESCRIPTION Compact OS/arch identifier for provenance.
    p = 'unknown';
    try
        archStr = computer('arch');
    catch
        archStr = '';
    end
    try
        if ispc
            osStr = 'pc';
        elseif ismac
            osStr = 'mac';
        elseif isunix
            osStr = 'unix';
        else
            osStr = '';
        end
    catch
        osStr = '';
    end
    parts = {};
    if ~isempty(osStr); parts{end+1} = osStr; end %#ok<AGROW>
    if ~isempty(archStr); parts{end+1} = archStr; end %#ok<AGROW>
    if ~isempty(parts)
        p = strjoin(parts, '-');
    end
end

function writeMetadataSidecar(metadata, sidecarPath)
    [outDir, ~, ~] = fileparts(sidecarPath);
    if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    fid = fopen(sidecarPath, 'w');
    if fid < 0
        warning('runR23AasEirpCdfGrid:cannotOpenSidecar', ...
            'Could not open %s for writing.', sidecarPath);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    try
        fprintf(fid, '%s', jsonencode(metadata));
    catch
        flds = fieldnames(metadata);
        for k = 1:numel(flds)
            v = metadata.(flds{k});
            if ischar(v) || isstring(v)
                fprintf(fid, '%s = %s\n', flds{k}, char(v));
            elseif islogical(v)
                fprintf(fid, '%s = %d\n', flds{k}, double(v));
            elseif isnumeric(v) && isscalar(v)
                fprintf(fid, '%s = %.10g\n', flds{k}, double(v));
            else
                fprintf(fid, '%s = <unprintable>\n', flds{k});
            end
        end
    end
end
