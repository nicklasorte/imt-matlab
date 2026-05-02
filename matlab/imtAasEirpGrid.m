function eirpGridDbm = imtAasEirpGrid(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, sectorEirpDbm, params)
%IMTAASEIRPGRID Peak-normalized AAS sector EIRP distribution over az/el.
%
%   EIRPGRIDDBM = imtAasEirpGrid(AZGRIDDEG, ELGRIDDEG, ...
%                                STEERAZDEG, STEERELDEG, ...
%                                SECTOREIRPDBM, PARAMS)
%
%   Returns the EIRP radiated from the face of one IMT AAS sector antenna
%   in each direction of the (azGridDeg, elGridDeg) observation grid for an
%   electronic beam steered at (steerAzDeg, steerElDeg).
%
%   MVP normalization (peak-normalized form):
%       eirpGridDbm = sectorEirpDbm
%                     + compositeGainDbi
%                     - max(compositeGainDbi(:))
%
%   so that max(eirpGridDbm(:)) == sectorEirpDbm exactly. This avoids
%   double-counting conducted power vs. an already-stated sector EIRP and
%   makes the output directly testable. For the R23 default
%   sectorEirpDbm = 78.3 dBm / 100 MHz, the peak of the returned grid is
%   78.3 dBm / 100 MHz. (See imt_aas_bs_eirp.m for the alternative
%   conducted-power-plus-gain path used elsewhere in the repo.)
%
%   Inputs:
%       azGridDeg, elGridDeg   observation grid (see imtAasArrayFactor)
%       steerAzDeg, steerElDeg scalar electronic steering, sector frame
%       sectorEirpDbm          reference peak sector EIRP, dBm / 100 MHz.
%                              [] or omitted -> params.sectorEirpDbm.
%       params                 imtAasDefaultParams() struct (or override).
%
%   Output:
%       eirpGridDbm            EIRP per direction [dBm / 100 MHz], shape
%                              determined by imtAasNormalizeGrid.
%
%   Angle conventions (sector frame):
%       azimuth   in [-180, 180] deg, 0 = sector boresight
%       elevation in [ -90,  90] deg, 0 = horizon, negative = below
%   Mechanical downtilt is applied internally inside imtAasCompositeGain.

    if nargin < 6 || isempty(params)
        params = imtAasDefaultParams();
    end
    if nargin < 5 || isempty(sectorEirpDbm)
        sectorEirpDbm = params.sectorEirpDbm;
    end
    if ~(isnumeric(sectorEirpDbm) && isreal(sectorEirpDbm) && ...
            isscalar(sectorEirpDbm) && isfinite(sectorEirpDbm))
        error('imtAasEirpGrid:invalidSectorEirp', ...
            'sectorEirpDbm must be a real finite scalar [dBm].');
    end

    compositeDbi = imtAasCompositeGain(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params);

    peakDbi = max(compositeDbi(:));
    if ~isfinite(peakDbi)
        error('imtAasEirpGrid:nonFinitePeak', ...
            ['Composite gain peak is not finite. This usually means the ' ...
             'AAS parameters are inconsistent (check params).']);
    end

    eirpGridDbm = sectorEirpDbm + compositeDbi - peakDbi;
end
