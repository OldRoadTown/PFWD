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
tc/<exactly-one-case>.sv
th/harness.sv
```

For example, the smoke compilation ends with:

```text
tc/smoke.sv
th/harness.sv
```

Each standalone testcase defines `tc_pkg::pfe_test`. The harness always calls
`run_test("pfe_test")`, so no parser, wrapper script, or `+UVM_TESTNAME` is
required. Never compile two `tc/*.sv` files in the same run because they
intentionally reuse the same package and class names.

The production compile also needs `+define+PFE_REAL_DUT`,
`+define+PFE_USE_REAL_DATA_VIP`, the chosen `PFE_LANE_NUM`, and the encrypted
VIP include directory. Do not compile `tools/lint/` in the intranet flow.

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
    Select the file in the `tc_file` column as that run's only testcase source.
    Do not add a fixed seed column.
9. Verify assertion enable and assertion-coverage switches in the internal
   simulator log before accepting a coverage result.

Internal FE probing is deliberately absent from the Golden gate. It can be
added later as an optional passive bind only after the black-box regression is
stable and the internal hierarchy is confirmed across every Bug RTL.

The default `th/dut_bind_stub.svh` intentionally calls `$fatal`; this prevents
an unconnected black-box run from being mistaken for a passing Golden
regression.
