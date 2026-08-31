`timescale 1ns/1ps
`include "pfe_defines.svh"

module pfe_dut_adapter #(
  parameter int LANE_NUM = `PFE_LANE_NUM
) (pfe_if #(LANE_NUM) bus);

`ifdef PFE_REAL_DUT
  // This file is the only project-specific DUT integration seam. It must
  // instantiate the real RTL and connect it to "bus".
  `include "pfe_dut_bind.svh"
`else
  `include "pfe_dut_bind_stub.svh"
`endif

endmodule
