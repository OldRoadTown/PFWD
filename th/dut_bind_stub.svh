// Safe default: compile is possible, but simulation cannot accidentally pass
// without an explicitly connected DUT.
always_comb begin
  bus.pkt_in_bkpr       = 1'b0;
  bus.pkt_out_vld       = '0;
  for (int lane = 0; lane < LANE_NUM; lane++) begin
    bus.pkt_out_data[lane]    = '0;
  end
end

initial begin
  #1ps;
  $fatal(1, "PFE DUT is not connected. Define PFE_REAL_DUT and provide dut_bind.svh");
end
