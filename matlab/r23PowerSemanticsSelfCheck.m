function ps = r23PowerSemanticsSelfCheck(observedMax_dBm, ...
        sectorEirpDbm, perBeamPeakEirpDbm, splitSectorPower, varargin)
%R23POWERSEMANTICSSELFCHECK EIRP normalization / double-counting guard.
%
%   PS = r23PowerSemanticsSelfCheck(OBSERVEDMAX_dBM, SECTOREIRPDBM, ...
%                                   PERBEAMPEAKEIRPDBM, SPLITSECTORPOWER)
%   PS = r23PowerSemanticsSelfCheck(..., 'Tolerance_dB', 1e-6, ...
%                                        'WarnShortfall_dB', 3.0)
%
%   Compares the maximum observed grid EIRP to the expected sector /
%   per-beam peak EIRP and returns a structured self-check report.
%
%   Inputs:
%       OBSERVEDMAX_dBM       max(stats.max_dBm) across (az, el) cells
%                             over all Monte Carlo draws [dBm]
%       SECTOREIRPDBM         the SECTOR peak EIRP budget [dBm]
%                             (= maxEirpPerSector_dBm)
%       PERBEAMPEAKEIRPDBM    expected per-beam peak EIRP [dBm], i.e.
%                             sectorEirpDbm - 10*log10(numBeams) when
%                             splitSectorPower=true, else sectorEirpDbm
%       SPLITSECTORPOWER      logical flag controlling per-beam split
%
%   Optional name-value:
%       'Tolerance_dB'        numeric slack on the hard-fail comparison
%                             (default 1e-6 dB)
%       'WarnShortfall_dB'    threshold below which a soft-warn fires
%                             (default 3.0 dB)
%
%   Output PS struct:
%       .expectedSectorPeakEirp_dBm   sector peak EIRP budget
%       .expectedPerBeamPeakEirp_dBm  expected per-beam peak EIRP
%       .observedMaxGridEirp_dBm      observed grid max EIRP
%       .peakShortfall_dB             expected per-beam peak minus observed
%       .tolerance_dB                 hard-fail tolerance
%       .warnShortfallThreshold_dB   soft-warn threshold
%       .splitSectorPower             input flag echoed
%       .status                       'pass' | 'warn' | 'fail'
%       .message                      human-readable summary
%
%   Decision rules:
%       fail : observed > sector peak EIRP budget + tolerance_dB
%              (this would mean power double-counting / aggregation /
%              normalization error)
%       warn : peakShortfall_dB > WarnShortfall_dB
%              (informational only -- coarse grids, random steering,
%              or beam splitting may prevent the sampled grid from
%              landing on the beam peak)
%       pass : otherwise
%
%   See also: runR23AasEirpCdfGrid, r23ScenarioPreset.

    tolerance_dB     = 1e-6;
    warnShortfall_dB = 3.0;
    if ~isempty(varargin)
        if mod(numel(varargin), 2) ~= 0
            error('r23PowerSemanticsSelfCheck:badArgs', ...
                'Optional arguments must be Name, Value pairs.');
        end
        for k = 1:2:numel(varargin)
            name = varargin{k};
            if isstring(name) && isscalar(name); name = char(name); end
            value = varargin{k+1};
            switch lower(name)
                case 'tolerance_db'
                    tolerance_dB = double(value);
                case 'warnshortfall_db'
                    warnShortfall_dB = double(value);
                otherwise
                    error('r23PowerSemanticsSelfCheck:badArgs', ...
                        'Unknown option "%s".', name);
            end
        end
    end

    expectedSectorPeak_dBm  = double(sectorEirpDbm);
    expectedPerBeamPeak_dBm = double(perBeamPeakEirpDbm);
    observedMax_dBm         = double(observedMax_dBm);

    if splitSectorPower
        peakShortfall_dB = expectedPerBeamPeak_dBm - observedMax_dBm;
    else
        peakShortfall_dB = expectedSectorPeak_dBm - observedMax_dBm;
    end

    excess_dB = observedMax_dBm - expectedSectorPeak_dBm;

    if isfinite(observedMax_dBm) && excess_dB > tolerance_dB
        status  = 'fail';
        message = sprintf( ...
            ['power self-check FAIL: observedMaxGridEirp_dBm=%.4f ' ...
             'exceeds sector peak %.4f dBm by %.4f dB (tolerance ' ...
             '%.4g dB). This indicates power double-counting / ' ...
             'aggregation / normalization error.'], ...
            observedMax_dBm, expectedSectorPeak_dBm, ...
            excess_dB, tolerance_dB);
    elseif isfinite(observedMax_dBm) && peakShortfall_dB > warnShortfall_dB
        status  = 'warn';
        message = sprintf( ...
            ['power self-check WARN: observedMaxGridEirp_dBm=%.4f ' ...
             'is %.4f dB below expected per-beam peak %.4f dBm. ' ...
             'Coarse grids, random steering, or beam splitting may ' ...
             'prevent the sampled grid from landing on the beam ' ...
             'peak; this is informational only.'], ...
            observedMax_dBm, peakShortfall_dB, ...
            expectedPerBeamPeak_dBm);
    else
        status  = 'pass';
        message = sprintf( ...
            ['power self-check pass: observedMaxGridEirp_dBm=%.4f, ' ...
             'expectedPerBeamPeakEirp_dBm=%.4f, ' ...
             'expectedSectorPeakEirp_dBm=%.4f.'], ...
            observedMax_dBm, expectedPerBeamPeak_dBm, ...
            expectedSectorPeak_dBm);
    end

    ps = struct();
    ps.expectedSectorPeakEirp_dBm  = expectedSectorPeak_dBm;
    ps.expectedPerBeamPeakEirp_dBm = expectedPerBeamPeak_dBm;
    ps.observedMaxGridEirp_dBm     = observedMax_dBm;
    ps.peakShortfall_dB            = peakShortfall_dB;
    ps.tolerance_dB                = tolerance_dB;
    ps.warnShortfallThreshold_dB   = warnShortfall_dB;
    ps.splitSectorPower            = logical(splitSectorPower);
    ps.status                      = status;
    ps.message                     = message;
end
