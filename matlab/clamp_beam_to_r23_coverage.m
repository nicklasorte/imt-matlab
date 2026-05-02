function beams = clamp_beam_to_r23_coverage(bs, beams, params)
%CLAMP_BEAM_TO_R23_COVERAGE Clip raw beam angles to the R23 steering envelope.
%
%   BEAMS = clamp_beam_to_r23_coverage(BS, BEAMS)
%   BEAMS = clamp_beam_to_r23_coverage(BS, BEAMS, PARAMS)
%
%   Adds clamped steering fields to BEAMS by clipping rawAzDeg / rawElDeg
%   to the layout's azLimitsDeg / elLimitsDeg (R23 default: +/- 60 deg
%   horizontal, -10..0 deg vertical / equivalently 90..100 deg in the
%   R23 global-theta convention). The raw fields are preserved.
%
%   Two equivalent vertical representations are exposed side by side:
%
%       internal elevation  : steerElDeg in [-10, 0],   0 = horizon
%       R23 global theta    : steerThetaGlobalDeg       in [90, 100]
%
%   The conversion is exact and one-line (verified by
%   test_single_sector_eirp_mvp): thetaGlobalDeg = 90 - elevationDeg.
%   Existing callers that read steerElDeg / elLimitsDeg are unaffected -
%   the global-theta fields are additive.
%
%   Inputs:
%       BS      struct from get_default_bs (or override). May be omitted
%               if BEAMS already carries a .layout field, in which case
%               the embedded BS is used.
%       BEAMS   struct from compute_beam_angles_bs_to_ue.
%       PARAMS  optional struct from get_r23_aas_params.
%
%   Output (BEAMS appended with):
%       steerAzDeg            clamped azimuth steering [deg]
%       steerElDeg            clamped internal elevation [deg], expected
%                             range [-10, 0]
%       steerThetaGlobalDeg   clamped R23 global theta [deg], expected
%                             range [90, 100]
%       wasAzClipped          logical, true where rawAzDeg was clipped
%       wasElClipped          logical, true where rawElDeg was clipped
%       azLimitsDeg           1x2 azimuth limits [deg]
%       elLimitsDeg           1x2 internal elevation limits [deg]
%       thetaGlobalLimitsDeg  1x2 R23 global-theta limits [deg]
%                             (= [90 - elLimitsDeg(2), 90 - elLimitsDeg(1)])
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

    % R23 global-theta mirror of the internal elevation fields.
    % thetaGlobalDeg = 90 - elevationDeg; the limits flip because the
    % conversion is monotonically decreasing.
    steerThetaGlobalDeg  = 90 - steerElDeg;
    thetaGlobalLimitsDeg = [90 - elLim(2), 90 - elLim(1)];

    beams.steerAzDeg           = steerAzDeg;
    beams.steerElDeg           = steerElDeg;
    beams.steerThetaGlobalDeg  = steerThetaGlobalDeg;
    beams.wasAzClipped         = wasAzClipped;
    beams.wasElClipped         = wasElClipped;
    beams.azLimitsDeg          = azLim;
    beams.elLimitsDeg          = elLim;
    beams.thetaGlobalLimitsDeg = thetaGlobalLimitsDeg;
    beams.layout               = layout;
end
