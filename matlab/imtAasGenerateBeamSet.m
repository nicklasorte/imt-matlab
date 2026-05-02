function beams = imtAasGenerateBeamSet(N, sector, opts)
%IMTAASGENERATEBEAMSET Generate N UE-driven AAS beam steering angles.
%
%   BEAMS = imtAasGenerateBeamSet(N)
%   BEAMS = imtAasGenerateBeamSet(N, SECTOR)
%   BEAMS = imtAasGenerateBeamSet(N, SECTOR, OPTS)
%
%   Convenience wrapper: samples N UE positions, converts each to a raw
%   beam steering angle, and (by default) clamps to the sector / R23
%   steering envelope.
%
%   Pipeline:
%       imtAasSampleUePositions -> imtAasUeToBeamAngles ->
%       imtAasApplyBeamLimits   (unless OPTS.applyLimits == false)
%
%   Inputs:
%       N       positive integer scalar (number of beams).
%       SECTOR  optional sector struct (default imtAasSingleSectorParams()).
%       OPTS    optional struct. Recognised fields:
%                 .seed         optional RNG seed (passes through to
%                               imtAasSampleUePositions).
%                 .azRelDeg     optional explicit length-N UE azimuths.
%                 .r_m          optional explicit length-N UE ranges.
%                 .ueHeight_m   optional UE height (scalar or length-N).
%                 .applyLimits  logical (default true). When false, the
%                               raw raw* fields are kept and steerAzDeg /
%                               steerElDeg / wasAzClipped / wasElClipped
%                               are NOT added.
%
%   Output struct fields:
%       N
%       ue                 ue struct from imtAasSampleUePositions
%       sector             sector struct passthrough
%       rawSteerAzDeg      Nx1 raw steering azimuth [deg]
%       rawSteerElDeg      Nx1 raw steering elevation [deg]
%       groundRange_m      Nx1 BS-to-UE ground range [m]
%       slantRange_m       Nx1 BS-to-UE slant range [m]
%       azGlobalDeg        Nx1 absolute azimuth [deg]
%       (when limits are applied):
%       steerAzDeg         Nx1 clamped azimuth [deg]
%       steerElDeg         Nx1 clamped elevation [deg]
%       wasAzClipped       Nx1 logical
%       wasElClipped       Nx1 logical
%       azLimitsDeg        1x2 [deg]
%       elLimitsDeg        1x2 [deg]
%
%   See also: imtAasSingleSectorParams, imtAasSampleUePositions,
%             imtAasUeToBeamAngles, imtAasApplyBeamLimits.

    if nargin < 2 || isempty(sector)
        sector = imtAasSingleSectorParams();
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    if isfield(opts, 'applyLimits') && ~isempty(opts.applyLimits)
        applyLimits = logical(opts.applyLimits);
    else
        applyLimits = true;
    end

    sampleOpts = struct();
    if isfield(opts, 'seed') && ~isempty(opts.seed)
        sampleOpts.seed = opts.seed;
    end
    if isfield(opts, 'azRelDeg') && ~isempty(opts.azRelDeg)
        sampleOpts.azRelDeg = opts.azRelDeg;
    end
    if isfield(opts, 'r_m') && ~isempty(opts.r_m)
        sampleOpts.r_m = opts.r_m;
    end
    if isfield(opts, 'ueHeight_m') && ~isempty(opts.ueHeight_m)
        sampleOpts.ueHeight_m = opts.ueHeight_m;
    end

    ue   = imtAasSampleUePositions(N, sector, sampleOpts);
    beam = imtAasUeToBeamAngles(ue, sector);

    if applyLimits
        beam = imtAasApplyBeamLimits(beam, sector);
    end

    beams = struct();
    beams.N             = ue.N;
    beams.ue            = ue;
    beams.sector        = sector;
    beams.rawSteerAzDeg = beam.rawSteerAzDeg;
    beams.rawSteerElDeg = beam.rawSteerElDeg;
    beams.groundRange_m = beam.groundRange_m;
    beams.slantRange_m  = beam.slantRange_m;
    beams.azGlobalDeg   = beam.azGlobalDeg;

    if applyLimits
        beams.steerAzDeg   = beam.steerAzDeg;
        beams.steerElDeg   = beam.steerElDeg;
        beams.wasAzClipped = beam.wasAzClipped;
        beams.wasElClipped = beam.wasElClipped;
        beams.azLimitsDeg  = beam.azLimitsDeg;
        beams.elLimitsDeg  = beam.elLimitsDeg;
    end
end
