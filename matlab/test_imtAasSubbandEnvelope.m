function results = test_imtAasSubbandEnvelope()
%TEST_IMTAASSUBBANDENVELOPE Self tests for the per-subband narrowband density helper.
%
%   RESULTS = test_imtAasSubbandEnvelope()
%
%   Covers imtAasSubbandEnvelope (pure, no RNG):
%       T1.  Peak density headline == sectorEirp - 10*log10(bandwidthMHz).
%       T2.  Density envelope == constant + gain envelope (single beam):
%            perSubbandDensityEnvelope == (sectorEirp - peakGain)
%            - 10*log10(BW) + maxEnvelopeGainDbi, within 1e-6 dB.
%       T3.  Single-beam reduction: the density envelope equals the
%            band-integrated aggregate grid (dBm) - 10*log10(BW), within
%            1e-6 dB (one beam at full EPRE IS the aggregate, as a density).
%       T4.  Validity bound flag: subbandMHz <= bandwidthMHz/N clears the
%            flag; subbandMHz > bandwidthMHz/N sets it.
%       T5.  Strict validation: bad subbandMHz (0, negative, > bandwidthMHz)
%            throws imtAasSubbandEnvelope:invalidSubbandMHz.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results.summary = {};
    results.passed  = true;

    p   = imtAasDefaultParams();
    BW  = double(p.bandwidthMHz);
    az  = -60:5:60;
    el  = -12:1:6;
    bandOff = 10 * log10(BW);

    % ---- T1: peak density headline ----------------------------------
    beams3 = struct('steerAzDeg', [-20; 5; 30], 'steerElDeg', [-9; -6; -3]);
    r3 = imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', 1));
    ok1 = abs(r3.perSubbandPeak_dBmPerMHz - (p.sectorEirpDbm - bandOff)) <= 1e-9;
    results = check(results, ok1, sprintf( ...
        'T1: perSubbandPeak == sectorEirp - 10log10(BW) (%.4f dBm/MHz)', ...
        r3.perSubbandPeak_dBmPerMHz));

    % ---- T2: density == constant + gain envelope (single beam) -------
    beam1 = struct('steerAzDeg', 10, 'steerElDeg', -9);
    r1 = imtAasSubbandEnvelope(az, el, beam1, p, struct('subbandMHz', 1));
    secG = imtAasSectorEirpGridFromBeams(az, el, beam1, p, ...
        struct('splitSectorPower', false, 'sectorEirpDbm', p.sectorEirpDbm, ...
               'computeGain', true));
    gainEnv  = secG.maxEnvelopeGainDbi;
    peakGain = max(gainEnv(:));
    expected = (p.sectorEirpDbm - peakGain) - bandOff + gainEnv;
    d2 = abs(r1.perSubbandDensityEnvelope_dBmPerMHz - expected);
    ok2 = isequal(size(r1.perSubbandDensityEnvelope_dBmPerMHz), size(gainEnv)) && ...
          max(d2(:)) <= 1e-6;
    results = check(results, ok2, ...
        'T2: density envelope == (sectorEirp - peakGain) - 10log10(BW) + gain envelope');

    % ---- T3: single-beam reduction vs band-integrated aggregate ------
    secAgg = imtAasSectorEirpGridFromBeams(az, el, beam1, p, ...
        struct('splitSectorPower', true, 'sectorEirpDbm', p.sectorEirpDbm));
    expectDensity = secAgg.aggregateEirpDbm - bandOff;
    d3 = abs(r1.perSubbandDensityEnvelope_dBmPerMHz - expectDensity);
    ok3 = max(d3(:)) <= 1e-6;
    results = check(results, ok3, ...
        'T3: single-beam density == band-integrated aggregate - 10log10(BW)');

    % ---- T4: validity bound flag ------------------------------------
    % 3 beams, BW=100 -> bound = 33.33 MHz.
    rClear = imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', 1));
    rSpan  = imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', 50));
    ok4 = rClear.validity.spansMultipleUeAllocations == false && ...
          rSpan.validity.spansMultipleUeAllocations == true && ...
          abs(rClear.validity.singleBeamPerSubbandBoundMHz - BW/3) <= 1e-9;
    results = check(results, ok4, ...
        'T4: validity flag clears at subbandMHz<=BW/N, sets at subbandMHz>BW/N');

    % ---- T5: strict subbandMHz validation ---------------------------
    ok5 = throwsId(@() imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', 0)), ...
              'imtAasSubbandEnvelope:invalidSubbandMHz') && ...
          throwsId(@() imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', -1)), ...
              'imtAasSubbandEnvelope:invalidSubbandMHz') && ...
          throwsId(@() imtAasSubbandEnvelope(az, el, beams3, p, struct('subbandMHz', BW + 1)), ...
              'imtAasSubbandEnvelope:invalidSubbandMHz');
    results = check(results, ok5, ...
        'T5: bad subbandMHz throws imtAasSubbandEnvelope:invalidSubbandMHz');

    fprintf('\n--- test_imtAasSubbandEnvelope summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = check(r, cond, msg)
    if cond
        r.summary{end+1} = ['PASS  ' msg];
    else
        r.summary{end+1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
