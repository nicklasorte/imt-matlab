function fig = plotImtAasReferenceComparison(cmp, titleText)
%PLOTIMTAASREFERENCECOMPARISON Plot actual vs reference EIRP cut + error.
%
%   FIG = plotImtAasReferenceComparison(CMP)
%   FIG = plotImtAasReferenceComparison(CMP, TITLETEXT)
%
%   Renders a two-panel figure for one EIRP pattern-cut comparison
%   produced by imtAasComparePatternCut:
%
%       top    panel:  actualDbm and referenceDbm vs angleDeg
%                      (x-axis label: "Angle (deg)",
%                       y-axis label: "EIRP (dBm/100 MHz)")
%       bottom panel:  errorDb = actualDbm - referenceDbm vs angleDeg
%                      (x-axis label: "Angle (deg)",
%                       y-axis label: "Error (dB)")
%
%   The figure title shows max abs error and RMS error from CMP, plus
%   the optional caller-supplied TITLETEXT.
%
%   Inputs:
%       cmp        struct from imtAasComparePatternCut. Required fields:
%                    angleDeg, actualDbm, referenceDbm, errorDb,
%                    maxAbsErrorDb, rmsErrorDb. Optional fields:
%                    pass, peakAngleDeg, mainLobeWindowDeg.
%       titleText  optional char/string prepended to the auto title.
%
%   Output:
%       fig        figure handle.
%
%   Base MATLAB only - no toolboxes required.
%
%   See also imtAasComparePatternCut, imtAasLoadReferenceCutCsv.

    if nargin < 1 || ~isstruct(cmp) || ~isscalar(cmp)
        error('plotImtAasReferenceComparison:invalidInput', ...
            'cmp must be a scalar struct from imtAasComparePatternCut.');
    end
    if nargin < 2 || isempty(titleText)
        titleText = '';
    end
    if isstring(titleText) && isscalar(titleText)
        titleText = char(titleText);
    end
    if ~ischar(titleText)
        error('plotImtAasReferenceComparison:invalidTitle', ...
            'titleText must be a char vector or scalar string.');
    end

    requiredFields = {'angleDeg', 'actualDbm', 'referenceDbm', ...
                      'errorDb', 'maxAbsErrorDb', 'rmsErrorDb'};
    for i = 1:numel(requiredFields)
        if ~isfield(cmp, requiredFields{i})
            error('plotImtAasReferenceComparison:missingField', ...
                'cmp struct missing required field "%s".', ...
                requiredFields{i});
        end
    end

    angle  = cmp.angleDeg(:).';
    actual = cmp.actualDbm(:).';
    refV   = cmp.referenceDbm(:).';
    errDb  = cmp.errorDb(:).';

    if numel(actual) ~= numel(angle) || numel(refV) ~= numel(angle) ...
            || numel(errDb) ~= numel(angle)
        error('plotImtAasReferenceComparison:sizeMismatch', ...
            ['cmp.actualDbm / referenceDbm / errorDb lengths must ', ...
             'match cmp.angleDeg length (%d).'], numel(angle));
    end

    fig = figure('Name', 'IMT AAS reference comparison', 'Color', 'w');

    % ---- top panel: actual vs reference -------------------------------
    ax1 = subplot(2, 1, 1);
    plot(ax1, angle, actual, 'b-',  'LineWidth', 1.25); hold(ax1, 'on');
    plot(ax1, angle, refV,   'r--', 'LineWidth', 1.25);
    if isfield(cmp, 'peakAngleDeg') && isfinite(cmp.peakAngleDeg) ...
            && isfield(cmp, 'mainLobeWindowDeg') ...
            && isfinite(cmp.mainLobeWindowDeg) ...
            && cmp.mainLobeWindowDeg > 0
        halfWin = cmp.mainLobeWindowDeg / 2;
        yl = ylim(ax1);
        plot(ax1, [cmp.peakAngleDeg - halfWin, cmp.peakAngleDeg - halfWin], ...
             yl, 'k:', 'LineWidth', 0.75);
        plot(ax1, [cmp.peakAngleDeg + halfWin, cmp.peakAngleDeg + halfWin], ...
             yl, 'k:', 'LineWidth', 0.75);
    end
    hold(ax1, 'off');
    grid(ax1, 'on');
    xlabel(ax1, 'Angle (deg)');
    ylabel(ax1, 'EIRP (dBm/100 MHz)');
    legend(ax1, {'Actual (MATLAB)', 'Reference'}, 'Location', 'best');

    autoTitle = sprintf('maxAbsErr = %.3f dB, RMS = %.3f dB', ...
        cmp.maxAbsErrorDb, cmp.rmsErrorDb);
    if isfield(cmp, 'pass')
        if cmp.pass
            tag = 'PASS';
        else
            tag = 'FAIL';
        end
        autoTitle = sprintf('%s [%s]', autoTitle, tag);
    end
    if isempty(titleText)
        title(ax1, autoTitle);
    else
        title(ax1, sprintf('%s  -  %s', titleText, autoTitle));
    end

    % ---- bottom panel: error vs angle --------------------------------
    ax2 = subplot(2, 1, 2);
    plot(ax2, angle, errDb, 'k-', 'LineWidth', 1.0); hold(ax2, 'on');
    plot(ax2, [angle(1), angle(end)], [0, 0], 'Color', [0.5 0.5 0.5], ...
         'LineStyle', '--', 'LineWidth', 0.75);
    if isfield(cmp, 'opts') && isstruct(cmp.opts) ...
            && isfield(cmp.opts, 'maxAbsErrorDb') ...
            && isfinite(cmp.opts.maxAbsErrorDb) ...
            && cmp.opts.maxAbsErrorDb > 0
        thr = cmp.opts.maxAbsErrorDb;
        plot(ax2, [angle(1), angle(end)], [+thr, +thr], 'r:', ...
             'LineWidth', 0.75);
        plot(ax2, [angle(1), angle(end)], [-thr, -thr], 'r:', ...
             'LineWidth', 0.75);
    end
    hold(ax2, 'off');
    grid(ax2, 'on');
    xlabel(ax2, 'Angle (deg)');
    ylabel(ax2, 'Error (dB)');
    title(ax2, 'Error: actual - reference');
end
