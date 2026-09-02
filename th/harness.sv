`timescale 1ns/1ps
`include "defines.svh"

module harness;
  import uvm_pkg::*;
  import pfe_uvm_pkg::*;

  logic clk = 1'b0;
  always #0.5ns clk = ~clk;

  pfe_if pfe_vif(clk);
  dut_adapter #(`PFE_LANE_NUM) u_dut_adapter(pfe_vif);
  protocol_sva #(`PFE_LANE_NUM) u_protocol_sva(pfe_vif);

  initial begin
`ifdef PFE_LANE_NUM_RTL_MISSING
    $fatal(1,
      "LANE_NUM=auto but no RTL LANE_2 through LANE_7 selector was visible; compile the RTL configuration before env/pfe_if.sv or set LANE_NUM explicitly");
`endif
`ifdef PFE_RTL_LANE_NUM
    if (`PFE_LANE_NUM != `PFE_RTL_LANE_NUM)
      $fatal(1,
        "PFE_LANE_NUM=%0d disagrees with RTL LANE_x selection=%0d",
        `PFE_LANE_NUM, `PFE_RTL_LANE_NUM);
`endif
    if (`PFE_LANE_NUM < `PFE_MIN_LANES || `PFE_LANE_NUM > `PFE_MAX_LANES)
      $fatal(1, "PFE_LANE_NUM=%0d is outside supported range [3:7]", `PFE_LANE_NUM);
`ifdef PFE_LANE_NUM_FROM_RTL
    $display("PFE_LANE_CONFIG source=rtl_macro lanes=%0d", `PFE_LANE_NUM);
`elsif PFE_LANE_NUM_FALLBACK
    $display("PFE_LANE_CONFIG source=fallback lanes=%0d", `PFE_LANE_NUM);
`else
    $display("PFE_LANE_CONFIG source=explicit lanes=%0d", `PFE_LANE_NUM);
`endif
    pfe_vif.rst_n = 1'b0;
    pfe_vif.apply_reset(6);
  end

  initial begin
    string test_name;
`ifndef PFE_USE_REAL_DATA_VIP
    $warning("Using open fallback data_caculate_vip; this is not a Golden RTL qualification run");
`endif
    if (!$value$plusargs("UVM_TESTNAME=%s", test_name))
      `uvm_fatal("NO_TEST", "+UVM_TESTNAME=<test class> is required")
    uvm_config_db#(virtual pfe_if)::set(
      null, "uvm_test_top", "vif", pfe_vif);
    uvm_config_db#(string)::set(null, "*", "tc_name", test_name);
    uvm_top.set_timeout(100us, 1'b0);
    // Test selection is deliberately string-based, so harness has no compile
    // order dependency on the standalone tc_pkg supplied by the regression.
    run_test(test_name);
  end
endmodule
