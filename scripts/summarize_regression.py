#!/usr/bin/env python3
"""Summarize simulation cycles, CPU time, Px, and optional Ex."""

from __future__ import annotations

import argparse
import csv
import glob
import json
import re
from pathlib import Path


REAL_RE = re.compile(r"^real\s+([0-9]+(?:\.[0-9]+)?)\s*$")


def cpu_seconds(path: Path) -> float:
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = REAL_RE.match(line.strip())
        if match:
            return float(match.group(1))
    raise ValueError(f"no '/usr/bin/time -p' real line in {path}")


def sim_cycles(path: Path) -> int:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"no performance row in {path}")
    return int(rows[-1]["sim_cycles"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", required=True, help="glob matching run directories")
    parser.add_argument("--coverage-rate", type=float, help="fraction in [0,1]")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    run_dirs = [Path(name) for name in sorted(glob.glob(args.runs)) if Path(name).is_dir()]
    if not run_dirs:
        raise ValueError(f"no run directories matched {args.runs}")
    total_cycles = 0
    total_cpu_seconds = 0.0
    counted = 0
    for run_dir in run_dirs:
        perf = run_dir / "pfe_perf.csv"
        timing = run_dir / "cpu_time.log"
        if not perf.exists() or not timing.exists():
            continue
        total_cycles += sim_cycles(perf)
        total_cpu_seconds += cpu_seconds(timing)
        counted += 1
    if counted == 0:
        raise ValueError("matched directories contain no complete run result")

    cpu_time_ns = total_cpu_seconds * 1.0e9
    report: dict[str, float | int] = {
        "run_count": counted,
        "total_cycles": total_cycles,
        "cpu_time_seconds": total_cpu_seconds,
        "cpu_time_ns": cpu_time_ns,
        "px_cycle_per_cpu_ns": total_cycles / cpu_time_ns if cpu_time_ns else 0.0,
    }
    if args.coverage_rate is not None:
        if not 0.0 <= args.coverage_rate <= 1.0:
            raise ValueError("coverage rate must be in [0,1]")
        report["coverage_rate"] = args.coverage_rate
        report["ex_coverage_per_cycle"] = args.coverage_rate / total_cycles
    rendered = json.dumps(report, indent=2, sort_keys=True)
    print(rendered)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
