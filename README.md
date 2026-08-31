# Portable PFE UVM Verification Environment

This repository contains a configurable SystemVerilog/UVM environment for the
Package Forward Engine specification. Its protocol model supports compile-time
`LANE_NUM` values 3 through 7. Coverage and performance qualification are
focused on Lane 4 as required.

## What is implemented

- array-based portable PFE interface and a single real-DUT adapter seam;
- backpressure-aware multi-lane input agent;
- independent FE responder using `data_caculate_vip` and encoded 1–4 cycle
  latency;
- input, FEIN/FEOUT, reset, and PKTOUT monitors;
- sequence-number reference model and end-to-end scoreboard;
- dependency timing, current/dependency data, FE conflict, output data/order,
  loss, duplicate, timeout, and performance checks;
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
tb/interfaces/       signal interface and clocking blocks
tb/agents/           PKTIN, FE, PKTOUT, and reset components
tb/env/              scoreboard, coverage, and UVM environment
tb/seq/              reusable directed and random sequences
tb/tests/            UVM test library
tb/sva/              protocol assertions and assertion coverage
tb/integration/      safe stub and example DUT binding
tb/top/              adapter and UVM top
scripts/             run, bind generation, h_regress, performance comparison
regress/             seed-free test/topology manifest
docs/                verification plan and internal porting checklist
```

## Connect a flattened DUT

The signal names in the problem statement are supported by the bind generator:

```bash
export SIM=vcs
export DUT_FILELIST=/internal/path/golden.f
export DUT_PORT_STYLE=flat
export DUT_MODULE=pfe_golden
export DUT_LANE_PARAM=LANE_NUM
export VIP_DIR=/internal/path/vip

RTL_KIND=golden LANE_NUM=4 TEST=pfe_smoke_test ./scripts/run_test.sh
```

Set `DUT_HAS_LANE_PARAM=0` if the selected top has no lane parameter. For an
array-port DUT, copy `tb/integration/pfe_dut_bind_array.svh.example` to an
external directory as `pfe_dut_bind.svh`, adapt it, and set `DUT_BIND_DIR`.

Every run prints and records a newly generated seed. Supplying `SEED=<value>` is
supported only for local failure reproduction; no checked-in regression entry
fixes a seed. Each complete case (including an uncached compile) has a default
hard wall-clock limit of 1740 seconds, configurable through
`CASE_TIMEOUT_SECONDS`. The final
UVM phase converts any accumulated error/fatal count into `$fatal`, so a DUT
failure cannot silently return a passing process status.

## Golden-first regression

The internal h_regress schema is not available outside the intranet. Map
`regress/pfe_regress.csv` to the site's configuration and use
`scripts/h_regress_case.sh` as the case command. The required public entry point
is:

```bash
H_REGRESS_ARGS='<site configuration arguments>' ./scripts/run_h_regress.sh
```

Run the manifest first with `RTL_KIND=golden`. Configure h_regress to stop the
campaign on the first Golden failure. Only after the complete Golden campaign
passes should the same manifest run with `RTL_KIND=candidate`.

## Lane-4 performance gate

Collect several `pfe_lane4_performance_test` CSV files for each RTL, then run:

```bash
python3 scripts/compare_perf.py \
  --golden 'out/runs/golden/lane4/pfe_lane4_performance_test/*/pfe_perf.csv' \
  --candidate 'out/runs/candidate/lane4/pfe_lane4_performance_test/*/pfe_perf.csv' \
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
`docs/internal-porting-checklist.md` before the first Golden run.
