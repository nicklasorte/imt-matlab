function out = runSingleSectorEirpDemoExample()
%RUNSINGLESECTOREIRPDEMOEXAMPLE Example wrapper for the R23 single-sector demo.
%
%   OUT = runSingleSectorEirpDemoExample()
%
%   Runs run_single_sector_eirp_demo with a small MC count and a coarse
%   grid, writes a P95 PNG and percentile CSV under examples/output/, and
%   returns the demo OUT struct.
%
%   Example outputs:
%       examples/output/single_sector_eirp_p95.png
%       examples/output/single_sector_eirp_pcts.csv

    here    = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    opts = struct();
    opts.numSnapshots = 50;
    opts.numUes       = 3;
    opts.seed         = 1;
    opts.gridPoints   = struct('azGridDeg', -90:5:90, 'elGridDeg', -30:5:10);
    opts.savePlot     = true;
    opts.saveCsv      = true;
    opts.plotPath     = fullfile(outDir, 'single_sector_eirp_p95.png');
    opts.csvPath      = fullfile(outDir, 'single_sector_eirp_pcts.csv');
    opts.show         = false;
    opts.verbose      = true;

    out = run_single_sector_eirp_demo(opts);
end
