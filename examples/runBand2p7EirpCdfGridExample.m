%RUNBAND2P7EIRPCDFGRIDEXAMPLE 2.7 GHz band option: EIRP CDF-grid example.
%
%   Runs the 2.7 GHz macro case (ITU 1 710-4 990 MHz 4x8 AAS, Part 27
%   power of 65 dBm/MHz = 85 dBm / 100 MHz, 2750 MHz TDD, ITU 2-3 GHz BS
%   height and cell radius) on a small grid and prints the key numbers.
%
%   Run from the repo root:
%       addpath('matlab'); run(fullfile('examples', 'runBand2p7EirpCdfGridExample.m'))

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'matlab'));

opts = struct();
opts.band        = '2p7ghz';
opts.environment = 'urban';
opts.numMc       = 200;
opts.seed        = 1;
opts.azGridDeg   = -60:2:60;
opts.elGridDeg   = -20:1:10;
opts.percentiles = [5 50 95 99];
opts.subband     = struct('subbandMHz', 1);   % narrowband density (Part 27 check)

result = runR23AasEirpCdfGrid(opts);
md = result.metadata;

fprintf('Band:               %s (%s)\n', md.band, md.bandLabel);
fprintf('Geometry preset:    %s (%d x %d, %.2f dBi)\n', md.aasGeometryPreset, ...
    md.numRows, md.numColumns, md.aasGeometry.calculatedAntennaGainDbi);
fprintf('Frequency:          %g MHz, %g MHz channel, %s\n', md.frequencyMHz, ...
    md.bandwidthMHz, md.duplex);
fprintf('Sector peak EIRP:   %.2f dBm / %g MHz (%.2f dBm/MHz; %s)\n', ...
    md.sectorEirpDbm, md.bandwidthMHz, md.peakEirpDensity_dBmPerMHz, md.powerBasis);
fprintf('BS height / radius: %g m / %g m\n', md.bsHeight_m, md.cellRadius_m);
fprintf('Observed max EIRP:  %.2f dBm (self-check: %s)\n', ...
    max(result.stats.max_dBm(:)), result.selfCheck.powerSemantics.status);
fprintf('Per-subband peak:   %.2f dBm/MHz\n', result.subband.perSubbandPeak_dBmPerMHz);
