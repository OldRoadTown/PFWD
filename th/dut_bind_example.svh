// Copy this file to dut_bind.svh after confirming the exact EXAM2021_TOP
// declarations and the definition of `LANE_WIDTH. The DUT uses unpacked lane
// arrays, while pfe_if uses packed arrays for portable UVM clocking blocks.
`ifndef PFE_DUT_MODULE
  `define PFE_DUT_MODULE EXAM2021_TOP
`endif

logic         dut_pkt_in_vld   [`LANE_WIDTH];
logic [127:0] dut_pkt_in_data  [`LANE_WIDTH];
logic [4:0]   dut_pkt_in_ctrl  [`LANE_WIDTH];
logic         dut_pkt_out_vld  [`LANE_WIDTH];
logic [127:0] dut_pkt_out_data [`LANE_WIDTH];

for (genvar lane = 0; lane < LANE_NUM; lane++) begin : g_lane_bridge
  assign dut_pkt_in_vld[lane]   = bus.pkt_in_vld[lane];
  assign dut_pkt_in_data[lane]  = bus.pkt_in_data[lane];
  assign dut_pkt_in_ctrl[lane]  = bus.pkt_in_ctrl[lane];
  assign bus.pkt_out_vld[lane]  = dut_pkt_out_vld[lane];
  assign bus.pkt_out_data[lane] = dut_pkt_out_data[lane];
end

`PFE_DUT_MODULE u_dut (
  .clk               (bus.clk),
  .rst_n             (bus.rst_n),
  .lane_pkt_in_vld   (dut_pkt_in_vld),
  .lane_pkt_in_data  (dut_pkt_in_data),
  .lane_pkt_in_ctrl  (dut_pkt_in_ctrl),
  .lane_pkt_out_vld  (dut_pkt_out_vld),
  .lane_pkt_out_data (dut_pkt_out_data),
  .pkt_in_bkpr       (bus.pkt_in_bkpr)
);
