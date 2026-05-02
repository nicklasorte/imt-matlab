function model = embrss_category_model(category, varargin)
%EMBRSS_CATEGORY_MODEL EMBRSS-style deployment-category model presets.
%
%   MODEL = embrss_category_model(CATEGORY)
%   MODEL = embrss_category_model(CATEGORY, NAME, VALUE, ...)
%
%   Returns a struct with the per-category geometric / UE-density defaults
%   used to drive the first-step EMBRSS antenna/EIRP CDF-grid generator.
%
%   This is NOT a full Quadriga / SSB acquisition / CSI / PMI model. The
%   per-iteration beam pointing is later drawn by sample_aas_beam_direction
%   in 'ue_sector' mode using these geometric parameters.
%
%   CATEGORY (char or string scalar):
%       'urban_macro'
%       'suburban_macro'
%       'rural_macro'
%
%   Returned MODEL fields:
%       .name                  category name (char)
%       .bs_height_m           base-station antenna height above ground
%       .sector_radius_m       cell-sector outer radius (UE r_max)
%       .ue_height_range_m     [hMin hMax] UE antenna AGL range
%       .sector_az_deg         sector boresight azimuth [deg]
%       .sector_width_deg      sector opening angle [deg]
%       .min_ue_range_m        minimum BS-to-UE range (UE r_min)
%       .num_ues_per_sector    number of co-scheduled UEs per sector
%       .default_num_beams     beams per Monte Carlo draw
%       .default_combine_beams 'max' | 'sum_mW'
%       .notes                 string describing assumptions
%
%   Defaults (EMBRSS-style; conservative macro values):
%       urban_macro:    bs=20m, radius=400m,  ue_h=[1.5 35]
%       suburban_macro: bs=25m, radius=800m,  ue_h=[1.5 17]
%       rural_macro:    bs=35m, radius=1600m, ue_h=[1.5 5]
%
%   Each category uses sector_width_deg=120, min_ue_range_m=35,
%   num_ues_per_sector=3.
%
%   Name-value pairs override any numeric field by name (validated). For
%   example:
%       m = embrss_category_model('urban_macro', ...
%               'sector_radius_m', 500, ...
%               'num_ues_per_sector', 4);
%
%   Invalid category names throw embrss_category_model:badCategory.

    if nargin < 1 || isempty(category)
        error('embrss_category_model:missingCategory', ...
            'CATEGORY is required.');
    end
    if ~(ischar(category) || (isstring(category) && isscalar(category)))
        error('embrss_category_model:badCategoryType', ...
            'CATEGORY must be a char vector or string scalar.');
    end
    cat = char(category);

    switch lower(cat)
        case 'urban_macro'
            model = baseModel();
            model.name              = 'urban_macro';
            model.bs_height_m       = 20;
            model.sector_radius_m   = 400;
            model.ue_height_range_m = [1.5 35];
            model.notes = ['EMBRSS-style urban macro: dense UE heights ' ...
                'up to 35 m to capture high-rise indoor users.'];

        case 'suburban_macro'
            model = baseModel();
            model.name              = 'suburban_macro';
            model.bs_height_m       = 25;
            model.sector_radius_m   = 800;
            model.ue_height_range_m = [1.5 17];
            model.notes = ['EMBRSS-style suburban macro: mid-rise UE ' ...
                'heights, larger sector radius than urban.'];

        case 'rural_macro'
            model = baseModel();
            model.name              = 'rural_macro';
            model.bs_height_m       = 35;
            model.sector_radius_m   = 1600;
            model.ue_height_range_m = [1.5 5];
            model.notes = ['EMBRSS-style rural macro: tall BS, low UEs, ' ...
                'large sector radius.'];

        otherwise
            error('embrss_category_model:badCategory', ...
                ['Unknown category "%s". Supported categories: ' ...
                 '"urban_macro", "suburban_macro", "rural_macro".'], cat);
    end

    % --- name-value overrides ----------------------------------------
    if mod(numel(varargin), 2) ~= 0
        error('embrss_category_model:badOverrides', ...
            'Name-value overrides must come in name/value pairs.');
    end

    for i = 1:2:numel(varargin)
        name = varargin{i};
        val  = varargin{i+1};
        if ~(ischar(name) || (isstring(name) && isscalar(name)))
            error('embrss_category_model:badOverrideName', ...
                'Override names must be char vectors or string scalars.');
        end
        name = char(name);
        switch name
            case {'bs_height_m', 'sector_radius_m', 'sector_az_deg', ...
                  'sector_width_deg', 'min_ue_range_m', ...
                  'num_ues_per_sector', 'default_num_beams'}
                validateattributes(val, {'numeric'}, ...
                    {'real','finite','scalar'}, mfilename, name);
                model.(name) = double(val);
            case 'ue_height_range_m'
                validateattributes(val, {'numeric'}, ...
                    {'real','finite','vector','numel',2,'nonnegative'}, ...
                    mfilename, name);
                if val(2) < val(1)
                    error('embrss_category_model:badRange', ...
                        'ue_height_range_m must satisfy hMax >= hMin.');
                end
                model.ue_height_range_m = double(val(:).');
            case 'default_combine_beams'
                if ~(ischar(val) || (isstring(val) && isscalar(val)))
                    error('embrss_category_model:badCombine', ...
                        'default_combine_beams must be a char/string.');
                end
                v = lower(char(val));
                if ~ismember(v, {'max','sum_mw'})
                    error('embrss_category_model:badCombine', ...
                        'default_combine_beams must be "max" or "sum_mW".');
                end
                model.default_combine_beams = v;
            case 'notes'
                model.notes = char(val);
            case 'name'
                model.name = char(val);
            otherwise
                error('embrss_category_model:badOverrideName', ...
                    'Unknown override field "%s".', name);
        end
    end

    % --- final consistency checks ------------------------------------
    if model.sector_radius_m <= model.min_ue_range_m
        error('embrss_category_model:badGeometry', ...
            ['sector_radius_m (%g) must be > min_ue_range_m (%g).'], ...
            model.sector_radius_m, model.min_ue_range_m);
    end
    if model.sector_width_deg <= 0 || model.sector_width_deg > 360
        error('embrss_category_model:badSectorWidth', ...
            'sector_width_deg must be in (0, 360].');
    end
    if model.num_ues_per_sector < 1 || ...
            mod(model.num_ues_per_sector, 1) ~= 0
        error('embrss_category_model:badNumUes', ...
            'num_ues_per_sector must be a positive integer.');
    end
    if model.default_num_beams < 1 || mod(model.default_num_beams, 1) ~= 0
        error('embrss_category_model:badNumBeams', ...
            'default_num_beams must be a positive integer.');
    end
end

function m = baseModel()
%BASEMODEL Shared default fields (overridden per category).
    m = struct();
    m.name                  = '';
    m.bs_height_m           = 25;
    m.sector_radius_m       = 500;
    m.ue_height_range_m     = [1.5 1.5];
    m.sector_az_deg         = 0;
    m.sector_width_deg      = 120;
    m.min_ue_range_m        = 35;
    m.num_ues_per_sector    = 3;
    m.default_num_beams     = 1;
    m.default_combine_beams = 'max';
    m.notes                 = '';
end
