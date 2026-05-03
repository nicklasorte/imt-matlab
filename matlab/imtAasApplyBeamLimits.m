function beam = imtAasApplyBeamLimits(beam, sector)
%IMTAASAPPLYBEAMLIMITS Clamp raw beam steering angles to sector / R23 limits.
%
%   BEAM = imtAasApplyBeamLimits(BEAM)
%   BEAM = imtAasApplyBeamLimits(BEAM, SECTOR)
%
%   Adds clipped steering fields to BEAM by clamping the raw steering
%   angles to SECTOR.azLimitsDeg and SECTOR.elLimitsDeg. The raw fields
%   are preserved.
%
%   Inputs:
%       BEAM    struct produced by imtAasUeToBeamAngles (must have
%               rawSteerAzDeg / rawSteerElDeg fields).
%       SECTOR  optional sector struct; if omitted, BEAM.sector is used.
%
%   Output struct fields appended:
%       steerAzDeg     clamped azimuth steering [deg]
%       steerElDeg     clamped elevation steering [deg]
%       wasAzClipped   logical, true where rawSteerAzDeg was clipped
%       wasElClipped   logical, true where rawSteerElDeg was clipped
%       azLimitsDeg    1x2 azimuth limits [deg]
%       elLimitsDeg    1x2 elevation limits [deg]
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

    azLim = sector.azLimitsDeg;
    elLim = sector.elLimitsDeg;

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
