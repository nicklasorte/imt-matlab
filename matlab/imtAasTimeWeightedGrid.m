function tw = imtAasTimeWeightedGrid(stats, ssb, timeBudget)
%IMTAASTIMEWEIGHTEDGRID Time-weighted (sweep + load-gated traffic) EIRP grid.
%
%   TW = imtAasTimeWeightedGrid(STATS, SSB, TIMEBUDGET)
%
%   Combines the always-on SSB broadcast sweep and the UE-driven traffic
%   grid into a single per-direction TIME-AVERAGE EIRP grid using the
%   duty-cycle weights from the DL frame time budget:
%
%       Pbar = alphaSweep * S  +  alphaUe * T            (linear mW)
%
%   where
%       S = 10.^(SSB.timeAvg_dBm / 10)   sweep conditional mean (mean over
%                                        the L sweep beams, linear power)
%       T = STATS.mean_lin_mW            UE/traffic conditional mean
%                                        (Monte Carlo linear-mW mean)
%
%   alphaSweep / alphaUe are the fraction of OFDM symbols spent in the
%   sweep and UE classes; the remaining alphaIdle is idle/UL time that
%   radiates no power, hence Pbar is the true time-average (NOT a peak).
%
%   STATS and SSB must share the same (az, el) grid. STATS is the streaming
%   traffic aggregator from runR23AasEirpCdfGrid; it is READ-ONLY here.
%
%   TIMEBUDGET selects the duty-cycle model:
%     * If TIMEBUDGET.frame is a struct -> the TS 38.214 frame path. The
%       sweep beam count and per-UE count default into the frame cfg:
%         frame.ssb.L        <- SSB.numBeams           (when absent)
%         frame.csirsUe.numUes <- STATS.numUesPerSector (when absent)
%       then alphaSweep/alphaUe/alphaIdle come from imtAasDlFrameTimeBudget.
%     * Otherwise -> the legacy simple budget (back-compat). Fields:
%         .numSSB (default SSB.numBeams) .symbolsPerSSB (4)
%         .ssbScs_kHz (30) .ssbPeriod_ms (20) .dlFraction (0.75)
%         .loadFactor (0.20)
%       with
%         alphaSweep = min(numSSB*symbolsPerSSB*Tsym/(ssbPeriod_ms*1e-3), dlFraction)
%         alphaUe    = max(dlFraction - alphaSweep, 0) * loadFactor
%
%   Output TW struct:
%     .avg_dBm         10*log10(Pbar)                       [dBm], Naz x Nel
%     .peak_dBm        max(STATS.max_dBm, SSB.envelope_dBm) [dBm], Naz x Nel
%                      (worst-case envelope: the higher of the traffic peak
%                      and the sweep peak per direction, NOT a power sum)
%     .sweepShareOfAvg alphaSweep*S ./ max(Pbar, realmin)   in [0,1]
%     .alphaSweep .alphaUe .alphaIdle   scalar duty-cycle fractions
%     .budget          full imtAasDlFrameTimeBudget output (frame path only)
%     .timeBudget      resolved summary (.path 'frame'|'legacy' + alphas)
%   Back-compat ALIASES (also set):
%     .ssbShareOfAvg = .sweepShareOfAvg
%     .alphaSsb      = .alphaSweep
%     .alphaTr       = .alphaUe
%
%   See also: imtAasDlFrameTimeBudget, imtAasSsbOption, runR23AasEirpCdfGrid.

    if nargin < 3 || isempty(timeBudget)
        timeBudget = struct();
    end
    if ~isstruct(timeBudget)
        error('imtAasTimeWeightedGrid:badTimeBudget', ...
            'TIMEBUDGET must be a struct (or [] for defaults).');
    end

    % ---- grids must agree -------------------------------------------
    assertSameGrid(stats, ssb);

    % ---- conditional means (linear mW) ------------------------------
    S = 10 .^ (ssb.timeAvg_dBm ./ 10);   % sweep conditional mean
    T = stats.mean_lin_mW;               % traffic conditional mean

    % ---- resolve duty-cycle fractions -------------------------------
    if isfield(timeBudget, 'frame') && isstruct(timeBudget.frame)
        frame = timeBudget.frame;
        % Default the sweep beam count and per-UE count from the caller's
        % actual geometry (so the symbol accounting matches the radiated
        % sweep / traffic grids it weights).
        frame = ensureSub(frame, 'ssb');
        if ~isfield(frame.ssb, 'L') || isempty(frame.ssb.L)
            frame.ssb.L = ssb.numBeams;
        end
        frame = ensureSub(frame, 'csirsUe');
        if ~isfield(frame.csirsUe, 'numUes') || isempty(frame.csirsUe.numUes)
            frame.csirsUe.numUes = getf(stats, 'numUesPerSector', 3);
        end

        budget     = imtAasDlFrameTimeBudget(frame);
        alphaSweep = budget.alphaSweep;
        alphaUe    = budget.alphaUe;
        alphaIdle  = budget.alphaIdle;

        % Build field-by-field (a struct value as a struct() argument can
        % be misinterpreted as a struct-array spec).
        resolvedTb            = struct();
        resolvedTb.path       = 'frame';
        resolvedTb.alphaSweep = alphaSweep;
        resolvedTb.alphaUe    = alphaUe;
        resolvedTb.alphaIdle  = alphaIdle;
        resolvedTb.frame      = budget.frame;
    else
        % ---- legacy simple budget (back-compat) ---------------------
        numSSB        = getf(timeBudget, 'numSSB',        ssb.numBeams);
        symbolsPerSSB = getf(timeBudget, 'symbolsPerSSB', 4);
        ssbScs_kHz    = getf(timeBudget, 'ssbScs_kHz',    30);
        ssbPeriod_ms  = getf(timeBudget, 'ssbPeriod_ms',  20);
        dlFraction    = getf(timeBudget, 'dlFraction',    0.75);
        loadFactor    = getf(timeBudget, 'loadFactor',    0.20);

        mu          = log2(ssbScs_kHz / 15);
        slotsPerSec = 2^mu * 1000;
        symRate     = slotsPerSec * 14;
        Tsym        = 1 / symRate;

        alphaSweep = min(numSSB * symbolsPerSSB * Tsym / (ssbPeriod_ms * 1e-3), dlFraction);
        alphaUe    = max(dlFraction - alphaSweep, 0) * loadFactor;
        alphaIdle  = max(1 - alphaSweep - alphaUe, 0);

        budget = [];
        resolvedTb = struct('path', 'legacy', ...
            'alphaSweep', alphaSweep, 'alphaUe', alphaUe, 'alphaIdle', alphaIdle, ...
            'numSSB', numSSB, 'symbolsPerSSB', symbolsPerSSB, ...
            'ssbScs_kHz', ssbScs_kHz, 'ssbPeriod_ms', ssbPeriod_ms, ...
            'dlFraction', dlFraction, 'loadFactor', loadFactor);
    end

    % ---- time-weighted average power --------------------------------
    Pbar = alphaSweep .* S + alphaUe .* T;

    tw = struct();
    tw.avg_dBm         = 10 .* log10(Pbar);
    tw.peak_dBm        = max(stats.max_dBm, ssb.envelope_dBm);
    tw.sweepShareOfAvg = (alphaSweep .* S) ./ max(Pbar, realmin);
    tw.alphaSweep      = alphaSweep;
    tw.alphaUe         = alphaUe;
    tw.alphaIdle       = alphaIdle;
    if ~isempty(budget)
        tw.budget = budget;
    end
    tw.timeBudget      = resolvedTb;

    % ---- back-compat aliases ----------------------------------------
    tw.ssbShareOfAvg   = tw.sweepShareOfAvg;
    tw.alphaSsb        = tw.alphaSweep;
    tw.alphaTr         = tw.alphaUe;
end

% =====================================================================

function assertSameGrid(stats, ssb)
%ASSERTSAMEGRID Require STATS and SSB to share the same az/el grid.
    sa = stats.azGrid(:); se = stats.elGrid(:);
    ba = ssb.azGrid(:);   be = ssb.elGrid(:);
    ok = numel(sa) == numel(ba) && numel(se) == numel(be) && ...
         isequal(size(stats.mean_lin_mW), size(ssb.timeAvg_dBm));
    if ok
        ok = max(abs(sa - ba)) < 1e-9 && max(abs(se - be)) < 1e-9;
    end
    if ~ok
        error('imtAasTimeWeightedGrid:gridMismatch', ...
            ['STATS and SSB must share the same (az, el) grid ', ...
             '(stats %dx%d, ssb %dx%d).'], ...
            numel(sa), numel(se), numel(ba), numel(be));
    end
end

function s = ensureSub(s, name)
%ENSURESUB Guarantee s.(name) exists and is a struct.
    if ~isfield(s, name) || ~isstruct(s.(name))
        s.(name) = struct();
    end
end

function v = getf(s, name, default)
%GETF Struct field read with default for missing / empty fields.
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
