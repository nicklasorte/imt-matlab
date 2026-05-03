function [AZ, EL] = imtAasNormalizeGrid(azGrid, elGrid)
%IMTAASNORMALIZEGRID Normalize az/el inputs into matched 2-D arrays.
%
%   [AZ, EL] = imtAasNormalizeGrid(AZGRID, ELGRID)
%
%   Helper used by the AAS MVP (imtAasArrayFactor / imtAasCompositeGain /
%   imtAasEirpGrid) to give deterministic handling of scalar / vector /
%   2-D grid inputs:
%
%       both scalars                -> AZ, EL are scalars
%       both vectors                -> AZ, EL are ndgrid'd to Naz x Nel
%       both 2-D arrays, same size  -> passed through unchanged
%
%   Anything else (mismatched 2-D shapes, ndims > 2, non-numeric, NaN/Inf)
%   raises a clear identifier'd error.

    if ~isnumeric(azGrid) || ~isreal(azGrid)
        error('imtAas:invalidGrid', ...
            'azGrid must be a real numeric array.');
    end
    if ~isnumeric(elGrid) || ~isreal(elGrid)
        error('imtAas:invalidGrid', ...
            'elGrid must be a real numeric array.');
    end
    if any(~isfinite(azGrid(:))) || any(~isfinite(elGrid(:)))
        error('imtAas:invalidGrid', ...
            'azGrid / elGrid contain NaN or Inf.');
    end
    if ndims(azGrid) > 2 || ndims(elGrid) > 2 %#ok<ISMAT>
        error('imtAas:invalidGrid', ...
            'azGrid / elGrid must be at most 2-D.');
    end

    if isscalar(azGrid) && isscalar(elGrid)
        AZ = double(azGrid);
        EL = double(elGrid);
        return;
    end

    if isequal(size(azGrid), size(elGrid))
        if isvector(azGrid) && size(azGrid, 1) == 1
            % Same-length ROW vectors [1×N]: independent axes — ndgrid to Naz×Nel.
            [AZ, EL] = ndgrid(double(azGrid(:).'), double(elGrid(:).'));
        else
            % Same-shape column vectors [N×1] or 2-D matrices: already matched
            % pairs (e.g. output of a prior ndgrid call) — pass through unchanged
            % so they are not accidentally re-ndgrid'd into a larger square matrix.
            AZ = double(azGrid);
            EL = double(elGrid);
        end
        return;
    end

    if isvector(azGrid) && isvector(elGrid)
        [AZ, EL] = ndgrid(double(azGrid(:).'), double(elGrid(:).'));
        return;
    end

    error('imtAas:gridSizeMismatch', ...
        ['azGrid (size %s) and elGrid (size %s) must be both scalars, ' ...
         'both vectors, or two 2-D arrays of the same size.'], ...
        mat2str(size(azGrid)), mat2str(size(elGrid)));
end
