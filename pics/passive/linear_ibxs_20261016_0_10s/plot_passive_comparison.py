"""Derive passive comparison data and plot saved CSVs; never run an ODE."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import platform
import tempfile
import time
from datetime import datetime, timezone

import numpy as np

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[3]
CONFIG_PATH = ROOT / 'config' / 'passive_linear_ibxs_20261016.json'
CFG = json.loads(CONFIG_PATH.read_text())
DATA = ROOT / CFG['data_directory']
FIGURES = ROOT / CFG['figure_directory']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def relative(path):
    return Path(path).relative_to(ROOT).as_posix()


def finite(a):
    assert np.isfinite(np.asarray(a, dtype=float)).all(), 'NaN/Inf rejected'


def read_numeric(path):
    a = np.genfromtxt(path, names=True, delimiter=',', encoding='utf-8')
    assert a.ndim == 1 and len(a) > 1, f'Invalid CSV: {path}'
    for name in a.dtype.names:
        finite(a[name])
    return a


def write_json(path, content):
    path.write_text(json.dumps(content, indent=2, allow_nan=False) + '\n')


def output_check(paths, overwrite):
    for path in paths:
        if path.exists() and not overwrite:
            raise FileExistsError(f'Existing result: {relative(path)}; use --overwrite for explicit regeneration')


def rms(a, t):
    return float(np.sqrt(np.trapezoid(a*a, t) / (t[-1]-t[0])))


def source_data():
    directories = [ROOT / CFG[k] for k in ('source_ibxs_directory', 'source_linear_directory')]
    arrays = [read_numeric(d / 'time_histories.csv') for d in directories]
    metas = [json.loads((d / 'metadata.json').read_text()) for d in directories]
    configs = [json.loads((d / 'effective_config.json').read_text()) for d in directories]
    provenance_checks = []
    for meta in metas:
        assert meta['solver_status'] == 'completed'
        assert meta['run_id'] == CFG['source_run_id']
        for entry in meta['source_sha256']:
            current_hash = sha(ROOT / entry['path'])
            numerical = entry['path'] not in CFG['non_numerical_provenance_files']
            if numerical:
                assert current_hash == entry['sha256'], f'Numerical source changed: {entry["path"]}'
            provenance_checks.append({'path': entry['path'], 'numerical': numerical,
                                      'original_sha256': entry['sha256'], 'current_sha256': current_hash})
    for key in ('vehicle', 'track', 'solver'):
        assert configs[0][key] == configs[1][key], f'Different source {key}'
    for config in configs:
        assert config['track']['seed'] == 127
        assert config['track']['rng_algorithm'] == 'twister'
        assert not any(config['solver']['initial_state'])
    for key in ('k', 'c'):
        assert configs[0]['secondary'][key] == configs[1]['secondary'][key]
    x, y = arrays
    assert len(x) == len(y) == CFG['expected_samples']
    comparisons = {'source_hash_checks': provenance_checks}
    for name in ('time_s', 'front_track_m', 'rear_track_m',
                 'front_track_velocity_m_s', 'rear_track_velocity_m_s'):
        error = float(np.max(np.abs(x[name]-y[name])))
        limit = CFG['time_comparison_atol_s'] if name == 'time_s' else CFG['track_comparison_atol']
        assert error <= limit, f'Incompatible {name}: {error}'
        comparisons[name + '_max_abs_difference'] = error
    t = x['time_s']
    assert np.allclose(t[[0, -1]], CFG['time_interval_s'], rtol=0, atol=1e-12)
    assert np.allclose(np.diff(t), CFG['sample_interval_s'], rtol=0, atol=1e-12)
    # Reversing the pitch coordinate maps the linear incidence matrices.
    # The vertical linear input/output map is invariant when BOTH its input
    # and output are interpreted in the downward-positive convention.
    d = configs[0]['vehicle']['d']
    b_ibxs = np.array([[1, 1], [-d, d], [-1, 0], [0, -1]])
    b_linear = np.array([[1, 1], [d, -d], [-1, 0], [0, -1]])
    transform = np.diag([1, -1, 1, 1])
    assert np.array_equal(transform @ b_linear, b_ibxs)
    comparisons['linear_pitch_incidence_mapping'] = 'pass'
    a = np.column_stack((y['linear_body_vertical_acceleration_m_s2'],
                         x['body_vertical_acceleration_m_s2']))
    return t, a, x, directories, metas, configs, comparisons


def welch(a, fs, nwin, overlap, nfft):
    """One-sided density with independent Parseval energy validation."""
    assert 0 <= overlap < nwin <= len(a) and nfft >= nwin and nfft % 2 == 0
    window = np.hanning(nwin)
    starts = list(range(0, len(a)-nwin+1, nwin-overlap))
    powers, energies = [], []
    for start in starts:
        segment = a[start:start+nwin]
        weighted = (segment-segment.mean()) * window
        p = np.abs(np.fft.rfft(weighted, n=nfft))**2 / (fs * np.sum(window**2))
        p[1:-1] *= 2
        powers.append(p)
        energies.append(np.sum(weighted**2) / np.sum(window**2))
    p = np.mean(powers, axis=0)
    f = np.fft.rfftfreq(nfft, 1/fs)
    integrated = float(p.sum() * fs / nfft)
    expected = float(np.mean(energies))
    error = abs(integrated-expected) / expected
    assert error < 1e-12, 'PSD normalization failed Parseval validation'
    finite(p)
    assert (p > 0).all(), 'Nonpositive PSD rejected; no artificial log floor'
    return f, p, {'segment_count': len(starts), 'start_indices_zero_based': starts,
                  'unused_tail_samples': len(a)-(starts[-1]+nwin),
                  'integrated_psd_m2_s4': integrated,
                  'window_weighted_detrended_mean_square_m2_s4': expected,
                  'parseval_relative_error': error}


def smoke(overwrite):
    path = DATA / 'smoke_verification.json'
    output_check([path], overwrite)
    t, a, _, _, _, _, comparisons = source_data()
    mask = t <= 1.0
    assert mask.sum() == 501
    sample = np.column_stack((t[mask], a[mask]))
    finite(sample)
    with tempfile.TemporaryDirectory(prefix='srtp_passive_smoke_') as tmp:
        p = Path(tmp) / 'sample.csv'
        np.savetxt(p, sample, delimiter=',', header='time_s,linear_m_s2,ibxs_m_s2', comments='')
        restored = read_numeric(p)
        assert np.array_equal(restored['linear_m_s2'], sample[:, 1])
        assert np.array_equal(restored['ibxs_m_s2'], sample[:, 2])
    fs = 512
    ts = np.arange(fs) / fs
    f, p, validation = welch(np.sin(2*np.pi*16*ts), fs, 256, 128, 1024)
    assert abs(f[np.argmax(p)]-16) <= fs/1024
    assert abs(validation['integrated_psd_m2_s4']-0.5) < 1e-5
    report = {'status': 'pass', 'gate': 'postprocessing_smoke_no_ode',
              'time_interval_s': [0, 1], 'samples': int(mask.sum()),
              'csv_roundtrip': 'pass', 'source_compatibility': comparisons,
              'sinusoid_peak_frequency_hz': float(f[np.argmax(p)]),
              'sinusoid_power_expected': 0.5, 'sinusoid_validation': validation,
              'script_sha256': sha(SCRIPT), 'config_sha256': sha(CONFIG_PATH)}
    write_json(path, report)
    print(json.dumps(report, indent=2))


def prepare(overwrite):
    start = time.perf_counter()
    paths = [DATA / name for name in ('vertical_acceleration_time_histories.csv',
             'vertical_acceleration_rms.csv', 'vertical_acceleration_psd.csv', 'analysis_metadata.json')]
    output_check(paths, overwrite)
    gate = json.loads((DATA / 'smoke_verification.json').read_text())
    assert gate['status'] == 'pass' and gate['script_sha256'] == sha(SCRIPT)
    assert gate['config_sha256'] == sha(CONFIG_PATH), 'Run smoke after any code/config change'
    t, a, track, directories, metas, configs, comparisons = source_data()
    fs = 1 / CFG['sample_interval_s']
    settings = CFG['psd']
    estimates = [welch(a[:, i], fs, settings['window_samples'],
                      settings['overlap_samples'], settings['nfft']) for i in range(2)]
    assert np.array_equal(estimates[0][0], estimates[1][0])
    f = estimates[0][0]
    psd = np.column_stack([result[1] for result in estimates])
    db = 10*np.log10(psd / settings['db_reference_m2_s4_per_hz'])
    r = [rms(a[:, i], t) for i in range(2)]
    references = [metas[1]['metrics']['linear_rms10_m_s2'], metas[0]['metrics']['rms_0_10_s_m_s2']]
    assert np.allclose(r, references, rtol=0, atol=CFG['rms_reference_atol_m_s2'])
    reduction = [0.0, 100*(1-r[1]/r[0])]
    histories = np.column_stack((t, a, track['front_track_m'], track['rear_track_m']))
    spectra = np.column_stack((f, psd, db))
    for values in (histories, spectra, r, reduction):
        finite(values)
    # All full data, estimator and metadata checks succeed before exporting.
    np.savetxt(paths[0], histories, delimiter=',', fmt='%.17g', comments='',
               header='time_s,linear_vertical_acceleration_m_s2,ibxs_vertical_acceleration_m_s2,front_track_m,rear_track_m')
    with paths[1].open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['model', 'start_time_s', 'end_time_s', 'sample_count',
                         'rms_vertical_acceleration_m_s2', 'peak_abs_vertical_acceleration_m_s2',
                         'rms_reduction_vs_linear_percent'])
        for i, model in enumerate(('Linear', 'IBXS')):
            writer.writerow([model, t[0], t[-1], len(t), r[i], float(np.max(np.abs(a[:, i]))), reduction[i]])
    np.savetxt(paths[2], spectra, delimiter=',', fmt='%.17g', comments='',
               header='frequency_hz,linear_psd_m2_s4_per_hz,ibxs_psd_m2_s4_per_hz,linear_psd_db_re_1_m2_s4_per_hz,ibxs_psd_db_re_1_m2_s4_per_hz')
    sources = [d / name for d in directories for name in ('time_histories.csv',
               'track_realization.csv', 'effective_config.json', 'metadata.json')]
    metadata = {
        'run_id': CFG['run_id'], 'operation': CFG['operation'],
        'generated_utc': datetime.now(timezone.utc).isoformat(),
        'python': platform.python_version(), 'numpy': np.__version__,
        'config_path': relative(CONFIG_PATH), 'config_sha256': sha(CONFIG_PATH),
        'script_path': relative(SCRIPT), 'script_sha256': sha(SCRIPT),
        'git_revision': 'see source_metadata and SHA-256 snapshots; no commit assumed',
        'sources': {relative(path): sha(path) for path in sources},
        'source_metadata': metas, 'source_effective_configs': configs,
        'common_coordinate': CFG['common_coordinate'],
        'linear_coordinate_mapping': CFG['linear_coordinate_mapping'],
        'sample_count': len(t), 'sample_rate_hz': fs, 'rms_m_s2': dict(zip(('Linear', 'IBXS'), r)),
        'ibxs_rms_reduction_vs_linear_percent': reduction[1],
        'rms_reference_absolute_errors_m_s2': [abs(x-y) for x, y in zip(r, references)],
        'source_compatibility': comparisons, 'welch_settings': settings,
        'welch_validation': dict(zip(('Linear', 'IBXS'), [x[2] for x in estimates])),
        'frequency_grid_step_hz': fs/settings['nfft'],
        'window_frequency_resolution_hz': fs/settings['window_samples'],
        'finite_before_export': 'pass', 'physical_parameters': 'unchanged',
        'ode_rerun': False, 'verification_gate': 'plot_only_bypass_with_postprocessing_smoke',
        'smoke_report': relative(DATA/'smoke_verification.json'),
        'full_postprocessing_validation': 'pass',
        'exported_csv_sha256': {relative(path): sha(path) for path in paths[:3]},
        'postprocessing_runtime_seconds': time.perf_counter()-start,
    }
    write_json(paths[3], metadata)
    print(json.dumps({'rms_m_s2': metadata['rms_m_s2'], 'reduction_percent': reduction[1],
                      'gate': metadata['verification_gate'], 'finite': 'pass',
                      'welch_validation': metadata['welch_validation']}, indent=2))


def plot(overwrite):
    # Plotting consumes saved CSVs only and has no simulation dependency.
    os.environ.setdefault('MPLCONFIGDIR', str(Path(tempfile.gettempdir())/'srtp_passive_mpl_cache'))
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.ticker import AutoMinorLocator, FixedLocator, LogLocator, NullFormatter
    from matplotlib.transforms import Bbox

    names = ['vertical_acceleration_time_comparison', 'vertical_acceleration_psd_comparison',
             'vertical_acceleration_combined_comparison']
    outputs = [FIGURES/(name+'.'+ext) for name in names for ext in CFG['figure']['formats']]
    output_check(outputs+[FIGURES/'plot_metadata.json'], overwrite)
    history_path = DATA/'vertical_acceleration_time_histories.csv'
    psd_path = DATA/'vertical_acceleration_psd.csv'
    rms_path = DATA/'vertical_acceleration_rms.csv'
    csv_hashes_before = {relative(path): sha(path) for path in (history_path, rms_path, psd_path)}
    history, spectrum = read_numeric(history_path), read_numeric(psd_path)
    with rms_path.open() as stream:
        rows = list(csv.DictReader(stream))
    assert [row['model'] for row in rows] == ['Linear', 'IBXS']
    values = [float(row['rms_vertical_acceleration_m_s2']) for row in rows]
    finite(values)
    for i, key in enumerate(('linear', 'ibxs')):
        assert abs(rms(history[key+'_vertical_acceleration_m_s2'], history['time_s'])-values[i]) < 1e-12
        assert np.allclose(spectrum[key+'_psd_db_re_1_m2_s4_per_hz'],
                           10*np.log10(spectrum[key+'_psd_m2_s4_per_hz']), rtol=0, atol=1e-12)
    style = CFG['figure']
    plt.rcParams.update({'font.family': style['font'], 'font.size': 13,
                         'axes.labelsize': 15, 'xtick.labelsize': 12, 'ytick.labelsize': 12,
                         'legend.fontsize': 12, 'axes.linewidth': style['spine_width_pt'], 'pdf.fonttype': 42,
                         'mathtext.fontset': 'stix', 'savefig.facecolor': 'white'})

    figure_checks = {}

    def style_axes(ax):
        for spine in ax.spines.values():
            spine.set_linewidth(style['spine_width_pt'])
        ax.tick_params(which='both', direction='in', top=True, right=True)
        ax.tick_params(which='major', length=6, pad=style['tick_label_padding_pt'])
        ax.tick_params(which='minor', length=3)
        ax.yaxis.set_minor_locator(AutoMinorLocator(2))
        ax.set_box_aspect(1/style['panel_width_height_ratio'])

    def canvas():
        fig = plt.figure(figsize=style['size_inches'])
        ax = fig.add_axes(style['standalone_axes_position'])
        style_axes(ax)
        return fig, ax

    def save(fig, name):
        fig.canvas.draw()
        panel_checks = []
        for ax in fig.axes:
            assert [line.get_linewidth() for line in ax.lines] == [1.2, 1.6]
            assert [line.get_linestyle() for line in ax.lines] == ['-', '-']
            assert all(spine.get_linewidth() == 1.0 for spine in ax.spines.values())
            labels = [text.get_text() for text in ax.get_legend().get_texts()]
            assert labels == style['legend_labels'] and all('RMS' not in label for label in labels)
            bounds = ax.get_window_extent(fig.canvas.get_renderer())
            assert abs(bounds.width/bounds.height-style['panel_width_height_ratio']) < 1e-12
            assert ax.lines[0].get_color() == '#2B2D42'
            if ax.get_xscale() == 'log':
                x_label = ax.get_xticklabels()[0].get_window_extent(fig.canvas.get_renderer())
                y_label = ax.get_yticklabels()[0].get_window_extent(fig.canvas.get_renderer())
                assert not x_label.overlaps(y_label), 'PSD corner tick labels overlap'
            panel_checks.append({'axes_position': list(ax.get_position().bounds),
                                 'width_height_ratio': bounds.width/bounds.height,
                                 'line_widths_pt': [line.get_linewidth() for line in ax.lines],
                                 'line_styles': [line.get_linestyle() for line in ax.lines],
                                 'linear_color': ax.lines[0].get_color(),
                                 'spine_width_pt': 1.0, 'legend_labels': labels})
        # The same tight artist bounds used by bbox_inches='tight', with only
        # the minimal additional padding needed for a 1.3:1 standalone export.
        tight = fig.get_tightbbox(fig.canvas.get_renderer()).padded(style['export_tight_padding_inches'])
        if len(fig.axes) == 1:
            ratio = style['standalone_export_width_height_ratio']
            height_pixels = int(np.ceil(max(tight.height, tight.width/ratio)*style['dpi']/10))*10
            width_pixels = height_pixels*13//10
            width, height = width_pixels/style['dpi'], height_pixels/style['dpi']
            tight = Bbox.from_bounds(tight.x0-(width-tight.width)/2,
                                     tight.y0-(height-tight.height)/2, width, height)
        figure_checks[name] = {'size_inches': list(fig.get_size_inches()),
                              'export_size_inches': [tight.width, tight.height],
                              'png_pixels': [int(tight.width*style['dpi']), int(tight.height*style['dpi'])],
                              'export_width_height_ratio': tight.width/tight.height,
                              'tight_margins': True,
                              'panels': panel_checks}
        for ext in style['formats']:
            fig.savefig(FIGURES/(name+'.'+ext), dpi=style['dpi'], bbox_inches=tight, pad_inches=0)
        plt.close(fig)

    def draw_time(ax):
        for i, key in enumerate(('linear', 'ibxs')):
            ax.plot(history['time_s'], history[key+'_vertical_acceleration_m_s2'],
                    color=style[key+'_color'], lw=style[key+'_linewidth_pt'],
                    ls=style['linestyle'], label=style['legend_labels'][i])
        ax.set(xlim=CFG['time_interval_s'], xlabel='Time (s)',
               ylabel='Car-body vertical acceleration (m/s$^2$)')
        maximum = max(np.max(np.abs(history[key+'_vertical_acceleration_m_s2'])) for key in ('linear', 'ibxs'))
        top = np.ceil(maximum/0.5)*0.5 + 0.35
        ax.set_ylim(-top, top)
        ax.xaxis.set_major_locator(FixedLocator([0, 2, 4, 6, 8, 10]))
        ax.xaxis.set_minor_locator(AutoMinorLocator(2))
        ax.yaxis.set_major_locator(FixedLocator(np.arange(-1.5, 1.51, 0.5)))
        ax.legend(loc='upper right', frameon=True, edgecolor='none', framealpha=0.95)

    def draw_psd(ax):
        for i, key in enumerate(('linear', 'ibxs')):
            ax.plot(spectrum['frequency_hz'], spectrum[key+'_psd_db_re_1_m2_s4_per_hz'],
                    color=style[key+'_color'], lw=style[key+'_linewidth_pt'],
                    ls=style['linestyle'], label=style['legend_labels'][i])
        ax.set_xscale('log')
        ax.set_xlim(CFG['psd']['plot_frequency_limits_hz'])
        ticks = CFG['psd']['plot_frequency_ticks_hz']
        ax.xaxis.set_major_locator(FixedLocator(ticks))
        ax.set_xticklabels([f'{value:g}' for value in ticks])
        ax.xaxis.set_minor_locator(LogLocator(base=10, subs=np.arange(2, 10)*0.1))
        ax.xaxis.set_minor_formatter(NullFormatter())
        ax.get_xticklabels()[0].set_horizontalalignment('left')
        ax.get_xticklabels()[-1].set_horizontalalignment('right')
        ax.set_xlabel('Frequency (Hz)')
        ax.set_ylabel('PSD of car-body vertical acceleration\n(dB re 1 (m/s$^2$)$^2$/Hz)')
        mask = (spectrum['frequency_hz'] >= ticks[0]) & (spectrum['frequency_hz'] <= ticks[-1])
        shown = np.concatenate([spectrum[key+'_psd_db_re_1_m2_s4_per_hz'][mask] for key in ('linear', 'ibxs')])
        ax.set_ylim(10*np.floor(shown.min()/10), 10*np.ceil(shown.max()/10)+10)
        ax.legend(loc='upper right', frameon=True, edgecolor='none', framealpha=0.95)

    fig, ax = canvas()
    draw_time(ax)
    save(fig, names[0])

    fig, ax = canvas()
    draw_psd(ax)
    save(fig, names[1])

    fig = plt.figure(figsize=style['combined_size_inches'])
    axes = [fig.add_axes(position) for position in style['combined_axes_positions']]
    for ax, draw, panel in zip(axes, (draw_time, draw_psd), ('(a)', '(b)')):
        style_axes(ax)
        draw(ax)
        ax.text(0, 1.035, panel, transform=ax.transAxes, fontsize=14, va='bottom')
    first, second = [ax.get_position() for ax in axes]
    assert np.allclose([first.y0, first.y1, first.width, first.height],
                       [second.y0, second.y1, second.width, second.height], rtol=0, atol=1e-14)
    assert style['shared_caption'] is None and not fig.texts
    save(fig, names[2])
    csv_hashes_after = {relative(path): sha(path) for path in (history_path, rms_path, psd_path)}
    assert csv_hashes_before == csv_hashes_after, 'Plotting modified numerical data'
    metadata = {'run_id': CFG['run_id'], 'generated_utc': datetime.now(timezone.utc).isoformat(),
                'python': platform.python_version(), 'numpy': np.__version__,
                'matplotlib': matplotlib.__version__, 'backend': matplotlib.get_backend(),
                'script_sha256': sha(SCRIPT), 'config_sha256': sha(CONFIG_PATH),
                'source_csv_sha256': {relative(path): sha(path) for path in (history_path, rms_path, psd_path)},
                'figure_size_inches': style['size_inches'],
                'style_revision_date_local': style['style_revision_date_local'],
                'intentional_figure_regeneration': overwrite,
                'figure_checks': figure_checks,
                'combined_layout': style['combined_layout'], 'shared_caption': style['shared_caption'],
                'panel_alignment': 'pass', 'csv_unchanged_by_plotting': 'pass',
                'psd_xscale': 'log', 'psd_yscale': 'linear_dB',
                'finite_csv_validation': 'pass', 'ode_rerun': False,
                'outputs_sha256': {relative(path): sha(path) for path in outputs}}
    write_json(FIGURES/'plot_metadata.json', metadata)
    print('\n'.join(relative(path) for path in outputs))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('smoke', 'prepare', 'plot'))
    parser.add_argument('--overwrite', action='store_true', help='Explicitly regenerate this unchanged run')
    args = parser.parse_args()
    {'smoke': smoke, 'prepare': prepare, 'plot': plot}[args.action](args.overwrite)
