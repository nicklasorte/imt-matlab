function params = get_r23_aas_params()
%GET_R23_AAS_PARAMS R23 7.125-8.4 GHz Extended AAS antenna parameters.
%
%   PARAMS = get_r23_aas_params()
%
%   Returns the R23 / WP5D 7.125-8.4 GHz macro Extended AAS parameter
%   struct used by the single-sector EIRP CDF-grid MVP. This is a thin
%   wrapper around imtAasDefaultParams() that pins the values quoted in
%   the AAS-01 task description so the snake_case API can be used end-to-
%   end without touching imtAas* directly:
%
%       array (rows x columns) ............ 8 x 16
%       single-element gain ................ 6.4 dBi (incl. 2 dB ohmic)
%       horizontal 3 dB beamwidth .......... 90 deg
%       vertical   3 dB beamwidth .......... 65 deg
%       front-to-back / side-lobe atten. ... 30 dB
%       horizontal sub-array spacing ....... 0.5 lambda
%       vertical   sub-array spacing ....... 2.1 lambda
%       elements per vertical sub-array .... 3
%       intra-sub-array element spacing .... 0.7 lambda
%       fixed sub-array electrical downtilt  3 deg
%       mechanical downtilt ................ 6 deg
%       horizontal coverage ................ +/- 60 deg
%       vertical coverage (global theta) ... 90..100 deg
%       sector peak EIRP ................... 78.3 dBm / 100 MHz
%       conducted BS power ................. 46.1 dBm / 100 MHz
%       peak composite gain ................ 32.2 dBi
%
%   The PARAMS struct is also accepted directly by imtAasElementPattern,
%   imtAasArrayFactor, imtAasCompositeGain and imtAasEirpGrid.
%
%   Override:
%     params = get_r23_aas_params();
%     params.mechanicalDowntiltDeg = 8;   % example override

    params = imtAasDefaultParams();
end
