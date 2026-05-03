function out = demo_r23_aas_eirp_grid()
%DEMO_R23_AAS_EIRP_GRID End-to-end demo of the R23 7/8 GHz AAS EIRP grid.
%
%   OUT = demo_r23_aas_eirp_grid()
%
%   Builds the R23 macro-urban AAS configuration, evaluates the
%   deterministic per-direction EIRP on an azimuth x elevation grid
%   covering the forward sector, and plots EIRP per 100 MHz over the
%   grid. Returns the struct produced by imt_r23_aas_eirp_grid.
%
%   The plot uses imagesc with axes (azimuth, elevation) so the
%   horizontal axis is azimuth and the vertical axis is elevation.

    cfg     = imt_r23_aas_defaults('macroUrban');
    azGrid  = -180:1:180;
    elGrid  =  -90:1:30;

    out = imt_r23_aas_eirp_grid(azGrid, elGrid, cfg);

    fprintf(['[demo_r23_aas_eirp_grid] %s : peak EIRP = %.3f dBm/100MHz ' ...
             '(target %.3f), peak gain = %.3f dBi (target %.3f)\n'], ...
        cfg.deployment, ...
        max(out.eirp_dBm_per100MHz(:)), cfg.sectorEirp_dBm_per100MHz, ...
        max(out.gain_dBi(:)),            cfg.peakGain_dBi);

    figure('Name', 'R23 7/8 GHz Extended AAS EIRP grid');
    imagesc(out.azGrid, out.elGrid, out.eirp_dBm_per100MHz.');
    set(gca, 'YDir', 'normal');
    xlabel('Azimuth [deg]');
    ylabel('Elevation [deg]');
    title(sprintf(['R23 macro AAS EIRP @ %g MHz, %g MHz BW ' ...
                   '(beam az=%g, el=%g deg)'], ...
        cfg.frequencyMHz, cfg.bandwidthMHz, ...
        out.beamAzimDeg, out.beamElevDeg));
    cb = colorbar;
    ylabel(cb, 'EIRP [dBm / 100 MHz]');
end
