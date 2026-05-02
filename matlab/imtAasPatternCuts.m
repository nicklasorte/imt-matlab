function cuts = imtAasPatternCuts(azGridDeg, elGridDeg, eirpGridDbm, ...
        steerAzDeg, steerElDeg)
%IMTAASPATTERNCUTS Extract 1-D horizontal / vertical cuts from an EIRP grid.
%
%   CUTS = imtAasPatternCuts(AZGRIDDEG, ELGRIDDEG, EIRPGRIDDBM, ...
%                            STEERAZDEG, STEERELDEG)
%
%   Pulls reusable 1-D cuts and peak summary out of a 2-D AAS EIRP grid
%   produced by imtAasEirpGrid. Uses nearest-grid-point extraction (no
%   interpolation in this slice), which keeps the cuts deterministic and
%   directly comparable to the underlying grid.
%
%   Inputs:
%       azGridDeg     vector, azimuth grid [deg], 0 = sector boresight.
%       elGridDeg     vector, elevation grid [deg], 0 = horizon.
%       eirpGridDbm   matrix, size [numel(azGridDeg), numel(elGridDeg)],
%                     EIRP per direction in dBm / 100 MHz, as returned by
%                     imtAasEirpGrid (Naz x Nel ndgrid layout).
%       steerAzDeg    scalar, electronic steering azimuth [deg].
%       steerElDeg    scalar, electronic steering elevation [deg].
%
%   Output struct:
%       cuts.azGridDeg                 input azimuth grid (row vector)
%       cuts.elGridDeg                 input elevation grid (row vector)
%       cuts.steerAzDeg                input steering azimuth
%       cuts.steerElDeg                input steering elevation
%       cuts.horizontalCutAtSteerElDbm horizontal EIRP cut at the elevation
%                                      nearest to steerElDeg, length Naz
%       cuts.horizontalCutElevationDeg actual elevation [deg] used for the
%                                      horizontal cut (nearest grid point)
%       cuts.verticalCutAtSteerAzDbm   vertical EIRP cut at the azimuth
%                                      nearest to steerAzDeg, length Nel
%       cuts.verticalCutAzimuthDeg     actual azimuth [deg] used for the
%                                      vertical cut (nearest grid point)
%       cuts.azIndex                   index into azGridDeg used for the
%                                      vertical cut (nearest to steerAz)
%       cuts.elIndex                   index into elGridDeg used for the
%                                      horizontal cut (nearest to steerEl)
%       cuts.peakEirpDbm               max(eirpGridDbm(:))
%       cuts.peakAzDeg                 azimuth of peak grid cell [deg]
%       cuts.peakElDeg                 elevation of peak grid cell [deg]
%
%   See also imtAasEirpGrid, plotImtAasPatternCuts,
%   imtAasExportEirpGridCsv.

    if nargin < 5
        error('imtAasPatternCuts:notEnoughInputs', ...
            ['imtAasPatternCuts requires 5 inputs: ', ...
             'azGridDeg, elGridDeg, eirpGridDbm, steerAzDeg, steerElDeg.']);
    end

    % ---- validate vectors ---------------------------------------------
    if ~isnumeric(azGridDeg) || ~isreal(azGridDeg) || ~isvector(azGridDeg) ...
            || isempty(azGridDeg)
        error('imtAasPatternCuts:invalidGrid', ...
            'azGridDeg must be a non-empty real numeric vector.');
    end
    if ~isnumeric(elGridDeg) || ~isreal(elGridDeg) || ~isvector(elGridDeg) ...
            || isempty(elGridDeg)
        error('imtAasPatternCuts:invalidGrid', ...
            'elGridDeg must be a non-empty real numeric vector.');
    end
    if any(~isfinite(azGridDeg(:))) || any(~isfinite(elGridDeg(:)))
        error('imtAasPatternCuts:invalidGrid', ...
            'azGridDeg / elGridDeg contain NaN or Inf.');
    end

    azVec = double(azGridDeg(:).');
    elVec = double(elGridDeg(:).');
    Naz   = numel(azVec);
    Nel   = numel(elVec);

    % ---- validate EIRP grid shape -------------------------------------
    if ~isnumeric(eirpGridDbm) || ~isreal(eirpGridDbm)
        error('imtAasPatternCuts:invalidEirpGrid', ...
            'eirpGridDbm must be a real numeric matrix.');
    end
    if ndims(eirpGridDbm) > 2 %#ok<ISMAT>
        error('imtAasPatternCuts:invalidEirpGrid', ...
            'eirpGridDbm must be a 2-D matrix.');
    end
    if ~isequal(size(eirpGridDbm), [Naz, Nel])
        error('imtAasPatternCuts:gridSizeMismatch', ...
            ['eirpGridDbm size %s does not match ', ...
             '[numel(azGridDeg), numel(elGridDeg)] = [%d %d].'], ...
            mat2str(size(eirpGridDbm)), Naz, Nel);
    end
    %   Note: -Inf is a legitimate value (deep array-factor nulls in dB),
    %   so only NaN is treated as a defect here.
    if any(isnan(eirpGridDbm(:)))
        error('imtAasPatternCuts:invalidEirpGrid', ...
            'eirpGridDbm contains NaN values.');
    end

    % ---- validate steering scalars ------------------------------------
    validateScalar(steerAzDeg, 'steerAzDeg');
    validateScalar(steerElDeg, 'steerElDeg');
    steerAz = double(steerAzDeg);
    steerEl = double(steerElDeg);

    % ---- nearest-grid-point indices for the steering angles ----------
    [~, azIdx] = min(abs(azVec - steerAz));
    [~, elIdx] = min(abs(elVec - steerEl));

    horizontalCut = eirpGridDbm(:, elIdx);
    verticalCut   = eirpGridDbm(azIdx, :);

    % ---- peak location -----------------------------------------------
    [peakVal, linIdx] = max(eirpGridDbm(:));
    [peakAzIdx, peakElIdx] = ind2sub([Naz, Nel], linIdx);

    % ---- assemble result ---------------------------------------------
    cuts = struct();
    cuts.azGridDeg                 = azVec;
    cuts.elGridDeg                 = elVec;
    cuts.steerAzDeg                = steerAz;
    cuts.steerElDeg                = steerEl;
    cuts.horizontalCutAtSteerElDbm = horizontalCut(:).';
    cuts.horizontalCutElevationDeg = elVec(elIdx);
    cuts.verticalCutAtSteerAzDbm   = verticalCut(:).';
    cuts.verticalCutAzimuthDeg     = azVec(azIdx);
    cuts.azIndex                   = azIdx;
    cuts.elIndex                   = elIdx;
    cuts.peakEirpDbm               = peakVal;
    cuts.peakAzDeg                 = azVec(peakAzIdx);
    cuts.peakElDeg                 = elVec(peakElIdx);
end

% =====================================================================

function validateScalar(value, name)
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('imtAasPatternCuts:invalidSteer', ...
            '%s must be a real finite scalar.', name);
    end
end
