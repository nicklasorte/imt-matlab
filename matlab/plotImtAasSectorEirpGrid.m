function figs = plotImtAasSectorEirpGrid(out)
%PLOTIMTAASSECTOREIRPGRID Heatmaps for a UE-driven sector EIRP grid.
%
%   FIGS = plotImtAasSectorEirpGrid(OUT)
%
%   OUT is the struct returned by imtAasSectorEirpGridFromBeams (or by
%   imtAasCreateDefaultSectorEirpGrid). The function produces:
%
%       figs.aggregate     heatmap of out.aggregateEirpDbm
%       figs.envelope      heatmap of out.maxEnvelopeEirpDbm
%       figs.perBeam       1xK array of figure handles for the first K
%                          per-beam heatmaps (K = min(3, out.numBeams));
%                          empty when out.perBeamEirpDbm is missing.
%
%   Every title carries the explicit reminder
%       "Antenna-face EIRP only - no path loss"
%   so figures are not mistaken for received power.
%
%   See also imtAasSectorEirpGridFromBeams, plotImtAasEirpGrid.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotImtAasSectorEirpGrid:invalidOut', ...
            'OUT must be the struct returned by imtAasSectorEirpGridFromBeams.');
    end
    requiredFields = {'azGridDeg', 'elGridDeg', ...
        'aggregateEirpDbm', 'maxEnvelopeEirpDbm', 'numBeams'};
    for i = 1:numel(requiredFields)
        if ~isfield(out, requiredFields{i})
            error('plotImtAasSectorEirpGrid:missingField', ...
                'OUT is missing field "%s".', requiredFields{i});
        end
    end

    az = double(out.azGridDeg(:).');
    el = double(out.elGridDeg(:).');

    figs = struct();

    figs.aggregate = renderHeatmap(az, el, out.aggregateEirpDbm, ...
        sprintf(['Sector aggregate EIRP (numBeams = %d, peak %.2f ' ...
                 'dBm/100MHz)\nAntenna-face EIRP only - no path loss'], ...
                out.numBeams, max(out.aggregateEirpDbm(:))));

    figs.envelope = renderHeatmap(az, el, out.maxEnvelopeEirpDbm, ...
        sprintf(['Sector envelope EIRP (max over beams, peak %.2f ' ...
                 'dBm/100MHz)\nAntenna-face EIRP only - no path loss'], ...
                max(out.maxEnvelopeEirpDbm(:))));

    figs.perBeam = [];
    if isfield(out, 'perBeamEirpDbm') && ~isempty(out.perBeamEirpDbm)
        K = min(3, out.numBeams);
        beamFigs = cell(1, K);
        for k = 1:K
            steerAz = NaN; steerEl = NaN;
            if isfield(out, 'beams')
                if isfield(out.beams, 'steerAzDeg')
                    steerAz = out.beams.steerAzDeg(k);
                end
                if isfield(out.beams, 'steerElDeg')
                    steerEl = out.beams.steerElDeg(k);
                end
            end
            beamFigs{k} = renderHeatmap(az, el, ...
                out.perBeamEirpDbm(:, :, k), ...
                sprintf(['Per-beam EIRP %d / %d  (steer az=%.2f, ' ...
                         'el=%.2f deg, peak %.2f dBm/100MHz)\n' ...
                         'Antenna-face EIRP only - no path loss'], ...
                        k, out.numBeams, steerAz, steerEl, ...
                        max(reshape(out.perBeamEirpDbm(:, :, k), [], 1))));
        end
        figs.perBeam = beamFigs;
    end
end

% =====================================================================

function fig = renderHeatmap(az, el, grid, titleText)
    fig = figure('Name', 'IMT AAS sector EIRP grid', 'Color', 'w');
    imagesc(el, az, grid);
    set(gca, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title(titleText);
    cb = colorbar;
    ylabel(cb, 'EIRP [dBm / 100 MHz]');
    axis tight;
end
