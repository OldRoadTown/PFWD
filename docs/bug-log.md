# PFE Verification Issue and Bug Log

Last updated: 2026-09-01

This is the persistent record for DUT bugs, verification-environment issues,
coverage gaps, and performance regressions. Update it whenever a new issue is
observed or an existing issue changes status. A Bug RTL simulation is expected
to fail when the environment detects the injected defect; only Golden failures
block qualification.

## Status legend

| Status | Meaning |
|---|---|
| `OPEN` | Evidence exists, but investigation or environment work remains |
| `FOUND` | The environment reliably detects an injected DUT bug |
| `FIXED` | A verification-environment issue was corrected and checked |
| `CLOSED` | Investigation and all required reruns are complete |

## Current qualification baseline

| Item | Result | Status |
|---|---:|---|
| Complete Golden regression | All configured tests passed | Qualified |
| Code coverage | 91.39% | Below closure target |
| Functional coverage | 91.53% | Below closure target |
| Plan coverage | 89.75% | Below required 95% threshold |

The coverage numbers are from the merged Golden Lane-4 regression. Bug RTL and
Lane 3/5/6/7 databases must not be merged into this baseline.

## DUT bug summary

| ID | RTL | Class | Detection | Primary checker | Status |
|---|---|---|---|---|---|
| `DUT-BUG0` | `bug0` | Functional: unknown output control and no progress | `pkt_out_vld` remains X after reset; run eventually times out | `a_known_output_valids`, stimulus watchdog | `FOUND` |
| `DUT-BUG3` | `bug3` | Functional: X/Z observed on output valid/control | Protocol assertion prints an X/Z failure; exact signal and trigger are pending waveform triage | `a_known_output_valids` | `FOUND` |
| `DUT-BUG10` | `bug10` | Pending classification: same output valid/control X/Z checker fired | Must first prove bug10 used a clean, unique RTL build rather than a cached bug3 image | `a_known_output_valids` | `OPEN` |

## DUT-BUG0: output valid remains unknown

### Reproduction

| Field | Value |
|---|---|
| RTL | `bug0` |
| Topology | Lane 4 |
| Testcase | Pending: copy from the failing h_regress task |
| Seed | Pending: copy from the failing simulation log |
| First-failure time/cycle | Pending: copy from the waveform/log |
| Error count | 19 instances of `PFE output valid/control contains X or Z` |
| Terminal failure | `sequence did not complete within 20000 cycles` |

Use a recorded seed only for failure reproduction. Do not place it in the
checked-in regression list.

### Expected behavior

After reset, `pkt_out_vld` must always be a known zero or one. `pkt_out_data`
is meaningful only for lanes whose corresponding valid bit is one.

### Observed behavior

- `pkt_out_vld` is X before reset and remains X after reset is released.
- `pkt_out_data` sometimes changes, but no value can be accepted while its
  valid qualifier is unknown.
- `pkt_in_bkpr` is known and toggles between zero and one.
- Input requests are present and some transfers are accepted.
- No legal PKTOUT progress is observed; the finite stimulus sequence does not
  complete within 20,000 cycles.

### Failure chain

```text
output-valid control remains unknown
  -> output data cannot form a legal transfer
  -> processing makes no usable forward progress
  -> a_known_output_valids reports repeated errors
  -> the stimulus watchdog eventually reports a fatal timeout
```

The repeated errors and final fatal are treated as consequences of one
injected RTL defect, not as twenty independent bugs.

### Root-cause assessment

The black-box evidence is consistent with an output-valid register, queue-valid
state, scheduler selection, or related control state not being initialized or
reset. An incomplete combinational assignment or missing port driver could
produce the same interface symptom. The exact internal RTL line is not yet
proven and is not required for verification closure.

### Verdict and next action

- Verdict: bug0 is reliably detected as a functional bug.
- Do not relax the X/Z assertion or increase the watchdog to make bug0 pass.
- Preserve a screenshot around the first post-reset X and one showing the
  later no-progress interval.
- Fill in testcase, seed, and first-failure time from the internal run.
- Continue with bug1 using coverage collection disabled.

## DUT-BUG3: assertion detects X/Z but UVM initially reported zero errors

