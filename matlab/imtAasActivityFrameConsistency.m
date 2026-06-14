function info = imtAasActivityFrameConsistency(budget, pLegacy)
%IMTAASACTIVITYFRAMECONSISTENCY Compare the legacy activity p vs frame alphaUe.
%
%   INFO = imtAasActivityFrameConsistency(BUDGET, PLEGACY)
%
%   Pure, deterministic consistency check between the two time/activity
%   mechanisms in runR23AasEirpCdfGrid:
%
%     * the LEGACY activity-weighted CDF on-fraction
%           pLegacy = tddActivityFactor * networkLoadingFactor
%     * the FRAME-budget UE-class duty cycle
%           budget.alphaUe   (from imtAasDlFrameTimeBudget, TS 38.214)
%
%   The two SHOULD agree when both describe the same UE-traffic activity.
%   When they diverge (the standalone tdd*load factor is not derived from
%   the symbol-counted frame budget) the CDF view and the SSB time-weighted
%   grid are sourced from different activity factors -- this helper flags
%   that so the caller can warn and point at activityModel='frame'.
%
%   BUDGET   imtAasDlFrameTimeBudget output (must have field .alphaUe).
%   PLEGACY  finite numeric scalar legacy on-fraction.
%
%   Output INFO struct:
%     .alphaUe       budget.alphaUe (frame UE-class duty cycle)
%     .pLegacy       the supplied legacy on-fraction
%     .deltaAlphaUe  abs(alphaUe - pLegacy)
%     .consistent    deltaAlphaUe < tolerance  (logical)
%     .tolerance     1e-3 (absolute, on the duty-cycle fraction)
%
%   See also: imtAasDlFrameTimeBudget, runR23AasEirpCdfGrid.

    if ~isstruct(budget) || ~isfield(budget, 'alphaUe')
        error('imtAasActivityFrameConsistency:badBudget', ...
            'BUDGET must be an imtAasDlFrameTimeBudget output with field .alphaUe.');
    end
    if ~(isnumeric(pLegacy) && isscalar(pLegacy) && isfinite(pLegacy))
        error('imtAasActivityFrameConsistency:badPLegacy', ...
            'PLEGACY must be a finite numeric scalar.');
    end

    tol = 1e-3;
    alphaUe = double(budget.alphaUe);
    pLeg    = double(pLegacy);

    info = struct();
    info.alphaUe      = alphaUe;
    info.pLegacy      = pLeg;
    info.deltaAlphaUe = abs(alphaUe - pLeg);
    info.consistent   = info.deltaAlphaUe < tol;
    info.tolerance    = tol;
end
