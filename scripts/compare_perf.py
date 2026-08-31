#!/usr/bin/env python3
"""Compare Lane-4 candidate performance CSV against Golden RTL results."""

from __future__ import annotations

import argparse
import csv
import glob
import json
import statistics
from pathlib import Path


METRICS = ("throughput", "avg_dispatch", "avg_e2e", "bkpr_ratio", "max_bkpr")


def load(patterns: list[str]) -> list[dict[str, float]]:
    paths = sorted({path for pattern in patterns for path in glob.glob(pattern)})
    if not paths:
        raise ValueError(f"no files matched: {patterns}")
    rows: list[dict[str, float]] = []
    for name in paths:
        with Path(name).open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                if not row or row.get("test") == "test":
                    continue
                rows.append({metric: float(row[metric]) for metric in METRICS})
    if not rows:
        raise ValueError("performance CSV files contain no data rows")
    return rows


def summarize(rows: list[dict[str, float]]) -> dict[str, float]:
    return {metric: statistics.median(row[metric] for row in rows) for metric in METRICS}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--golden", nargs="+", required=True, help="CSV paths/globs")
    parser.add_argument("--candidate", nargs="+", required=True, help="CSV paths/globs")
    parser.add_argument("--min-throughput-ratio", type=float, default=0.90)
    parser.add_argument("--max-latency-ratio", type=float, default=1.10)
    parser.add_argument("--max-bkpr-delta", type=float, default=0.05)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    golden = summarize(load(args.golden))
    candidate = summarize(load(args.candidate))
    checks = {
        "throughput": {
            "pass": candidate["throughput"]
            >= golden["throughput"] * args.min_throughput_ratio,
            "minimum": golden["throughput"] * args.min_throughput_ratio,
        },
        "avg_dispatch": {
            "pass": golden["avg_dispatch"] == 0
            or candidate["avg_dispatch"]
            <= golden["avg_dispatch"] * args.max_latency_ratio,
            "maximum": golden["avg_dispatch"] * args.max_latency_ratio,
        },
        "avg_e2e": {
            "pass": golden["avg_e2e"] == 0
            or candidate["avg_e2e"] <= golden["avg_e2e"] * args.max_latency_ratio,
            "maximum": golden["avg_e2e"] * args.max_latency_ratio,
        },
        "bkpr_ratio": {
            "pass": candidate["bkpr_ratio"]
            <= golden["bkpr_ratio"] + args.max_bkpr_delta,
            "maximum": golden["bkpr_ratio"] + args.max_bkpr_delta,
        },
    }
    passed = all(check["pass"] for check in checks.values())
    report = {"pass": passed, "golden": golden, "candidate": candidate, "checks": checks}
    rendered = json.dumps(report, indent=2, sort_keys=True)
    print(rendered)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