### Observed behavior

- The bug3 simulation log contains `PFE output valid/control contains X or Z`.
- The same run originally ended with `UVM_ERROR : 0` because the assertion
  action used SystemVerilog `$error`, which is outside the UVM report server.
- Exact testcase, seed, first-failure time, and the first unknown signal remain
  to be copied from the internal run.

### Verdict and required rerun

The protocol assertion has detected a functional interface failure in bug3.
The zero UVM count was a reporting-integration defect (`ENV-004`), not evidence
that bug3 passed. After the SVA-to-UVM bridge is installed, rerun the complete
Golden regression first, then rerun the failing bug3 testcase. The corrected
run must have a nonzero UVM error count and must not emit `PASSED`.

## DUT-BUG10: same X/Z checker as bug3

Bug10 currently fires the same `a_known_output_valids` assertion as bug3. This
is possible for two independent internal defects because different reset,
queue-valid, scheduler, or port-driver failures can converge on the same
black-box symptom. Before marking bug10 `FOUND`, use a clean build directory,
confirm `compile.log` references only the bug10 RTL filelist, and compare its
first-failure time and output-valid bit pattern with bug3 under the same
reproduction seed. Bit-for-bit identical runs indicate a likely stale/cached
RTL image; distinct traces with the same checker can represent separate bugs.

## Verification-environment issues

| ID | Issue | Impact | Action | Status |
|---|---|---|---|---|
| `ENV-001` | Driver previously acknowledged a request before a low-backpressure acceptance edge | Packet-count mismatch and false Golden timeout | Retain/retry the same item until an actual low-BKPR edge | `FIXED` |
| `ENV-002` | Standalone test packages were not all present in one compiled image | `Requested test ... not found` in h_regress | Compile `tc/tc_pkg.sv` once and select tests only with `+UVM_TESTNAME` | `FIXED` |
| `ENV-003` | Harness imported `tc_pkg` and used package-local `TC_NAME` | Source-order-dependent compile failures | Read `+UVM_TESTNAME` as a string; remove compile-time testcase dependency | `FIXED` |
| `ENV-004` | Protocol SVA action blocks and the final gate used SystemVerilog `$error`/`$fatal`, which are not counted by the UVM report server | Assertion failures could coexist with `UVM_ERROR : 0` and a false pass marker; a fatal timeout could bypass `final_phase` aggregation | Report `uvm_error` directly in each SVA action, retain the interface counter as a fallback, and use `uvm_fatal` for the final gate | `FIXED`, Golden rerun pending |
| `ENV-COV-001` | `bkpr_cg.cp_streak.none` is declared, but the sampler currently records only nonzero streaks | A legal functional-coverage bin is unreachable | Sample zero on cycles with no active backpressure streak, then rerun Golden coverage | `OPEN` |

## Coverage-closure queue

1. Export the names/hierarchies of uncovered plan assertions and functional
   bins from the merged Golden Lane-4 report.
2. Correct `ENV-COV-001` and rerun only the affected directed test first.
3. Map each uncovered assertion to a directed sequence before increasing random
   repeat counts.
4. Re-merge Golden Lane-4 coverage and record the new percentages here.
5. Reach at least 95% plan coverage; target 98% or higher.

## Template for the next DUT bug

Copy this section for each new Bug RTL:

```text
ID / RTL:
Status: OPEN | FOUND | CLOSED
Class: functional | performance | environment
Topology:
Testcase:
Seed (reproduction only):
First failure time/cycle:
First error/checker:
Expected behavior:
Observed behavior:
Golden comparison:
Waveform evidence:
Terminal symptom:
Root-cause hypothesis:
Action taken:
Golden rerun result after environment changes:
```

## Iteration rules

1. Diagnose the first failure, not the final cascade symptom.
2. Compare against Golden with the same topology and environment before calling
   an observation a DUT bug.
3. Record functional failures and performance-only regressions separately.
4. Any checker, sequence, assertion, or coverage-model change requires a fresh
   Golden qualification before rerunning Bug RTL.
5. Never merge Bug RTL coverage into the Golden coverage result.
6. Keep regression seeds random; record a seed only to reproduce a failure.
