#!/usr/bin/env python3
"""Compare candidate performance against its topology-matched reference."""

from __future__ import annotations

import argparse
import csv
import glob
import json
import statistics
from pathlib import Path


IDENTITY_FIELDS = ("lane_num", "accepted", "output")
METRICS = (
    "active_cycles",
    "throughput",
    "avg_e2e",
    "bkpr_ratio",
    "max_bkpr",
    "out_util",
)
REQUIRED_FIELDS = set(IDENTITY_FIELDS + METRICS)


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
                missing = sorted(REQUIRED_FIELDS - row.keys())
                if missing:
                    raise ValueError(
                        f"{name}: missing columns {missing}; rerun the performance test"
                    )
                rows.append(
                    {field: float(row[field]) for field in IDENTITY_FIELDS + METRICS}
                )
    if not rows:
        raise ValueError("performance CSV files contain no data rows")
    return rows


def summarize(rows: list[dict[str, float]]) -> dict[str, float]:
    return {metric: statistics.median(row[metric] for row in rows) for metric in METRICS}


def validate_pair(
    golden_rows: list[dict[str, float]], candidate_rows: list[dict[str, float]]
) -> tuple[int, int]:
    lane_nums = {
        int(row["lane_num"]) for row in golden_rows + candidate_rows
    }
    if len(lane_nums) != 1:
        raise ValueError(f"reference and candidate lane_num values differ: {lane_nums}")

    for label, rows in (("reference", golden_rows), ("candidate", candidate_rows)):
        for row in rows:
            if int(row["accepted"]) != int(row["output"]):
                raise ValueError(
                    f"{label} has accepted={int(row['accepted'])} "
                    f"but output={int(row['output'])}; classify the functional failure first"
                )

    packet_counts = {
        int(row["output"]) for row in golden_rows + candidate_rows
    }
    if len(packet_counts) != 1:
        raise ValueError(
            f"reference and candidate packet counts differ: {packet_counts}"
        )
    return lane_nums.pop(), packet_counts.pop()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--golden", nargs="+", required=True, help="CSV paths/globs")
    parser.add_argument("--candidate", nargs="+", required=True, help="CSV paths/globs")
    parser.add_argument("--min-throughput-ratio", type=float, default=0.90)
    parser.add_argument("--min-output-util-ratio", type=float, default=0.90)
    parser.add_argument("--max-latency-ratio", type=float, default=1.10)
    parser.add_argument("--max-bkpr-delta", type=float, default=0.05)
    parser.add_argument("--max-active-cycles-ratio", type=float, default=1.0)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    golden_rows = load(args.golden)
    candidate_rows = load(args.candidate)
    lane_num, packet_count = validate_pair(golden_rows, candidate_rows)
    golden = summarize(golden_rows)
    candidate = summarize(candidate_rows)
    checks = {
        "active_cycles": {
            "pass": candidate["active_cycles"]
            <= golden["active_cycles"] * args.max_active_cycles_ratio,
            "maximum": golden["active_cycles"] * args.max_active_cycles_ratio,
        },
        "throughput": {
            "pass": candidate["throughput"]
            >= golden["throughput"] * args.min_throughput_ratio,
            "minimum": golden["throughput"] * args.min_throughput_ratio,
        },
        "out_util": {
            "pass": candidate["out_util"]
            >= golden["out_util"] * args.min_output_util_ratio,
            "minimum": golden["out_util"] * args.min_output_util_ratio,
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
    report = {
        "pass": passed,
        "lane_num": lane_num,
        "packet_count": packet_count,
        "golden": golden,
        "candidate": candidate,
        "checks": checks,
    }
    rendered = json.dumps(report, indent=2, sort_keys=True)
    print(rendered)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
