function figHandle = plotImtAasEirpGrid(azGridDeg, elGridDeg, eirpGridDbm)
%PLOTIMTAASEIRPGRID Heatmap of AAS EIRP over azimuth / elevation.
%
%   FIGHANDLE = plotImtAasEirpGrid(AZGRIDDEG, ELGRIDDEG, EIRPGRIDDBM)
%
%   Plots EIRP_dBm versus azimuth and elevation as a 2-D heatmap and
%   returns the figure handle.
%
%   AZGRIDDEG and ELGRIDDEG must be the vectors used to build EIRPGRIDDBM
%   under the ndgrid convention used by imtAasEirpGrid: EIRPGRIDDBM is an
%   Naz x Nel array where row i corresponds to AZGRIDDEG(i) and column j
%   corresponds to ELGRIDDEG(j).
%
%   The heatmap uses elevation on the x-axis and azimuth on the y-axis so
%   that "right = beam pointing direction (downtilt)" reads naturally.

    if ~isvector(azGridDeg) || ~isvector(elGridDeg)
        error('plotImtAasEirpGrid:badGrid', ...
            'azGridDeg and elGridDeg must be vectors.');
    end
    az = double(azGridDeg(:).');
    el = double(elGridDeg(:).');
    Naz = numel(az);
    Nel = numel(el);

    if ~isequal(size(eirpGridDbm), [Naz, Nel])
        error('plotImtAasEirpGrid:sizeMismatch', ...
            ['eirpGridDbm size %s does not match [numel(azGridDeg), ' ...
             'numel(elGridDeg)] = [%d %d].'], ...
            mat2str(size(eirpGridDbm)), Naz, Nel);
    end

    figHandle = figure('Name', 'IMT AAS EIRP grid', 'Color', 'w');
    imagesc(el, az, eirpGridDbm);
    set(gca, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title('IMT AAS sector EIRP [dBm / 100 MHz]');
    cb = colorbar;
    ylabel(cb, 'EIRP [dBm / 100 MHz]');
    axis tight;
end
