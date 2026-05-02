function figs = plotImtAasPatternCuts(cuts)
%PLOTIMTAASPATTERNCUTS Plot horizontal and vertical EIRP pattern cuts.
%
%   FIGS = plotImtAasPatternCuts(CUTS)
%
%   Produces two figures from the struct returned by imtAasPatternCuts:
%
%     figs.horizontal  EIRP vs azimuth at the steering elevation
%                      (horizontalCutAtSteerElDbm vs azGridDeg)
%     figs.vertical    EIRP vs elevation at the steering azimuth
%                      (verticalCutAtSteerAzDbm vs elGridDeg)
%
%   The horizontal-cut x-axis is labelled "Azimuth relative to sector
%   boresight (deg)"; the vertical-cut x-axis is labelled "Elevation
%   relative to horizon (deg)". A vertical reference line marks the
%   steering angle and a marker is placed at the peak of each cut.
%
%   Inputs:
%       cuts  struct from imtAasPatternCuts. Required fields:
%             azGridDeg, elGridDeg, steerAzDeg, steerElDeg,
%             horizontalCutAtSteerElDbm, horizontalCutElevationDeg,
%             verticalCutAtSteerAzDbm, verticalCutAzimuthDeg,
%             peakEirpDbm.
%
%   Output:
%       figs  struct with two fields:
%             figs.horizontal  figure handle for the horizontal cut
%             figs.vertical    figure handle for the vertical cut
%
%   See also imtAasPatternCuts, plotImtAasEirpGrid.

    if nargin < 1 || ~isstruct(cuts) || ~isscalar(cuts)
        error('plotImtAasPatternCuts:invalidInput', ...
            'cuts must be a scalar struct returned by imtAasPatternCuts.');
    end
    requiredFields = {'azGridDeg', 'elGridDeg', ...
                      'steerAzDeg', 'steerElDeg', ...
                      'horizontalCutAtSteerElDbm', ...
                      'horizontalCutElevationDeg', ...
                      'verticalCutAtSteerAzDbm', ...
                      'verticalCutAzimuthDeg', ...
                      'peakEirpDbm'};
    for i = 1:numel(requiredFields)
        if ~isfield(cuts, requiredFields{i})
            error('plotImtAasPatternCuts:missingField', ...
                'cuts struct missing required field "%s".', ...
                requiredFields{i});
        end
    end

    az  = cuts.azGridDeg(:).';
    el  = cuts.elGridDeg(:).';
    yAz = cuts.horizontalCutAtSteerElDbm(:).';
    yEl = cuts.verticalCutAtSteerAzDbm(:).';

    if numel(yAz) ~= numel(az)
        error('plotImtAasPatternCuts:sizeMismatch', ...
            ['horizontalCutAtSteerElDbm length %d does not match ', ...
             'azGridDeg length %d.'], numel(yAz), numel(az));
    end
    if numel(yEl) ~= numel(el)
        error('plotImtAasPatternCuts:sizeMismatch', ...
            ['verticalCutAtSteerAzDbm length %d does not match ', ...
             'elGridDeg length %d.'], numel(yEl), numel(el));
    end

    % ---- horizontal cut ----------------------------------------------
    figs.horizontal = figure('Name', 'IMT AAS EIRP - horizontal cut', ...
                             'Color', 'w');
    plot(az, yAz, 'b-', 'LineWidth', 1.25);
    hold on;
    [yPeak, iPeak] = max(yAz);
    plot(az(iPeak), yPeak, 'ro', 'MarkerSize', 8, ...
         'MarkerFaceColor', 'r');
    yl = ylim;
    plot([cuts.steerAzDeg, cuts.steerAzDeg], yl, 'k--', 'LineWidth', 1);
    hold off;
    grid on;
    xlabel('Azimuth relative to sector boresight (deg)');
    ylabel('EIRP (dBm/100 MHz)');
    title(sprintf( ...
        'Horizontal cut at elevation = %.2f deg (steer az = %.2f, peak %.2f dBm)', ...
        cuts.horizontalCutElevationDeg, cuts.steerAzDeg, yPeak));
    legend({'EIRP cut', 'Cut peak', 'Steer azimuth'}, 'Location', 'best');

    % ---- vertical cut ------------------------------------------------
    figs.vertical = figure('Name', 'IMT AAS EIRP - vertical cut', ...
                           'Color', 'w');
    plot(el, yEl, 'b-', 'LineWidth', 1.25);
    hold on;
    [yPeakV, iPeakV] = max(yEl);
    plot(el(iPeakV), yPeakV, 'ro', 'MarkerSize', 8, ...
         'MarkerFaceColor', 'r');
    ylv = ylim;
    plot([cuts.steerElDeg, cuts.steerElDeg], ylv, 'k--', 'LineWidth', 1);
    hold off;
    grid on;
    xlabel('Elevation relative to horizon (deg)');
    ylabel('EIRP (dBm/100 MHz)');
    title(sprintf( ...
        'Vertical cut at azimuth = %.2f deg (steer el = %.2f, peak %.2f dBm)', ...
        cuts.verticalCutAzimuthDeg, cuts.steerElDeg, yPeakV));
    legend({'EIRP cut', 'Cut peak', 'Steer elevation'}, 'Location', 'best');
end
