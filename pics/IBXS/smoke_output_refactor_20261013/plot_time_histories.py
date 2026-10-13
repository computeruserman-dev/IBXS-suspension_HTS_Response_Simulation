"""Run-local Matplotlib script; paths are resolved from this file, not cwd."""
from pathlib import Path
import argparse
import datetime
import json
import hashlib
import platform

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overwrite", action="store_true", help="Intentionally regenerate existing figures.")
    args = parser.parse_args()
    figure_dir = Path(__file__).resolve().parent
    project_root = figure_dir.parents[2]
    model = figure_dir.parent.name
    run_id = figure_dir.name
    data_dir = project_root / "data" / model / run_id
    csv_path = data_dir / "time_histories.csv"
    metadata_path = data_dir / "metadata.json"
    if not csv_path.is_file() or not metadata_path.is_file():
        raise FileNotFoundError(f"Missing run CSV or metadata in {data_dir}")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if metadata["model"] != model or metadata["run_id"] != run_id:
        raise ValueError("Run metadata does not match the script directory.")
    values = np.atleast_1d(np.genfromtxt(csv_path, delimiter=",", names=True))
    if not np.isfinite(np.column_stack([values[n] for n in values.dtype.names])).all():
        raise ValueError("CSV contains NaN or Inf.")
    response = "body_vertical_acceleration_m_s2" if model == "IBXS" else "tixs_body_vertical_acceleration_m_s2"
    required = ["time_s", response]
    if model == "TIXS":
        required.append("linear_body_vertical_acceleration_m_s2")
    if not all(name in values.dtype.names for name in required):
        raise ValueError(f"Missing required columns: {required}")
    time = values["time_s"]
    if len(time) < 2 or np.any(np.diff(time) <= 0):
        raise ValueError("Time must contain at least two strictly increasing samples.")
    stems = ["body_acceleration"]
    if model == "TIXS":
        stems.append("linear_tixs_acceleration_comparison")
    destinations = [figure_dir / f"{stem}.{ext}" for stem in stems for ext in ("png", "pdf")]
    record = figure_dir / "plot_metadata.json"
    if not args.overwrite and any(p.exists() for p in destinations + [record]):
        raise FileExistsError("Figures already exist; use --overwrite for intentional regeneration.")
    plt.rcParams.update({"font.family": "DejaVu Serif", "font.size": 12, "axes.linewidth": 0.8})
    for stem in stems:
        fig, ax = plt.subplots(figsize=(9, 6), layout="constrained")
        if stem == "linear_tixs_acceleration_comparison":
            ax.plot(time, values["linear_body_vertical_acceleration_m_s2"], color="#777777", linewidth=0.8, label="Conventional linear suspension")
            ax.plot(time, values[response], color="#1f4875", linewidth=0.8, label="Passive TIXS")
            ax.legend(loc="best", framealpha=0.9)
        else:
            ax.plot(time, values[response], color="#1f4875", linewidth=0.8)
        ax.set(xlabel="Time (s)", ylabel="Car-body vertical acceleration (m/s²)", xlim=(time[0], time[-1]), title=f"{model}: {time[0]:g}–{time[-1]:g} s response")
        ax.grid(alpha=0.25)
        for extension in ("png", "pdf"):
            fig.savefig(figure_dir / f"{stem}.{extension}", dpi=200)
        plt.close(fig)
    command = f"python3 pics/{model}/{run_id}/plot_time_histories.py" + (" --overwrite" if args.overwrite else "")
    plot_metadata = {
        "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "python": platform.python_version(), "numpy": np.__version__, "matplotlib": matplotlib.__version__,
        "command": command, "source_csv": csv_path.relative_to(project_root).as_posix(),
        "source_metadata": metadata_path.relative_to(project_root).as_posix(),
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "source_csv_sha256": hashlib.sha256(csv_path.read_bytes()).hexdigest(),
        "seed": metadata["effective_config"]["track"]["seed"],
        "solver": metadata["effective_config"]["solver"],
        "figure_size_inches": [9, 6], "intentional_regeneration": args.overwrite,
        "outputs": [p.relative_to(project_root).as_posix() for p in destinations],
    }
    record.write_text(json.dumps(plot_metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Rendered {len(destinations)} figures for {model}/{run_id}")


if __name__ == "__main__":
    main()
