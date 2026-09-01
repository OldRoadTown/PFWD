`timescale 1ns/1ps
`include "defines.svh"

module dut_adapter #(
  parameter int LANE_NUM = `PFE_LANE_NUM
) (pfe_if bus);

`ifdef PFE_REAL_DUT
  // This file is the only project-specific DUT integration seam. It must
  // instantiate the real RTL and connect it to "bus".
  `include "dut_bind.svh"
`else
  `include "dut_bind_stub.svh"
`endif

endmodule
