`timescale 1ns/1ps
`include "defines.svh"

// Non-UVM elaboration shell used only by the open-source interface lint target.
module lint_top;
  logic clk = 1'b0;
  always #0.5ns clk = ~clk;
  pfe_if bus(clk);
  dut_adapter #(`PFE_LANE_NUM) adapter(bus);
  protocol_sva #(`PFE_LANE_NUM) assertions(bus);
endmodule
