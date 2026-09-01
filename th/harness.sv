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
    if (`PFE_LANE_NUM < `PFE_MIN_LANES || `PFE_LANE_NUM > `PFE_MAX_LANES)
      $fatal(1, "PFE_LANE_NUM=%0d is outside supported range [3:7]", `PFE_LANE_NUM);
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
