function out = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, beams, params, opts)
%IMTAASSECTOREIRPGRIDFROMBEAMS Sector-level EIRP grid from a set of UE-driven beams.
%
%   OUT = imtAasSectorEirpGridFromBeams(AZGRIDDEG, ELGRIDDEG, BEAMS, PARAMS, OPTS)
%
%   Builds the antenna-face sector EIRP distribution over the (az, el)
%   observation grid for one IMT AAS sector that is simultaneously
%   serving NUMBEAMS UEs. For each beam, a peak-normalized per-direction
%   EIRP grid is produced via imtAasEirpGrid and the per-beam grids are
%   then aggregated by linear-power summation.
%
%   R23 power semantics:
%     78.3 dBm / 100 MHz is the SECTOR PEAK EIRP, not a per-beam allowance.
%     When the sector simultaneously serves NUMBEAMS UEs, the sector
%     conducted power is shared across the simultaneous BS-UE links, so
%     the per-beam peak EIRP is:
%
%         perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(numBeams)
%
%     when OPTS.SPLITSECTORPOWER is true (the default). Setting
%     OPTS.SPLITSECTORPOWER = false makes each beam peak at the full
%     sectorEirpDbm (use only for single-reference-beam diagnostics).
%
%   Inputs:
%       AZGRIDDEG   real numeric vector, azimuth grid [deg].
%       ELGRIDDEG   real numeric vector, elevation grid [deg].
%       BEAMS       struct with column-vector fields:
%                       steerAzDeg   per-beam steering azimuth [deg]
%                       steerElDeg   per-beam steering elevation [deg]
%                   Both must be finite real vectors of equal length.
%       PARAMS      optional imtAasDefaultParams struct (default
%                   imtAasDefaultParams()).
%       OPTS        optional struct. Recognised fields:
%                       sectorEirpDbm           default params.sectorEirpDbm
%                       splitSectorPower        default
%                                               params.defaultSplitSectorPowerAcrossBeams
%                                               (true if missing)
%                       aggregationMode         default 'sum_mW'
%                       returnPerBeam           default true
%                       normalizeEachBeamToPeak default true
%
%   Output struct fields:
%       azGridDeg                  vector passthrough [deg]
%       elGridDeg                  vector passthrough [deg]
%       AZ, EL                     ndgrid'd Naz x Nel arrays [deg]
%       perBeamEirpDbm             Naz x Nel x numBeams [dBm / 100 MHz]
%                                  (omitted when opts.returnPerBeam == false)
%       aggregateEirpDbm           Naz x Nel, linear-mW power-summed
%                                  [dBm / 100 MHz]
%       maxEnvelopeEirpDbm         Naz x Nel, per-cell envelope
%                                  (max over beams) [dBm / 100 MHz]
%       perBeamPeakEirpDbm         scalar peak EIRP per beam [dBm / 100 MHz]
%       sectorEirpDbm              scalar sector reference [dBm / 100 MHz]
%       splitSectorPower           logical
%       numBeams                   scalar
%       beams                      passthrough of input BEAMS
%       params                     passthrough of input PARAMS
%       peakAggregateEirpDbm       max(aggregateEirpDbm(:))
%       peakEnvelopeEirpDbm        max(maxEnvelopeEirpDbm(:))
%       eirpAggregateDbwPerHz      Naz x Nel [dBW / Hz]
%       eirpEnvelopeDbwPerHz       Naz x Nel [dBW / Hz]
%
%   Important - this function is antenna-face EIRP only:
%     * NO TDD activity factor
%     * NO network loading factor
%     * NO path loss
%     * NO receiver antenna gain
%     * NO I / N
%
%   See also: imtAasEirpGrid, imtAasGenerateBeamSet,
%             imtAasCreateDefaultSectorEirpGrid, imtAasDefaultParams.

    if nargin < 3 || isempty(beams)
        error('imtAasSectorEirpGridFromBeams:missingBeams', ...
            'BEAMS struct is required.');
    end
    if nargin < 4 || isempty(params)
        params = imtAasDefaultParams();
    end
    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('imtAasSectorEirpGridFromBeams:invalidOpts', ...
            'OPTS must be a struct (or [] for defaults).');
    end

    % ---- validate beams struct ----------------------------------------
    if ~isstruct(beams)
        error('imtAasSectorEirpGridFromBeams:invalidBeams', ...
            'BEAMS must be a struct.');
    end
    if ~isfield(beams, 'steerAzDeg') || ~isfield(beams, 'steerElDeg')
        error('imtAasSectorEirpGridFromBeams:missingBeamFields', ...
            'BEAMS must contain fields steerAzDeg and steerElDeg.');
    end
    steerAz = beams.steerAzDeg;
    steerEl = beams.steerElDeg;
    if ~isnumeric(steerAz) || ~isreal(steerAz) || ~isvector(steerAz) || ...
            isempty(steerAz) || any(~isfinite(steerAz))
        error('imtAasSectorEirpGridFromBeams:invalidSteerAz', ...
            'BEAMS.steerAzDeg must be a non-empty finite real numeric vector.');
    end
    if ~isnumeric(steerEl) || ~isreal(steerEl) || ~isvector(steerEl) || ...
            isempty(steerEl) || any(~isfinite(steerEl))
        error('imtAasSectorEirpGridFromBeams:invalidSteerEl', ...
            'BEAMS.steerElDeg must be a non-empty finite real numeric vector.');
    end
    if numel(steerAz) ~= numel(steerEl)
        error('imtAasSectorEirpGridFromBeams:beamLenMismatch', ...
            ['BEAMS.steerAzDeg (%d) and BEAMS.steerElDeg (%d) must ', ...
             'have the same length.'], numel(steerAz), numel(steerEl));
    end
    steerAz = double(steerAz(:));
    steerEl = double(steerEl(:));
    numBeams = numel(steerAz);

    % ---- validate grid vectors ----------------------------------------
    if ~isnumeric(azGridDeg) || ~isreal(azGridDeg) || ~isvector(azGridDeg) ...
            || isempty(azGridDeg) || any(~isfinite(azGridDeg(:)))
        error('imtAasSectorEirpGridFromBeams:invalidAzGrid', ...
            'AZGRIDDEG must be a non-empty finite real numeric vector.');
    end
    if ~isnumeric(elGridDeg) || ~isreal(elGridDeg) || ~isvector(elGridDeg) ...
            || isempty(elGridDeg) || any(~isfinite(elGridDeg(:)))
        error('imtAasSectorEirpGridFromBeams:invalidElGrid', ...
            'ELGRIDDEG must be a non-empty finite real numeric vector.');
    end
    azVec = double(azGridDeg(:).');
    elVec = double(elGridDeg(:).');
    Naz = numel(azVec);
    Nel = numel(elVec);
    [AZ, EL] = ndgrid(azVec, elVec);

    % ---- resolve opts -------------------------------------------------
    if isfield(opts, 'sectorEirpDbm') && ~isempty(opts.sectorEirpDbm)
        sectorEirpDbm = opts.sectorEirpDbm;
    else
        sectorEirpDbm = params.sectorEirpDbm;
    end
    if ~(isnumeric(sectorEirpDbm) && isreal(sectorEirpDbm) && ...
            isscalar(sectorEirpDbm) && isfinite(sectorEirpDbm))
        error('imtAasSectorEirpGridFromBeams:invalidSectorEirp', ...
            'sectorEirpDbm must be a real finite scalar [dBm].');
    end
    sectorEirpDbm = double(sectorEirpDbm);

    if isfield(opts, 'splitSectorPower') && ~isempty(opts.splitSectorPower)
        splitSectorPower = logical(opts.splitSectorPower);
    elseif isfield(params, 'defaultSplitSectorPowerAcrossBeams') && ...
            ~isempty(params.defaultSplitSectorPowerAcrossBeams)
        splitSectorPower = logical(params.defaultSplitSectorPowerAcrossBeams);
    else
        splitSectorPower = true;
    end

    if isfield(opts, 'aggregationMode') && ~isempty(opts.aggregationMode)
        aggregationMode = char(opts.aggregationMode);
    else
        aggregationMode = 'sum_mW';
    end
    if ~strcmpi(aggregationMode, 'sum_mW')
        error('imtAasSectorEirpGridFromBeams:unsupportedAggregation', ...
            ['Only aggregationMode = ''sum_mW'' is currently supported ', ...
             '(got ''%s'').'], aggregationMode);
    end

    if isfield(opts, 'returnPerBeam') && ~isempty(opts.returnPerBeam)
        returnPerBeam = logical(opts.returnPerBeam);
    else
        returnPerBeam = true;
    end

    if isfield(opts, 'normalizeEachBeamToPeak') && ...
            ~isempty(opts.normalizeEachBeamToPeak)
        normalizeEachBeamToPeak = logical(opts.normalizeEachBeamToPeak);
    else
        normalizeEachBeamToPeak = true;
    end

    % ---- per-beam peak EIRP (the power split) -------------------------
    if splitSectorPower
        perBeamPeakEirpDbm = sectorEirpDbm - 10 * log10(numBeams);
    else
        perBeamPeakEirpDbm = sectorEirpDbm;
    end

    % ---- per-beam EIRP grids ------------------------------------------
    perBeamEirpDbm = zeros(Naz, Nel, numBeams);
    for i = 1:numBeams
        perBeamEirpDbm(:, :, i) = imtAasEirpGrid( ...
            azVec, elVec, ...
            steerAz(i), steerEl(i), ...
            perBeamPeakEirpDbm, params);
    end

    % ---- aggregation by linear-mW power summation ---------------------
    aggregateEirpDbm   = 10 * log10(sum(10 .^ (perBeamEirpDbm / 10), 3));
    maxEnvelopeEirpDbm = max(perBeamEirpDbm, [], 3);

    bandwidthHz = double(params.bandwidthMHz) * 1e6;
    eirpAggregateDbwPerHz = aggregateEirpDbm - 30 - 10 * log10(bandwidthHz);
    eirpEnvelopeDbwPerHz  = maxEnvelopeEirpDbm - 30 - 10 * log10(bandwidthHz);

    % ---- assemble output ---------------------------------------------
    out = struct();
    out.azGridDeg              = azVec;
    out.elGridDeg              = elVec;
    out.AZ                     = AZ;
    out.EL                     = EL;
    if returnPerBeam
        out.perBeamEirpDbm     = perBeamEirpDbm;
    end
    out.aggregateEirpDbm       = aggregateEirpDbm;
    out.maxEnvelopeEirpDbm     = maxEnvelopeEirpDbm;
    out.perBeamPeakEirpDbm     = perBeamPeakEirpDbm;
    out.sectorEirpDbm          = sectorEirpDbm;
    out.splitSectorPower       = splitSectorPower;
    out.numBeams               = numBeams;
    out.beams                  = beams;
    out.params                 = params;
    out.peakAggregateEirpDbm   = max(aggregateEirpDbm(:));
    out.peakEnvelopeEirpDbm    = max(maxEnvelopeEirpDbm(:));
    out.eirpAggregateDbwPerHz  = eirpAggregateDbwPerHz;
    out.eirpEnvelopeDbwPerHz   = eirpEnvelopeDbwPerHz;
    out.aggregationMode        = aggregationMode;
    out.normalizeEachBeamToPeak = normalizeEachBeamToPeak;
end
