function beams = clamp_beam_to_r23_coverage(bs, beams, params)
%CLAMP_BEAM_TO_R23_COVERAGE Clip raw beam angles to the R23 steering envelope.
%
%   BEAMS = clamp_beam_to_r23_coverage(BS, BEAMS)
%   BEAMS = clamp_beam_to_r23_coverage(BS, BEAMS, PARAMS)
%
%   Adds clamped steering fields to BEAMS by clipping rawAzDeg / rawElDeg
%   to the layout's azLimitsDeg / elLimitsDeg (R23 default: +/- 60 deg
%   horizontal, -10..0 deg vertical). The raw fields are preserved.
%
%   Inputs:
%       BS      struct from get_default_bs (or override). May be omitted
%               if BEAMS already carries a .layout field, in which case
%               the embedded BS is used.
%       BEAMS   struct from compute_beam_angles_bs_to_ue.
%       PARAMS  optional struct from get_r23_aas_params.
%
%   Output (BEAMS appended with):
%       steerAzDeg     clamped azimuth steering [deg]
%       steerElDeg     clamped elevation steering [deg]
%       wasAzClipped   logical, true where rawAzDeg was clipped
%       wasElClipped   logical, true where rawElDeg was clipped
%       azLimitsDeg    1x2 azimuth limits [deg]
%       elLimitsDeg    1x2 elevation limits [deg]
%
%   See also: compute_beam_angles_bs_to_ue.

    if nargin < 2 || isempty(beams)
        error('clamp_beam_to_r23_coverage:missingBeams', ...
            'beams struct (see compute_beam_angles_bs_to_ue) is required.');
    end
    if ~isfield(beams, 'rawAzDeg') || ~isfield(beams, 'rawElDeg')
        error('clamp_beam_to_r23_coverage:badBeams', ...
            'beams must contain rawAzDeg and rawElDeg fields.');
    end

    if nargin < 1 || isempty(bs)
        if isfield(beams, 'layout') && ~isempty(beams.layout)
            layout = beams.layout;
        else
            error('clamp_beam_to_r23_coverage:missingBs', ...
                ['bs struct must be provided when beams.layout is empty ' ...
                 '(see get_default_bs, generate_single_sector_layout).']);
        end
    else
        if nargin < 3 || isempty(params)
            params = get_r23_aas_params();
        end
        layout = generate_single_sector_layout(bs, params);
    end

    azLim = layout.azLimitsDeg;
    elLim = layout.elLimitsDeg;
    rawAz = beams.rawAzDeg(:);
    rawEl = beams.rawElDeg(:);

    steerAzDeg = min(max(rawAz, azLim(1)), azLim(2));
    steerElDeg = min(max(rawEl, elLim(1)), elLim(2));

    wasAzClipped = (rawAz < azLim(1)) | (rawAz > azLim(2));
    wasElClipped = (rawEl < elLim(1)) | (rawEl > elLim(2));

    beams.steerAzDeg   = steerAzDeg;
    beams.steerElDeg   = steerElDeg;
    beams.wasAzClipped = wasAzClipped;
    beams.wasElClipped = wasElClipped;
    beams.azLimitsDeg  = azLim;
    beams.elLimitsDeg  = elLim;
    beams.layout       = layout;
end
