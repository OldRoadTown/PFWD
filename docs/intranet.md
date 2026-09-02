# Internal Porting Checklist

Only `env/`, `tc/`, and `th/` are verification source directories. The single
simulation root is `harness` in `th/harness.sv`; `EXAM2021_TOP` is the DUT
instantiated below it. Keep the site's fixed scripts and add the following
compile order to the site filelist:

```text
+incdir+env
+incdir+tc
+incdir+th
env/pfe_if.sv
env/env_pkg.sv
env/protocol_sva.sv
th/dut_adapter.sv
tc/tc_pkg.sv
th/harness.sv
```

`tc/tc_pkg.sv` includes all testcase class bodies and registers them with the
UVM factory. Compile it once and select the required class at runtime:

```text
+UVM_TESTNAME=smoke
+UVM_TESTNAME=latency
+UVM_TESTNAME=dep_chain
```

Do not add `tc/smoke.sv`, `tc/latency.sv`, or any other included class-body
file to `env.f` or to an individual regression job. Those files are source
includes owned by `tc/tc_pkg.sv`, not independent compilation units.

The production compile also needs `+define+PFE_REAL_DUT`,
`+define+PFE_USE_REAL_DATA_VIP`, and the encrypted VIP include directory. If
the RTL filelist defines a cumulative `LANE_2` through `LANE_7` selector, place
that filelist before `env/pfe_if.sv`; the environment derives `PFE_LANE_NUM`
from the highest visible selector. A regression may still define
`PFE_LANE_NUM` explicitly, in which case the harness checks it against the RTL
selector and stops on a mismatch. Do not compile `tools/lint/` in the intranet
flow.

The source framework is ready for site integration; these are the steps that
cannot be verified outside the intranet without the Golden RTL and encrypted
VIP.

1. Use `harness` as the only simulation root. The DUT module is
   `EXAM2021_TOP` and its forwarding engines are integrated internally.
2. Supply the DUT filelist through `DUT_FILELIST`.
3. Copy `th/dut_bind_example.svh` to `dut_bind.svh`; confirm the `LANE_WIDTH`
   and all unpacked-array declarations before compiling.
4. Connect only PKTIN, PKTOUT, BKPR, clock, and reset. Do not drive internal
   FEIN/FEOUT signals because the integrated forwarding engines already do so.
5. Put `data_caculate_vip.sv` in `VIP_DIR`. If the encrypted file cannot be
   included inside a package, change only `env/data_vip.svh` to match
   the vendor delivery wrapper.
6. Confirm `pkt_in_bkpr` is stable in time for PKTIN driving and means no packet
   is accepted in a cycle where it is high.
7. Confirm reset requires PKTOUT valids to be zero. Adjust only the
   reset assertion if the Golden contract explicitly differs.
8. Map each row in `tc/testlist.csv` into the site's fixed h_regress schema.
    Pass the `uvm_test` value through `+UVM_TESTNAME`; every row uses the same
    compiled `tc/tc_pkg.sv`. Do not add a fixed seed column.
9. Verify assertion enable and assertion-coverage switches in the internal
   simulator log before accepting a coverage result.

Internal FE probing is deliberately absent from the Golden gate. It can be
added later as an optional passive bind only after the black-box regression is
stable and the internal hierarchy is confirmed across every Bug RTL.

The default `th/dut_bind_stub.svh` intentionally calls `$fatal`; this prevents
an unconnected black-box run from being mistaken for a passing Golden
regression.
