function cfg = load_suspension_config(projectRoot,model)
% Load versioned benchmark settings; positional overrides are applied by callers.
configPath = fullfile(projectRoot,'config',[lower(model),'_li2021_parameters.json']);
assert(isfile(configPath),'Missing benchmark configuration: %s',configPath);
cfg = jsondecode(fileread(configPath));
assert(strcmp(cfg.model,model) && cfg.schema_version == 1,'Configuration model/schema mismatch.');
assert(strcmp(cfg.solver.method,'ode45'),'Only the documented ode45 method is supported.');
validateattributes(cfg.solver.output_step_s,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.solver.rel_tol,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.solver.abs_tol,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.solver.max_step_s,{'numeric'},{'scalar','real','finite','positive'});
physical = [struct2array(cfg.vehicle),cfg.secondary.k,cfg.secondary.c,cfg.secondary.b,cfg.secondary.l];
assert(all(isfinite(physical)) && all(physical > 0),'Physical parameters must be positive and finite.');
assert(isempty(cfg.reference_track_csv) || ...
    (isempty(regexp(cfg.reference_track_csv,'^(/|[A-Za-z]:)|(^|[/\\])\.\.([/\\]|$)','once'))), ...
    'reference_track_csv must be a project-relative path without parent traversal.');
assert(numel(cfg.solver.initial_state) == 8 && all(isfinite(cfg.solver.initial_state)), ...
    'Initial state must contain eight finite values.');
cfg.configuration_path = ['config/',lower(model),'_li2021_parameters.json'];
end
