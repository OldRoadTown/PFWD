# Internal Porting Checklist

The protocol-level environment is complete; these are the site-specific steps
that cannot be verified outside the intranet.

1. Confirm the real DUT top module and its compile-time lane parameter.
2. Supply the DUT filelist through `DUT_FILELIST`.
3. For ports named exactly like the specification, set
   `DUT_PORT_STYLE=flat` and `DUT_MODULE=<top>`. The generator creates an exact
   Lane 3/4/5/6/7 bind file.
4. For any other port shape, provide a directory containing
   `pfe_dut_bind.svh` and set `DUT_BIND_DIR`.
5. Put `data_caculate_vip.sv` in `VIP_DIR`. If the encrypted file cannot be
   included inside a package, change only `pfe_data_vip_wrapper.svh` to match
   the vendor delivery wrapper.
6. Check the FE timing diagram against the model convention: FEIN sampled at a
   rising edge with encoded latency 0 produces FEOUT for the following rising
   edge; encoded latency 3 produces it four rising edges later.
7. Confirm each FE instance accepts at most one request until its result is
   returned. If the real FE is pipelined, replace the responder's per-lane
   single entry with a due-cycle queue and retain the collision check.
8. Confirm `pkt_in_bkpr` is stable in time for PKTIN driving and means no packet
   is accepted in a cycle where it is high.
9. Confirm reset requires PKTOUT and FEIN valids to be zero. Adjust only the
   reset assertion if the Golden contract explicitly differs.
10. Map the site-specific h_regress schema to `regress/pfe_regress.csv`, using
    `scripts/h_regress_case.sh` as each case command. Do not add a seed column.
11. Verify assertion enable and assertion-coverage switches in the internal
    simulator log before accepting a coverage result.

The default DUT bind intentionally calls `$fatal`; this prevents an unconnected
black-box run from being mistaken for a passing Golden regression.
