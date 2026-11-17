function key = imtBandName(band)
%IMTBANDNAME Canonical band key for the band option.
%
%   KEY = imtBandName(BAND) returns '7ghz' or '2p7ghz'. BAND is a char or
%   scalar string and is matched case-insensitively against these aliases:
%       '7ghz', '7 ghz', 'r23', '8ghz', '7.125-8.4ghz'        -> '7ghz'
%       '2p7ghz', '2.7ghz', '2.7 ghz', '2700-2800mhz', '2750' -> '2p7ghz'
%
%   Errors with imtBandName:unknownBand for anything else.
%
%   See also: imtBandDefaultParams, aasGeometryPreset.

    if isstring(band) && isscalar(band)
        band = char(band);
    end
    if isnumeric(band) && isscalar(band)
        band = num2str(band);
    end
    if ~ischar(band)
        error('imtBandName:badBand', 'BAND must be a char or scalar string.');
    end

    k = lower(strrep(strtrim(band), ' ', ''));
    switch k
        case {'7ghz', 'r23', '8ghz', '7.125-8.4ghz', '7125-8400mhz'}
            key = '7ghz';
        case {'2p7ghz', '2.7ghz', '2700-2800mhz', '2750', '2750mhz'}
            key = '2p7ghz';
        otherwise
            error('imtBandName:unknownBand', ...
                ['Unknown band "%s". Supported: ''7ghz'' (default), ' ...
                 '''2p7ghz''.'], band);
    end
end
