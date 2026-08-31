# PFE Verification Plan

## 1. Scope and observable reference model

The environment treats every packet accepted on `PKTIN` as a transaction with
an internal 64-bit sequence number. Packets accepted in one cycle are numbered
in ascending input-lane order. The expected forwarding result is computed as:

```text
source(seq) = input_data(seq)                                  when dp == 0
source(seq) = input_data(seq) XOR result(seq-dp)                when dp != 0
result(seq) = data_caculate_vip(source(seq), encoded_latency)
```

The output scoreboard consumes exactly one global sequence. Therefore lane,
data, duplicate, unexpected, dropped, and out-of-order failures are diagnosed
independently.

## 2. Checkers

| Requirement | Checker | Failure class |
|---|---|---|
| Same-cycle input order is lane 0 to N-1 | PKTIN monitor sequence reconstruction | stimulus/protocol |
| `dp` references an earlier packet within seven | input reference model | dependency |
| FEIN current data and latency belong to an accepted packet | FE request matcher | dispatch |
| FEIN dependency valid/data are exact | FE request matcher | dependency/data |
| Dependent FEIN occurs no earlier than the cycle after FEOUT | completion-cycle check | dependency timing |
| One outstanding request per FE instance | FE responder and scoreboard | FE conflict |
| FEOUT result equals independent VIP calculation | FE response checker | FE data/model |
| PKTOUT data equals processed result | end-to-end scoreboard | data |
| PKTOUT lane equals `seq % LANE_NUM` | monitor, scoreboard, SVA | order |
| PKTOUT valid mask is cyclically contiguous | monitor and SVA | order |
| Accepted/output counts match | check phase and watchdog | drop/duplicate/deadlock |
| Interface values are known when valid | per-lane SVA | protocol |
| Reset output behavior | SVA and reset monitor | reset |
| Bounded visible progress | SVA and cycle watchdog | hang/starvation |

## 3. Functional coverage

The class coverage model samples LANE topology, accepted packet count, lane
bitmap and bitmap class, each input lane, latency, dependency distance,
latency/dependency crosses, lane/latency/dependency crosses, dependency chain
depth, dependency fan-out, FE lane and parallelism, output count/start/wrap, and
backpressure streak length.

SVA cover properties independently cover per-lane traffic, all latency and
dependency encodings, idle gaps, short/medium/long backpressure, output wrap,
all-FE concurrency, all-output concurrency, and reset re-entry.

Only Lane-4 runs in `regress/pfe_regress.csv` request coverage collection. The
other topologies establish configurability without multiplying coverage data.

## 4. Directed tests

| Test | Primary intent |
|---|---|
| `pfe_smoke_test` | short mixed dependency/latency traffic |
| `pfe_lane_config_test` | common environment on Lane 3 through Lane 7 |
| `pfe_no_dependency_test` | independent scheduling and throughput |
| `pfe_dependency_distance_test` | every dependency distance 0 through 7 |
| `pfe_dependency_chain_test` | serialized long dependency chain |
| `pfe_dependency_fanout_test` | seven packets sharing one result |
| `pfe_latency_matrix_test` | latency × dependency combinations |
| `pfe_sparse_lane_test` | all nonzero input lane bitmaps and idle gaps |
| `pfe_output_wraparound_test` | output cursor crossings with varying beat sizes |
| `pfe_backpressure_stress_test` | saturated high-latency traffic |
| `pfe_fe_parallel_completion_test` | simultaneous FE use/completion pressure |
| `pfe_scheduler_corner_test` | slow roots, dependents, and free traffic mixed |
| `pfe_reset_test` | legal reset, model flush, and post-reset traffic |
| `pfe_constrained_random_test` | bounded randomized lane/latency/dependency mix |
| `pfe_lane4_performance_test` | deterministic control-pattern performance baseline |

## 5. Performance criteria

Lane-4 performance records throughput, dispatch wait average/maximum, end-to-end
latency average/maximum, backpressure ratio/maximum streak, FE dispatch slots,
output slots, observed cycles, and packet balance. The directed performance
sequence does not make scheduling depend on random payload values, so Golden
and candidate runs need not reuse a fixed seed.

Candidate failure is automatic when any configured condition is violated:

- throughput is below the Golden median multiplied by the minimum ratio;
- dispatch or end-to-end latency exceeds the Golden median multiplied by the
  maximum ratio;
- backpressure ratio exceeds Golden by the configured absolute delta.

Use several Golden samples and several candidate samples with
`scripts/compare_perf.py`; it compares medians to reduce host-load noise.

## 6. Closure procedure

1. Run the complete manifest against Golden RTL and stop on any error.
2. Merge only Lane-4 assertion and functional coverage databases.
3. Inspect uncovered assertion names and map each to an existing test.
4. Tighten or add a directed sequence before increasing random repeat counts.
5. Record Golden Lane-4 performance samples.
6. Run candidate RTL and apply the functional plus performance gates.
7. Reproduce failures with the seed printed in `PFE_RUN`, without placing that
   seed in the checked-in regression configuration.
