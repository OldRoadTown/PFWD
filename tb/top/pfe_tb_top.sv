`timescale 1ns/1ps
`include "pfe_defines.svh"

module pfe_tb_top;
  import uvm_pkg::*;
  import pfe_uvm_pkg::*;

  logic clk = 1'b0;
  always #0.5ns clk = ~clk;

  pfe_if #(`PFE_LANE_NUM) pfe_vif(clk);
  pfe_dut_adapter #(`PFE_LANE_NUM) u_dut_adapter(pfe_vif);
  pfe_protocol_sva #(`PFE_LANE_NUM) u_protocol_sva(pfe_vif);

  initial begin
    if (`PFE_LANE_NUM < `PFE_MIN_LANES || `PFE_LANE_NUM > `PFE_MAX_LANES)
      $fatal(1, "PFE_LANE_NUM=%0d is outside supported range [3:7]", `PFE_LANE_NUM);
    pfe_vif.rst_n = 1'b0;
    pfe_vif.apply_reset(6);
  end

  initial begin
`ifndef PFE_USE_REAL_DATA_VIP
    $warning("Using open fallback data_caculate_vip; this is not a Golden RTL qualification run");
`endif
    uvm_config_db#(virtual pfe_if #(`PFE_LANE_NUM))::set(
      null, "uvm_test_top", "vif", pfe_vif);
    uvm_top.set_timeout(100us, 1'b0);
    run_test();
  end
endmodule
