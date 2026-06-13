function h = imtAasPointingHistogram(steerAzDeg, steerElDeg, azEdgesDeg, elEdgesDeg)
%IMTAASPOINTINGHISTOGRAM Joint (azimuth, elevation) pointing-angle histogram.
%
%   H = imtAasPointingHistogram(STEERAZDEG, STEERELDEG, AZEDGESDEG, ELEDGESDEG)
%
%   Bins a set of applied beam steering directions into a joint 2-D
%   histogram over (steering azimuth, steering elevation). This is the
%   single, unit-tested binning path that the R23 AAS CDF-grid runner
%   (runR23AasEirpCdfGrid) accumulates per snapshot to build the
%   pointing-angle PMF (out.pointingHistogram). It is a pure function:
%   no globals, no figures, no RNG.
%
%   Inputs:
%       STEERAZDEG  equal-length vector of steering azimuths [deg],
%                   measured relative to the sector boresight.
%       STEERELDEG  equal-length vector of steering elevations [deg],
%                   with 0 = horizon (negative = below horizon / downtilt).
%       AZEDGESDEG  monotonically increasing azimuth bin edges [deg].
%       ELEDGESDEG  monotonically increasing elevation bin edges [deg].
%
%   Output struct H:
%       .counts        [nAzBin x nElBin] = histcounts2(az, el, azEdges,
%                      elEdges). Azimuth indexes the ROWS and elevation
%                      the COLUMNS, matching the az=rows / el=cols
%                      orientation of the existing pointing / EIRP / gain
%                      heatmaps.
%       .numInRange    sum(counts(:)) -- samples that landed in a bin.
%       .numOutOfRange count of samples that fell OUTSIDE the edge
%                      rectangle [azEdges(1),azEdges(end)] x
%                      [elEdges(1),elEdges(end)] (the samples histcounts2
%                      silently drops). numInRange + numOutOfRange always
%                      equals numel(steerAzDeg), so undercounting is
%                      visible rather than hidden -- relevant when
%                      clampElevation is off and elevations steer well
%                      below the default lower edge.
%
%   See also: runR23AasEirpCdfGrid, plotR23AasPointingHistogram,
%             histcounts2.

    az = double(steerAzDeg(:));
    el = double(steerElDeg(:));
    if numel(az) ~= numel(el)
        error('imtAasPointingHistogram:lengthMismatch', ...
            ['steerAzDeg (%d) and steerElDeg (%d) must be equal-length ' ...
             'vectors.'], numel(az), numel(el));
    end

    azEdges = double(azEdgesDeg(:).');
    elEdges = double(elEdgesDeg(:).');
    if numel(azEdges) < 2 || numel(elEdges) < 2
        error('imtAasPointingHistogram:badEdges', ...
            'azEdgesDeg and elEdgesDeg must each have at least two edges.');
    end

    % az = rows, el = cols (histcounts2 returns [numel(azEdges)-1 x
    % numel(elEdges)-1]). Out-of-range samples are silently dropped here;
    % they are recovered below so the running total is conserved.
    counts = histcounts2(az, el, azEdges, elEdges);

    h = struct();
    h.counts        = counts;
    h.numInRange    = sum(counts(:));
    % numel - numInRange == count outside the edge rectangle (and folds in
    % any NaN samples), guaranteeing numInRange + numOutOfRange == numel.
    h.numOutOfRange = numel(az) - h.numInRange;
end
