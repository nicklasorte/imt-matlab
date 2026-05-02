function cfg = embrss_aas_config(category, varargin)
%EMBRSS_AAS_CONFIG EMBRSS-style AAS antenna + power config (M.2101 default).
%
%   CFG = embrss_aas_config(CATEGORY)
%   CFG = embrss_aas_config(CATEGORY, NAME, VALUE, ...)
%
%   Returns a CFG struct compatible with imt_aas_bs_eirp /
%   run_imt_aas_eirp_monte_carlo for an EMBRSS deployment category. The
%   CATEGORY argument is currently informational (held in cfg.category)
%   but is accepted so the API matches embrss_category_model.
%
%   Default antenna parameters use the existing repo M.2101 / pycraf-parity
%   composite-pattern model (cfg.patternModel = 'm2101'). The R23 7/8 GHz
%   extended sub-array variant (cfg.patternModel = 'r23_extended_aas') is
%   NOT enabled here; that is a follow-up.
%
%   Power semantics
%   ---------------
%   imt_aas_bs_eirp computes:
%       eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB
%   so cfg.txPower_dBm is the **conducted** transmit power, not peak EIRP.
%   To avoid double-counting antenna gain we expose two modes:
%
%       'powerMode' = 'conducted' (default)
%           cfg.txPower_dBm is taken directly from 'txPower_dBm' (default
%           20 dBm; this is intentionally low so demo runs do not emit
%           regulatory-scale numbers).
%
%       'powerMode' = 'peak_eirp'
%           Caller supplies the desired peak EIRP and the array peak gain.
%           cfg.txPower_dBm is then back-computed:
%               cfg.txPower_dBm = peakEirp_dBm - peakGain_dBi
%                                 + cfg.feederLoss_dB
%           For an N_H x N_V uniform array with rho = 1 the peak gain is
%               peakGain_dBi = G_Emax + 10*log10(N_H * N_V)
%           which is also used as the default if 'peakGain_dBi' is omitted.
%
%   Name-value pairs
%   ----------------
%   Antenna fields (defaults shown):
%       'G_Emax'        6.4    [dBi]   single-element peak gain
%       'A_m'           30     [dB]    horizontal front-to-back ratio
%       'SLA_nu'        30     [dB]    vertical side-lobe attenuation
%       'phi_3db'       90     [deg]   horizontal 3 dB beamwidth
%       'theta_3db'     65     [deg]   vertical 3 dB beamwidth
%       'd_H'           0.5    [lam]   horizontal element spacing
%       'd_V'           0.5    [lam]   vertical element spacing
%       'N_H'           8              horizontal element count
%       'N_V'           16             vertical element count
%       'rho'           1              correlation level in [0,1]
%       'k'             12             multiplication factor
%       'feederLoss_dB' 0      [dB]
%
%   Power fields:
%       'powerMode'      'conducted' | 'peak_eirp'
%       'txPower_dBm'    20  (conducted mode)
%       'peakEirp_dBm'    -  (peak_eirp mode, required)
%       'peakGain_dBi'    -  (peak_eirp mode, optional;
%                               default = G_Emax + 10*log10(N_H*N_V))
%
%   Returned CFG fields include all of the above plus:
%       cfg.patternModel = 'm2101'
%       cfg.category     = char(category)
%       cfg.powerMode    = 'conducted' | 'peak_eirp'
%
%   Examples
%   --------
%       cfg = embrss_aas_config('urban_macro');
%       cfg = embrss_aas_config('urban_macro', ...
%                  'powerMode', 'peak_eirp', ...
%                  'peakEirp_dBm', 72);

    if nargin < 1 || isempty(category)
        error('embrss_aas_config:missingCategory', ...
            'CATEGORY is required.');
    end
    if ~(ischar(category) || (isstring(category) && isscalar(category)))
        error('embrss_aas_config:badCategoryType', ...
            'CATEGORY must be a char vector or string scalar.');
    end

    % --- defaults ----------------------------------------------------
    cfg = struct();
    cfg.patternModel  = 'm2101';
    cfg.category      = char(category);

    cfg.G_Emax        = 6.4;
    cfg.A_m           = 30;
    cfg.SLA_nu        = 30;
    cfg.phi_3db       = 90;
    cfg.theta_3db     = 65;
    cfg.d_H           = 0.5;
    cfg.d_V           = 0.5;
    cfg.N_H           = 8;
    cfg.N_V           = 16;
    cfg.rho           = 1;
    cfg.k             = 12;
    cfg.feederLoss_dB = 0;

    cfg.powerMode     = 'conducted';
    cfg.txPower_dBm   = 20;       % small, safe default for demos
    cfg.peakEirp_dBm  = [];
    cfg.peakGain_dBi  = [];

    % --- parse name-value pairs --------------------------------------
    if mod(numel(varargin), 2) ~= 0
        error('embrss_aas_config:badOverrides', ...
            'Name-value overrides must come in name/value pairs.');
    end

    powerOverrides = struct( ...
        'powerMode_set',    false, ...
        'txPower_set',      false, ...
        'peakEirp_set',     false, ...
        'peakGain_set',     false);

    numericFields = {'G_Emax','A_m','SLA_nu','phi_3db','theta_3db', ...
        'd_H','d_V','N_H','N_V','rho','k','feederLoss_dB', ...
        'txPower_dBm','peakEirp_dBm','peakGain_dBi'};

    for i = 1:2:numel(varargin)
        name = varargin{i};
        val  = varargin{i+1};
        if ~(ischar(name) || (isstring(name) && isscalar(name)))
            error('embrss_aas_config:badOverrideName', ...
                'Override names must be char vectors or string scalars.');
        end
        name = char(name);

        switch name
            case 'patternModel'
                if ~(ischar(val) || (isstring(val) && isscalar(val)))
                    error('embrss_aas_config:badPatternModel', ...
                        'patternModel must be a char/string scalar.');
                end
                pm = lower(char(val));
                if ~ismember(pm, {'m2101','r23_extended_aas'})
                    error('embrss_aas_config:badPatternModel', ...
                        ['Unknown patternModel "%s". Supported: ' ...
                         '"m2101", "r23_extended_aas".'], pm);
                end
                cfg.patternModel = pm;

            case 'powerMode'
                if ~(ischar(val) || (isstring(val) && isscalar(val)))
                    error('embrss_aas_config:badPowerMode', ...
                        'powerMode must be a char/string scalar.');
                end
                v = lower(char(val));
                if ~ismember(v, {'conducted','peak_eirp'})
                    error('embrss_aas_config:badPowerMode', ...
                        ['Unknown powerMode "%s". Supported: ' ...
                         '"conducted", "peak_eirp".'], v);
                end
                cfg.powerMode = v;
                powerOverrides.powerMode_set = true;

            case numericFields
                if ~isempty(val)
                    validateattributes(val, {'numeric'}, ...
                        {'real','finite','scalar'}, mfilename, name);
                    cfg.(name) = double(val);
                end
                switch name
                    case 'txPower_dBm'
                        powerOverrides.txPower_set  = ~isempty(val);
                    case 'peakEirp_dBm'
                        powerOverrides.peakEirp_set = ~isempty(val);
                    case 'peakGain_dBi'
                        powerOverrides.peakGain_set = ~isempty(val);
                end

            otherwise
                error('embrss_aas_config:badOverrideName', ...
                    'Unknown override field "%s".', name);
        end
    end

    % --- post-validation: array sizes --------------------------------
    if cfg.N_H < 1 || mod(cfg.N_H, 1) ~= 0
        error('embrss_aas_config:badN_H', 'N_H must be a positive integer.');
    end
    if cfg.N_V < 1 || mod(cfg.N_V, 1) ~= 0
        error('embrss_aas_config:badN_V', 'N_V must be a positive integer.');
    end
    if cfg.rho < 0 || cfg.rho > 1
        error('embrss_aas_config:badRho', 'rho must be in [0, 1].');
    end

    % --- resolve power semantics -------------------------------------
    %
    % 'conducted' mode: cfg.txPower_dBm is taken at face value. We do
    % NOT add antenna gain here; the imt_aas_bs_eirp call will combine
    % conducted power with composite gain. Setting peakEirp_dBm in this
    % mode is an error because it implies a different power semantics
    % and we would otherwise silently double-count.
    %
    % 'peak_eirp' mode: caller specifies the peak EIRP at the array
    % boresight. We back-compute conducted power so that
    %       cfg.txPower_dBm + peakGain_dBi - feederLoss_dB = peakEirp_dBm
    % which is the only way to avoid double-counting antenna gain when
    % imt_aas_bs_eirp later adds gain_dBi.
    switch cfg.powerMode
        case 'conducted'
            if powerOverrides.peakEirp_set
                error('embrss_aas_config:peakEirpInConducted', ...
                    ['peakEirp_dBm was supplied but powerMode is ' ...
                     '"conducted"; pass powerMode="peak_eirp" to use ' ...
                     'peak EIRP, or remove peakEirp_dBm to use ' ...
                     'conducted txPower_dBm directly.']);
            end
            % fall through; cfg.txPower_dBm is already set
            cfg.peakEirp_dBm = [];
            cfg.peakGain_dBi = [];

        case 'peak_eirp'
            if ~powerOverrides.peakEirp_set || isempty(cfg.peakEirp_dBm)
                error('embrss_aas_config:missingPeakEirp', ...
                    ['powerMode="peak_eirp" requires a peakEirp_dBm ' ...
                     'value.']);
            end
            if powerOverrides.txPower_set
                error('embrss_aas_config:txPowerInPeakEirp', ...
                    ['Do not pass txPower_dBm when powerMode=' ...
                     '"peak_eirp"; conducted power is back-computed ' ...
                     'from peakEirp_dBm and peakGain_dBi.']);
            end
            % default peak gain: G_Emax + 10*log10(N_H*N_V) (rho=1, full
            % coherent boresight). User can override.
            if ~powerOverrides.peakGain_set || isempty(cfg.peakGain_dBi)
                cfg.peakGain_dBi = cfg.G_Emax + ...
                    10 * log10(double(cfg.N_H) * double(cfg.N_V));
            end
            cfg.txPower_dBm = cfg.peakEirp_dBm - cfg.peakGain_dBi ...
                              + cfg.feederLoss_dB;

        otherwise
            error('embrss_aas_config:badPowerMode', ...
                'Unknown powerMode "%s".', cfg.powerMode);
    end
end
