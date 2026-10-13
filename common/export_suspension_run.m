function result = export_suspension_run(projectRoot,cfg,result,payload,history,sourcePath,runId)
% Preserve a run in paired data/pics directories, without invoking Python.
assert(all(isfinite(history{:,:}),'all'),'Refusing to export non-finite time histories.');
names = fieldnames(result);
for k = 1:numel(names)
    value = result.(names{k});
    if isnumeric(value)
        assert(all(isfinite(value(:))),'Non-finite result field: %s',names{k});
    end
end
if isempty(runId)
    stamp = char(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
    [~,uniqueTag] = fileparts(tempname);
    runId = ['run_',stamp,'_',lower(uniqueTag)];
end
runId = char(runId);
assert(~isempty(regexp(runId,'^[a-z][a-z0-9_]{0,95}$','once')), ...
    'runId must be lowercase snake_case, begin with a letter and be at most 96 characters.');
dataRel = ['data/',cfg.model,'/',runId];
picsRel = ['pics/',cfg.model,'/',runId];
dataDir = fullfile(projectRoot,'data',cfg.model,runId);
picsDir = fullfile(projectRoot,'pics',cfg.model,runId);
assert(~exist(dataDir,'file') && ~exist(picsDir,'file'), ...
    'Run already exists; choose a new runId. Nothing will be overwritten.');
[ok,msg,id] = mkdir(dataDir);
assert(ok && isempty(id),'Cannot reserve data directory: %s',msg);
[ok,msg,id] = mkdir(picsDir);
assert(ok && isempty(id),'Cannot reserve figure directory: %s',msg);
result.run_id = runId;
result.csv_path = [dataRel,'/time_histories.csv'];
result.mat_path = [dataRel,'/simulation_results.mat'];
result.figure_path = [picsRel,'/body_acceleration.png'];
if strcmp(cfg.model,'TIXS')
    result.comparison_figure_path = [picsRel,'/linear_tixs_acceleration_comparison.png'];
end
generatedUtc = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
metadata = struct('model',cfg.model,'run_id',runId,'generated_utc',generatedUtc, ...
    'matlab_version',version,'platform',computer,'solver_status','completed', ...
    'source_function',sourcePath,'configuration_source',cfg.configuration_path, ...
    'source_revision','not recorded; see source_sha256','effective_config',cfg, ...
    'metrics',result,'figure_directory',picsRel,'data_directory',dataRel);
metadata.generation_command = invocation(cfg,runId);
metadata.jvm_enabled = usejava('jvm');
metadata.plot_command = ['python3 ',picsRel,'/plot_time_histories.py'];
metadata.source_sha256 = source_hashes(projectRoot,sourcePath,cfg.configuration_path);
metadata.csv_columns = history.Properties.VariableNames;
metadata.csv_units = cellfun(@column_unit,metadata.csv_columns,'UniformOutput',false);
write_text(fullfile(dataDir,'effective_config.json'),jsonencode(cfg,PrettyPrint=true));
write_text(fullfile(dataDir,'metadata.json'),jsonencode(metadata,PrettyPrint=true));
write_text(fullfile(dataDir,'README.md'),data_readme(metadata));
write_text(fullfile(picsDir,'README.md'),pics_readme(metadata));
template = fullfile(projectRoot,'common','plot_time_histories.py.in');
assert(isfile(template),'Missing plotting template: %s',template);
copyfile(template,fullfile(picsDir,'plot_time_histories.py'));
writetable(history,fullfile(dataDir,'time_histories.csv'));
track = payload.track;
trackTable = table(track.t,track.front,track.rear,track.vFront,track.vRear, ...
    'VariableNames',{'time_s','front_track_m','rear_track_m','front_track_velocity_m_s','rear_track_velocity_m_s'});
writetable(trackTable,fullfile(dataDir,'track_realization.csv'));
payload.result = result;
payload.config = cfg;
payload.metadata = metadata;
save(fullfile(dataDir,'simulation_results.mat'),'-struct','payload','-v7');
fprintf('Saved run %s\nRegenerate figures from project root: %s\n',runId,metadata.plot_command);
end

function command = invocation(cfg,runId)
if strcmp(cfg.model,'IBXS')
    command = sprintf('simulate_ibxs_li2021(%.17g,true,%.17g,%.17g,''%s'',%.17g)', ...
        cfg.solver.max_step_s,cfg.secondary.alpha_deg,cfg.secondary.l,runId,cfg.solver.duration_s);
else
    command = sprintf('simulate_tixs_li2021(%.17g,true,''%s'',%.17g)', ...
        cfg.secondary.alpha_deg,runId,cfg.solver.duration_s);
end
end

function value = column_unit(name)
if endsWith(name,'_m_s2'), value = 'm/s^2';
elseif endsWith(name,'_rad_s'), value = 'rad/s';
elseif endsWith(name,'_m_s'), value = 'm/s';
elseif endsWith(name,'_rad'), value = 'rad';
elseif endsWith(name,'_m'), value = 'm';
elseif strcmp(name,'time_s'), value = 's';
else, error('Missing unit definition for CSV column %s.',name);
end
end

function manifest = source_hashes(root,sourcePath,configPath)
shared = dir(fullfile(root,'common','*.m'));
paths = [{sourcePath,configPath,'common/plot_time_histories.py.in'}, ...
    arrayfun(@(x)['common/',x.name],shared,'UniformOutput',false).'];
manifest = struct('path',paths,'sha256',cell(size(paths)));
for k = 1:numel(paths)
    if ~usejava('jvm')
        assert(isunix,'Source hashing without the JVM requires the Unix shasum command.');
        quoted = "'" + replace(string(fullfile(root,paths{k})),"'","'""'""'") + "'";
        [status,output] = system(char("shasum -a 256 " + quoted));
        assert(status == 0,'Unable to hash source with shasum: %s',paths{k});
        value = regexp(output,'^[0-9a-f]{64}','match','once');
        assert(~isempty(value),'Invalid source hash for %s.',paths{k});
        manifest(k).sha256 = value;
        continue
    end
    fid = fopen(fullfile(root,paths{k}),'rb');
    assert(fid >= 0,'Cannot read source for provenance: %s',paths{k});
    closer = onCleanup(@()fclose(fid));
    bytes = fread(fid,inf,'*uint8');
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(typecast(bytes,'int8'));
    manifest(k).sha256 = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
    clear closer
end
end

function write_text(path,content)
fid = fopen(path,'w','n','UTF-8');
assert(fid >= 0,'Cannot create documentation: %s',path);
closer = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',content);
end

function text = data_readme(m)
c = m.effective_config;
text = sprintf(['# %s run %s\n\nGenerated UTC: %s. Runtime: MATLAB %s (%s). Solver status: completed.\n\n', ...
    '## Reproduction\n\nFrom the project root, add `%s` to the MATLAB path and call:\n\n```matlab\n%s;\n```\n\n', ...
    'The run ID is reserved: use a new ID when replaying, and restore `effective_config.json` settings ', ...
    'rather than silently using changed defaults. Configuration source: `%s`.\n\n', ...
    'Seed: %d (`%s`); speed: %.17g km/h; solver: %s; RelTol: %.17g; AbsTol: %.17g; ', ...
    'MaxStep: %.17g s; output interval: %.17g s; duration: %.17g s.\n\n', ...
    'The exact effective physical, track, initial-state and refinement settings are recorded in ', ...
    '`effective_config.json` and `metadata.json`. Source SHA-256 values are in `metadata.json`; ', ...
    'no Git revision is asserted. The loaded-equilibrium nonlinear model is described in ', ...
    '`../../../config/suspension_dynamics_configuration.md`.\n\n', ...
    '## Files and units\n\n', ...
    '- `time_histories.csv`: response-grid values; column units are listed below.\n', ...
    '- `track_realization.csv`: full periodic track record; time_s (s), front_track_m/rear_track_m (m), ', ...
    'front_track_velocity_m_s/rear_track_velocity_m_s (m/s).\n', ...
    '- `simulation_results.mat`: states, track, parameters, effective config, metadata and metrics; ', ...
    'TIXS also saves linear/refined states and accelerations.\n', ...
    '- `effective_config.json`: complete settings after explicit positional overrides.\n', ...
    '- `metadata.json`: generation command, runtime, source hashes, units and metrics.\n\n', ...
    '| Column | Unit |\n|---|---|\n'], ...
    m.model,m.run_id,m.generated_utc,m.matlab_version,m.platform, ...
    [m.model,' Suspension'],m.generation_command,m.configuration_source,c.track.seed,c.track.rng_algorithm, ...
    c.track.speed_km_h,c.solver.method,c.solver.rel_tol,c.solver.abs_tol,c.solver.max_step_s, ...
    c.solver.output_step_s,c.solver.duration_s);
for k = 1:numel(m.csv_columns)
    text = [text,sprintf('| `%s` | %s |\n',m.csv_columns{k},m.csv_units{k})]; %#ok<AGROW>
end
text = [text,sprintf('\nPaired figure directory: `../../../%s/`. The plot script reads this CSV directly.\n',m.figure_directory)];
end

function text = pics_readme(m)
text = sprintf(['# %s figures for run %s\n\nPrepared UTC: %s. MATLAB does not render these figures.\n\n', ...
    'Source CSV: `../../../%s/time_histories.csv`. Source metadata and effective configuration: ', ...
    '`../../../%s/metadata.json` and `../../../%s/effective_config.json`.\n\n', ...
    'Run from the project root:\n\n```sh\n%s\n```\n\n', ...
    'Or run this directory\x27s `plot_time_histories.py` from any working directory. ', ...
    'Paths are anchored to the script. Intentional figure regeneration requires `--overwrite`; ', ...
    'this flag does not alter CSV/MAT data.\n\n', ...
    'Matplotlib uses Agg, a 9 by 6 inch (3:2) canvas, explicit Time (s) and acceleration (m/s^2) labels, ', ...
    'and a legend inside comparison axes. Files: `body_acceleration.png` and `body_acceleration.pdf`; ', ...
    'TIXS additionally produces `linear_tixs_acceleration_comparison.png` and `.pdf`. ', ...
    '`plot_metadata.json` records the actual plotting time, Python/NumPy/Matplotlib versions and source paths.\n\n', ...
    'Seed: %d (`%s`). Solver settings, physical units, all overrides and MATLAB runtime are recorded ', ...
    'in the linked data README and metadata. No numerical solver is rerun to change plot styling.\n'], ...
    m.model,m.run_id,m.generated_utc,m.data_directory,m.data_directory,m.data_directory, ...
    m.plot_command,m.effective_config.track.seed,m.effective_config.track.rng_algorithm);
end
