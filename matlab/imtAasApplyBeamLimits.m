function beam = imtAasApplyBeamLimits(beam, sector, limitOpts)
%IMTAASAPPLYBEAMLIMITS Clamp raw beam steering angles to sector / R23 limits.
%
%   BEAM = imtAasApplyBeamLimits(BEAM)
%   BEAM = imtAasApplyBeamLimits(BEAM, SECTOR)
%   BEAM = imtAasApplyBeamLimits(BEAM, SECTOR, LIMITOPTS)
%
%   Adds clipped steering fields to BEAM by clamping the raw steering
%   angles to SECTOR.azLimitsDeg and SECTOR.elLimitsDeg. The raw fields
%   are preserved.
%
%   Inputs:
%       BEAM      struct produced by imtAasUeToBeamAngles (must have
%                 rawSteerAzDeg / rawSteerElDeg fields).
%       SECTOR    optional sector struct; if omitted, BEAM.sector is used.
%       LIMITOPTS optional struct. Recognised fields:
%                   .clampElevation  logical (default true). When true the
%                                    elevation steering is clamped to the
%                                    nominal SECTOR.elLimitsDeg vertical-
%                                    coverage gate ([-10, 0] deg). When
%                                    false the elevation gate is disabled
%                                    by swapping the elevation limit vector
%                                    to [-Inf, Inf], so steerElDeg == rawEl,
%                                    wasElClipped is all-false, and the
%                                    reported elLimitsDeg is [-Inf, Inf]
%                                    (the audit signal for "no elevation
%                                    clamp"). Azimuth clamping is
%                                    UNAFFECTED in both modes.
%
%   Output struct fields appended:
%       steerAzDeg     clamped azimuth steering [deg]
%       steerElDeg     clamped elevation steering [deg]
%       wasAzClipped   logical, true where rawSteerAzDeg was clipped
%       wasElClipped   logical, true where rawSteerElDeg was clipped
%       azLimitsDeg    1x2 azimuth limits [deg]
%       elLimitsDeg    1x2 elevation limits [deg] ([-Inf, Inf] when
%                      clampElevation is false)
%
%   See also: imtAasUeToBeamAngles, imtAasGenerateBeamSet.

    if nargin < 1 || isempty(beam)
        error('imtAasApplyBeamLimits:missingBeam', 'beam struct is required.');
    end
    if ~isfield(beam, 'rawSteerAzDeg') || ~isfield(beam, 'rawSteerElDeg')
        error('imtAasApplyBeamLimits:missingFields', ...
            'beam must contain rawSteerAzDeg and rawSteerElDeg.');
    end

    if nargin < 2 || isempty(sector)
        if isfield(beam, 'sector') && ~isempty(beam.sector)
            sector = beam.sector;
        else
            sector = imtAasSingleSectorParams();
        end
    end

    if nargin < 3 || isempty(limitOpts)
        limitOpts = struct();
    end
    if isfield(limitOpts, 'clampElevation') && ~isempty(limitOpts.clampElevation)
        clampElevation = logical(limitOpts.clampElevation);
    else
        clampElevation = true;
    end

    % Azimuth limits are always the nominal sector envelope. The elevation
    % gate is disabled (clip-free) by swapping its limit vector to
    % [-Inf, Inf]: all downstream min/max + wasClipped arithmetic is then
    % unchanged but steerElDeg == rawEl, wasElClipped is all-false, and the
    % reported elLimitsDeg becomes [-Inf, Inf] (the no-clamp audit signal).
    azLim = sector.azLimitsDeg;
    if clampElevation
        elLim = sector.elLimitsDeg;     % nominal [-10 0]
    else
        elLim = [-Inf, Inf];            % elevation gate disabled
    end

    rawAz = beam.rawSteerAzDeg(:);
    rawEl = beam.rawSteerElDeg(:);

    steerAzDeg = min(max(rawAz, azLim(1)), azLim(2));
    steerElDeg = min(max(rawEl, elLim(1)), elLim(2));

    wasAzClipped = (rawAz < azLim(1)) | (rawAz > azLim(2));
    wasElClipped = (rawEl < elLim(1)) | (rawEl > elLim(2));

    beam.steerAzDeg   = steerAzDeg;
    beam.steerElDeg   = steerElDeg;
    beam.wasAzClipped = wasAzClipped;
    beam.wasElClipped = wasElClipped;
    beam.azLimitsDeg  = azLim;
    beam.elLimitsDeg  = elLim;
end
