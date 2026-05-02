function out = imtAasCreateDefaultSectorEirpGrid(Nues, deployment, opts)
%IMTAASCREATEDEFAULTSECTOREIRPGRID End-to-end helper for a UE-driven sector EIRP grid.
%
%   OUT = imtAasCreateDefaultSectorEirpGrid()
%   OUT = imtAasCreateDefaultSectorEirpGrid(NUES)
%   OUT = imtAasCreateDefaultSectorEirpGrid(NUES, DEPLOYMENT)
%   OUT = imtAasCreateDefaultSectorEirpGrid(NUES, DEPLOYMENT, OPTS)
%
%   Convenience wrapper around the UE-driven sector EIRP pipeline:
%
%       params = imtAasDefaultParams();
%       sector = imtAasSingleSectorParams(deployment, params);
%       beams  = imtAasGenerateBeamSet(Nues, sector, opts);
%       out    = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
%                                              beams, params, opts);
%
%   Defaults:
%       NUES        params.numUesPerSector  (3)
%       DEPLOYMENT  'macroUrban'
%       azGridDeg   -180:1:180
%       elGridDeg    -90:1:90
%       seed         1
%
%   OPTS may override:
%       .azGridDeg
%       .elGridDeg
%       .seed
%       .splitSectorPower
%   plus any field accepted by imtAasGenerateBeamSet or
%   imtAasSectorEirpGridFromBeams.
%
%   Output: same fields as imtAasSectorEirpGridFromBeams, plus:
%       out.sector  the imtAasSingleSectorParams sector struct
%       out.ue      ue struct (passthrough from imtAasGenerateBeamSet)
%
%   Antenna-face EIRP only - no path loss, receiver gain, or I/N.
%
%   See also: imtAasSectorEirpGridFromBeams, imtAasGenerateBeamSet,
%             imtAasSingleSectorParams, imtAasDefaultParams.

    params = imtAasDefaultParams();

    if nargin < 1 || isempty(Nues)
        Nues = params.numUesPerSector;
    end
    if nargin < 2 || isempty(deployment)
        deployment = 'macroUrban';
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('imtAasCreateDefaultSectorEirpGrid:invalidOpts', ...
            'OPTS must be a struct (or [] for defaults).');
    end

    sector = imtAasSingleSectorParams(deployment, params);

    beamOpts = opts;
    if ~(isfield(beamOpts, 'seed') && ~isempty(beamOpts.seed))
        beamOpts.seed = 1;
    end
    beams = imtAasGenerateBeamSet(Nues, sector, beamOpts);

    if isfield(opts, 'azGridDeg') && ~isempty(opts.azGridDeg)
        azGridDeg = opts.azGridDeg;
    else
        azGridDeg = -180:1:180;
    end
    if isfield(opts, 'elGridDeg') && ~isempty(opts.elGridDeg)
        elGridDeg = opts.elGridDeg;
    else
        elGridDeg = -90:1:90;
    end

    out = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beams, params, opts);

    out.sector = sector;
    out.ue     = beams.ue;
end
