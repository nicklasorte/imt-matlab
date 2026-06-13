function result = imtAasSsbOption(azGridDeg, elGridDeg, params, sector, stats, ssbOpts)
%IMTAASSSBOPTION Always-on SSB broadcast sweep + time-weighted EIRP grid.
%
%   RESULT = imtAasSsbOption(AZGRIDDEG, ELGRIDDEG, PARAMS, SECTOR, STATS, SSBOPTS)
%
%   Builds the always-on SSB beam sweep, evaluates it through the SAME
%   antenna engine as the traffic beams (imtAasSectorEirpGridFromBeams,
%   so identical normalization, mechanical-tilt transform and
%   observationFrame), and combines it with the streaming traffic STATS
%   into a time-weighted EIRP grid via imtAasTimeWeightedGrid.
%
%   STATS is the streaming traffic aggregator from runR23AasEirpCdfGrid and
%   is READ-ONLY: this function never writes back to it, so the traffic-only
%   power self-check is unaffected.
%
%   Sweep geometry (SSBOPTS fields, all optional):
%     .coarseConf   1xT az-beams-per-elevation-tier, default [3 3 2] (8 SSBs)
%     .elTiersDeg   1xT elevation per tier [deg], default [6 0 -3]
%                   (repo convention: 0 = horizon, + above, - below)
%     .azRangeDeg   [lo hi] sweep span [deg], default SECTOR.azLimitsDeg
%     .azPointsDeg  explicit per-beam azimuth list (overrides coarseConf)
%     .elPointsDeg  explicit per-beam elevation list (overrides elTiersDeg)
%     .splitSectorPower  logical, default false (each SSB beam peaks at the
%                   full sector EIRP -- the worst-case broadcast envelope)
%     .timeBudget   passed through to imtAasTimeWeightedGrid; default
%                   struct(). The sweep beam count defaults into both the
%                   legacy numSSB and the frame ssb.L fields.
%
%   For tier t the azimuth centres are spread uniformly across the sweep:
%       azCentres = azRange(1) + ((1:k) - 0.5) * (diff(azRange) / k)
%   with k = coarseConf(t) and elevation elTiersDeg(t), concatenated over
%   tiers. Azimuth is clamped to the sweep span; elevation tiers are NOT
%   clamped to [-10, 0] -- imtAasCompositeGain validates electronic steering
%   only to +/-90 deg, so the above-horizon +6 / 0 deg broadcast tiers are
%   intentional and survive.
%
%   Output RESULT struct:
%     .ssb           struct(azGrid, elGrid, numBeams, beamAzDeg, beamElDeg,
%                    envelope_dBm, timeAvg_dBm, perBeamEirpDbm)
%                    envelope_dBm  = per-cell max over sweep beams [dBm]
%                    timeAvg_dBm   = 10*log10(mean over beams of linear EIRP)
%     .timeWeighted  imtAasTimeWeightedGrid output
%     .config        struct(coarseConf, elTiersDeg, azRangeDeg, numBeams,
%                    splitSectorPower, timeBudget)
%
%   See also: imtAasSectorEirpGridFromBeams, imtAasTimeWeightedGrid,
%             imtAasDlFrameTimeBudget, runR23AasEirpCdfGrid.

    if nargin < 6 || isempty(ssbOpts) || ~isstruct(ssbOpts)
        ssbOpts = struct();
    end
    if nargin < 4 || isempty(sector)
        sector = imtAasSingleSectorParams();
    end
    if nargin < 3 || isempty(params)
        params = imtAasDefaultParams();
    end

    % ---- sweep azimuth span -----------------------------------------
    azRange = getf(ssbOpts, 'azRangeDeg', sector.azLimitsDeg);
    azRange = double(azRange(:).');
    if numel(azRange) ~= 2 || any(~isfinite(azRange)) || azRange(2) <= azRange(1)
        error('imtAasSsbOption:badAzRange', ...
            'ssbOpts.azRangeDeg must be a finite [lo hi] pair with hi > lo.');
    end

    % ---- build the sweep beam centres -------------------------------
    hasAz = isfield(ssbOpts, 'azPointsDeg') && ~isempty(ssbOpts.azPointsDeg);
    hasEl = isfield(ssbOpts, 'elPointsDeg') && ~isempty(ssbOpts.elPointsDeg);
    if hasAz || hasEl
        if ~(hasAz && hasEl)
            error('imtAasSsbOption:badPointLists', ...
                ['Provide BOTH ssbOpts.azPointsDeg and ssbOpts.elPointsDeg ', ...
                 '(or neither).']);
        end
        beamAz = double(ssbOpts.azPointsDeg(:));
        beamEl = double(ssbOpts.elPointsDeg(:));
        if numel(beamAz) ~= numel(beamEl)
            error('imtAasSsbOption:pointLenMismatch', ...
                ['ssbOpts.azPointsDeg (%d) and ssbOpts.elPointsDeg (%d) ', ...
                 'must have the same length.'], numel(beamAz), numel(beamEl));
        end
        % Config echoes the actual beam count / unique tiers used.
        coarseConf = numel(beamAz);
        elTiersDeg = unique(beamEl(:).', 'stable');
    else
        coarseConf = double(getf(ssbOpts, 'coarseConf', [3 3 2]));
        elTiersDeg = double(getf(ssbOpts, 'elTiersDeg', [6 0 -3]));
        coarseConf = coarseConf(:).';
        elTiersDeg = elTiersDeg(:).';
        if numel(coarseConf) ~= numel(elTiersDeg)
            error('imtAasSsbOption:tierMismatch', ...
                ['ssbOpts.coarseConf (%d tiers) and ssbOpts.elTiersDeg ', ...
                 '(%d tiers) must have the same length.'], ...
                numel(coarseConf), numel(elTiersDeg));
        end
        beamAz = zeros(0, 1);
        beamEl = zeros(0, 1);
        for t = 1:numel(coarseConf)
            k = coarseConf(t);
            if ~(isfinite(k) && k >= 1 && k == floor(k))
                error('imtAasSsbOption:badCoarseConf', ...
                    'ssbOpts.coarseConf entries must be positive integers.');
            end
            azC = azRange(1) + ((1:k) - 0.5) .* (diff(azRange) / k);
            beamAz = [beamAz; azC(:)];                       %#ok<AGROW>
            beamEl = [beamEl; repmat(elTiersDeg(t), k, 1)];  %#ok<AGROW>
        end
    end

    % Clamp azimuth into the sweep span (no elevation clamp on purpose).
    beamAz   = min(max(beamAz, azRange(1)), azRange(2));
    numBeams = numel(beamAz);

    splitSectorPower = logical(getf(ssbOpts, 'splitSectorPower', false));

    ssbBeams = struct('steerAzDeg', beamAz, 'steerElDeg', beamEl);

    % ---- evaluate through the EXISTING antenna engine ---------------
    sectorEirpDbm = params.sectorEirpDbm;
    ssbGrid = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ssbBeams, params, ...
        struct('splitSectorPower', splitSectorPower, ...
               'returnPerBeam',    true, ...
               'sectorEirpDbm',    sectorEirpDbm));

    envelope_dBm = ssbGrid.maxEnvelopeEirpDbm;                        % worst-case envelope
    condMeanLin  = mean(10 .^ (ssbGrid.perBeamEirpDbm ./ 10), 3);     % mean over sweep beams
    timeAvg_dBm  = 10 .* log10(condMeanLin);

    % ---- shape the ssb result struct (field-by-field to keep arrays) -
    ssb = struct();
    ssb.azGrid         = double(azGridDeg(:).');
    ssb.elGrid         = double(elGridDeg(:).');
    ssb.numBeams       = numBeams;
    ssb.beamAzDeg      = beamAz;
    ssb.beamElDeg      = beamEl;
    ssb.envelope_dBm   = envelope_dBm;
    ssb.timeAvg_dBm    = timeAvg_dBm;
    ssb.perBeamEirpDbm = ssbGrid.perBeamEirpDbm;

    % ---- time budget: default the beam count into legacy / frame ----
    timeBudget = getf(ssbOpts, 'timeBudget', struct());
    if isfield(timeBudget, 'frame') && isstruct(timeBudget.frame)
        if ~isfield(timeBudget.frame, 'ssb') || ~isstruct(timeBudget.frame.ssb)
            timeBudget.frame.ssb = struct();
        end
        if ~isfield(timeBudget.frame.ssb, 'L') || isempty(timeBudget.frame.ssb.L)
            timeBudget.frame.ssb.L = numBeams;
        end
    else
        if ~isfield(timeBudget, 'numSSB') || isempty(timeBudget.numSSB)
            timeBudget.numSSB = numBeams;
        end
    end

    tw = imtAasTimeWeightedGrid(stats, ssb, timeBudget);

    % ---- assemble ---------------------------------------------------
    config = struct();
    config.coarseConf       = coarseConf;
    config.elTiersDeg       = elTiersDeg;
    config.azRangeDeg       = azRange;
    config.numBeams         = numBeams;
    config.splitSectorPower = splitSectorPower;
    config.timeBudget       = tw.timeBudget;

    result = struct();
    result.ssb          = ssb;
    result.timeWeighted = tw;
    result.config       = config;
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
