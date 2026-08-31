`timescale 1ns/1ps
`include "pfe_defines.svh"

// Non-UVM elaboration shell used only by the open-source interface lint target.
module pfe_lint_top;
  logic clk = 1'b0;
  always #0.5ns clk = ~clk;
  pfe_if #(`PFE_LANE_NUM) bus(clk);
  pfe_dut_adapter #(`PFE_LANE_NUM) adapter(bus);
  pfe_protocol_sva #(`PFE_LANE_NUM) assertions(bus);
endmodule
