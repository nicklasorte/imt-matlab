function params = imtAasDefaultParams()
%IMTAASDEFAULTPARAMS Default IMT AAS parameters (R23 / WP5D 7.125-8.4 GHz).
%
%   PARAMS = imtAasDefaultParams()
%
%   Returns a struct with the WP5D R23 macro-AAS reference parameters used
%   by the AAS EIRP grid MVP:
%       imtAasElementPattern, imtAasArrayFactor,
%       imtAasCompositeGain,  imtAasEirpGrid.
%
%   Source: ITU-R WP5D R23 7.125-8.4 GHz IMT macro AAS table (Extended AAS
%   Model). All values come from the AAS-01 task description and match the
%   repo's existing imt_r23_aas_defaults.
%
%   Field map (units in [] where relevant):
%       elementGainDbi              single-element max gain G_E,max [dBi]
%       hBeamwidthDeg               horizontal 3 dB beamwidth phi_3dB [deg]
%       vBeamwidthDeg               vertical   3 dB beamwidth theta_3dB [deg]
%       frontToBackDb               front-to-back ratio A_m [dB]
%       sideLobeAttenuationDb       side-lobe attenuation SLA_nu [dB]
%       polarization                polarization tag (string)
%       numColumns                  N_H, horizontal columns
%       numRows                     N_V, vertical sub-arrays (rows)
%       hSpacingWavelengths         d_H, horizontal spacing [lambda]
%       vSubarraySpacingWavelengths d_V, vertical sub-array spacing [lambda]
%       numElementsPerSubarray      L,  vertical elements per sub-array
%       elementSpacingWavelengths   d_sub, intra-sub-array spacing [lambda]
%       subarrayDowntiltDeg         fixed sub-array electrical downtilt [deg]
%       mechanicalDowntiltDeg       mechanical downtilt of the panel [deg]
%       hCoverageDeg                horizontal electronic coverage (+/- deg)
%       vCoverageDegGlobalMin       vertical coverage min (global theta) [deg]
%       vCoverageDegGlobalMax       vertical coverage max (global theta) [deg]
%       sectorEirpDbm               peak sector EIRP [dBm / 100 MHz]
%       bandwidthMHz                occupied bandwidth [MHz]
%       frequencyMHz                carrier frequency [MHz]
%       k                           M.2101 element-pattern multiplier (= 12)
%       rho                         array correlation level in [0, 1] (= 1)
%
%   Notes:
%   * The vertical coverage is given in the M.2101 global-theta convention
%     where theta = 90 deg is the horizon and theta = 100 deg is 10 deg
%     below the horizon. In the (az, el) MVP convention used here, that
%     corresponds to elevation in [-10, 0] deg.
%   * The 6.4 dBi element gain already absorbs the R23 reference 2 dB ohmic
%     / array loss, so no additional loss term is applied downstream
%     (matching imt_r23_aas_defaults).

    params = struct();

    % ---- single-element / per-polarization (M.2101 Table 4) -----------
    params.elementGainDbi              = 6.4;
    params.hBeamwidthDeg               = 90;
    params.vBeamwidthDeg               = 65;
    params.frontToBackDb               = 30;
    params.sideLobeAttenuationDb       = 30;
    params.polarization                = 'linear_pm45';

    % ---- 8 x 16 sub-array layout (rows x columns) ---------------------
    params.numColumns                  = 16;   % N_H
    params.numRows                     = 8;    % N_V
    params.hSpacingWavelengths         = 0.5;  % d_H
    params.vSubarraySpacingWavelengths = 2.1;  % d_V

    % ---- vertical sub-array (within each panel cell) ------------------
    params.numElementsPerSubarray      = 3;    % L
    params.elementSpacingWavelengths   = 0.7;  % d_sub
    params.subarrayDowntiltDeg         = 3;    % fixed electrical downtilt

    % ---- panel mechanical mounting ------------------------------------
    params.mechanicalDowntiltDeg       = 6;

    % ---- coverage envelope --------------------------------------------
    params.hCoverageDeg                = 60;       % +/- deg
    params.vCoverageDegGlobalMin       = 90;       % global theta horizon
    params.vCoverageDegGlobalMax       = 100;      % global theta 10 deg below

    % ---- band / EIRP --------------------------------------------------
    params.sectorEirpDbm               = 78.3;     % per 100 MHz
    params.bandwidthMHz                = 100;
    params.frequencyMHz                = 8000;

    % ---- M.2101 recombination knobs -----------------------------------
    params.k   = 12;
    params.rho = 1;
end
