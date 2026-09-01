# Portable PFE UVM Verification Environment

This repository contains a configurable SystemVerilog/UVM environment for the
Package Forward Engine specification. Its protocol model supports compile-time
`LANE_NUM` values 3 through 7. Coverage and performance qualification are
focused on Lane 4 as required.

## What is implemented

- array-based portable PFE interface and a single real-DUT adapter seam;
- backpressure-aware multi-lane input agent;
- PKTIN, reset, and PKTOUT monitors for the integrated-FE top level;
- sequence-number reference model and end-to-end scoreboard;
- recursive dependency calculation through `data_caculate_vip`;
- output data/order, loss, duplicate, timeout, backpressure, and black-box
  performance checks;
- interface SVA plus assertion cover properties;
- functional covergroups and fifteen directed/random tests;
- Lane-4 Golden/candidate performance CSV generation and comparison;
- VCS, Xcelium, and Questa command adapters with assertion checking and
  assertion coverage enabled;
- seed-free regression manifest and an h_regress case adapter.

The default build uses a deterministic open calculation fallback so source can
be inspected. It is not the contest calculation. The default DUT bind terminates
simulation deliberately. A Golden qualification run therefore requires both
the encrypted VIP and a real DUT connection.

## Directory map

```text
env/                 reusable UVM environment, interface, SVA, and sequences
tc/                  UVM tests and the seed-free regression manifest
th/                  harness and the single DUT integration seam
tools/lint/          local syntax-only UVM surface; never compile in production
scripts/             run, h_regress, packaging, performance comparison
docs/                verification plan and internal porting checklist
```

The only simulation root is `harness` in `th/harness.sv`. The DUT module
`EXAM2021_TOP` is instantiated below it through `th/dut_adapter.sv`; the
adapter is not a second simulation top. For an intranet submission, copy
`env/`, `tc/`, and `th/`, then follow the compile order in `sim/files.f`.
Compile exactly one standalone `tc/*.sv` per run, followed by `th/harness.sv`.
Every case registers a class matching its file basename; select it with
`+UVM_TESTNAME=<basename>`. Do not copy `tools/lint/` into the production
compile.

Create a minimal intranet transfer archive with:

```bash
make bundle
```

The archive is written to `out/PFWD_uvm_src.tar.gz`; it contains no RTL,
encrypted VIP, Git history, simulator outputs, or lint-only UVM files.

## Connect EXAM2021_TOP

`EXAM2021_TOP` uses unpacked lane arrays and contains the forwarding engines
internally. Copy `th/dut_bind_example.svh` to `th/dut_bind.svh`, then confirm
the internal definition of the `LANE_WIDTH` macro and the exact ctrl/output port
declarations. The production environment does not connect, drive, or depend on
internal FEIN/FEOUT signals.

The portable runner can then be invoked as follows:

```bash
export SIM=vcs
export DUT_FILELIST=/internal/path/golden.f
export DUT_BIND_DIR=$PWD/th
export VIP_DIR=/internal/path/vip

RTL_KIND=golden LANE_NUM=4 TC=smoke ./scripts/run_test.sh
```

The intranet's fixed scripts may use different variable names; keep those
scripts and reproduce only the source order described in `sim/files.f`.

Every run prints and records a newly generated seed. Supplying `SEED=<value>` is
supported only for local failure reproduction; no checked-in regression entry
fixes a seed. Each complete case (including an uncached compile) has a default
hard wall-clock limit of 1740 seconds, configurable through
`CASE_TIMEOUT_SECONDS`. The final
UVM phase converts any accumulated error/fatal count into `$fatal`, so a DUT
failure cannot silently return a passing process status.

## Golden-first regression

The internal h_regress schema is not available outside the intranet. Map
`tc/testlist.csv` to the site's configuration and use
`scripts/h_regress_case.sh` as the case command. The required public entry point
is:

```bash
H_REGRESS_ARGS='<site configuration arguments>' ./scripts/run_h_regress.sh
```

Run the manifest first with `RTL_KIND=golden`. Configure h_regress to stop the
campaign on the first Golden failure. Only after the complete Golden campaign
passes should the same manifest run with `RTL_KIND=candidate`.

## Lane-4 performance gate

Collect several `performance.sv` CSV files for each RTL, then run:

```bash
python3 scripts/compare_perf.py \
  --golden 'out/runs/golden/lane4/performance/*/pfe_perf.csv' \
  --candidate 'out/runs/candidate/lane4/performance/*/pfe_perf.csv' \
  --report out/perf_comparison.json
```

The command exits nonzero on a performance regression. Thresholds are command
line options rather than hard-coded Golden values.

## Checks possible in this workspace

`make lint` checks the interface/SVA/adapter and syntax-elaborates the complete
UVM source using a lint-only API surface; production simulation never uses that
stub. `make lint-topologies` repeats full elaboration for Lane 3 through Lane 7.
A complete UVM compilation still requires VCS/Xcelium/Questa plus its real
UVM library, and a meaningful simulation additionally requires the internal DUT and encrypted VIP. See
`docs/intranet.md` before the first Golden run.
