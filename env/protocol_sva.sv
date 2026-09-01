`timescale 1ns/1ps
`include "defines.svh"

module protocol_sva #(
  parameter int LANE_NUM    = `PFE_LANE_NUM,
  parameter int MAX_PROGRESS = 4096
) (pfe_if #(LANE_NUM) vif);

  int unsigned output_cursor;
  int unsigned output_count;
  logic [LANE_NUM-1:0] expected_output_mask;

  always_comb begin
    output_count = $countones(vif.pkt_out_vld);
    expected_output_mask = '0;
    for (int offset = 0; offset < output_count; offset++)
      expected_output_mask[(output_cursor + offset) % LANE_NUM] = 1'b1;
  end

  always_ff @(posedge vif.clk or negedge vif.rst_n) begin
    if (!vif.rst_n)
      output_cursor <= 0;
    else if (output_count != 0)
      output_cursor <= (output_cursor + output_count) % LANE_NUM;
  end

  a_reset_quiet: assert property (
    @(posedge vif.clk) !vif.rst_n |->
      (vif.pkt_out_vld == '0)
  ) else $error("PFE reset outputs are not quiet");

  a_output_lane_rotation: assert property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      (vif.pkt_out_vld != '0) |->
        (vif.pkt_out_vld == expected_output_mask)
  ) else $error("PFE PKTOUT lane rotation violation");

  a_known_output_valids: assert property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      !$isunknown({vif.pkt_in_bkpr, vif.pkt_out_vld})
  ) else $error("PFE output valid/control contains X or Z");

  generate
    for (genvar lane = 0; lane < LANE_NUM; lane++) begin : g_lane_sva
      a_input_ctrl_known: assert property (
        @(posedge vif.clk) disable iff (!vif.rst_n)
          (vif.pkt_in_vld[lane] && !vif.pkt_in_bkpr) |->
            !$isunknown({vif.pkt_in_data[lane], vif.pkt_in_ctrl[lane]})
      ) else $error("PKTIN lane %0d contains X/Z", lane);

      a_output_data_known: assert property (
        @(posedge vif.clk) disable iff (!vif.rst_n)
          vif.pkt_out_vld[lane] |-> !$isunknown(vif.pkt_out_data[lane])
      ) else $error("PKTOUT lane %0d contains X/Z", lane);

      c_lane_input: cover property (
        @(posedge vif.clk) disable iff (!vif.rst_n)
          vif.pkt_in_vld[lane] && !vif.pkt_in_bkpr);
      c_lane_output: cover property (
        @(posedge vif.clk) disable iff (!vif.rst_n)
          vif.pkt_out_vld[lane]);

      for (genvar lat = 0; lat < 4; lat++) begin : g_lat_cov
        c_latency: cover property (
          @(posedge vif.clk) disable iff (!vif.rst_n)
            vif.pkt_in_vld[lane] && !vif.pkt_in_bkpr &&
            vif.pkt_in_ctrl[lane][1:0] == lat);
      end
      for (genvar dep = 0; dep < 8; dep++) begin : g_dp_cov
        c_dependency: cover property (
          @(posedge vif.clk) disable iff (!vif.rst_n)
            vif.pkt_in_vld[lane] && !vif.pkt_in_bkpr &&
            vif.pkt_in_ctrl[lane][4:2] == dep);
      end
    end
  endgenerate

  a_bounded_visible_progress: assert property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      ((|vif.pkt_in_vld) && !vif.pkt_in_bkpr) |->
        ##[1:MAX_PROGRESS] (|vif.pkt_out_vld)
  ) else $error("PFE made no visible PKTOUT progress within %0d cycles",
                MAX_PROGRESS);

  c_idle_gap: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      ((|vif.pkt_in_vld) && (vif.pkt_in_bkpr == 1'b0))
      ##1 (vif.pkt_in_vld == '0)[*2:8]
      ##1 ((|vif.pkt_in_vld) && (vif.pkt_in_bkpr == 1'b0)));

  c_backpressure_short: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      $rose(vif.pkt_in_bkpr) ##1 (vif.pkt_in_bkpr == 1'b0));
  c_backpressure_medium: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      $rose(vif.pkt_in_bkpr) ##1 vif.pkt_in_bkpr[*2:7]
      ##1 (vif.pkt_in_bkpr == 1'b0));
  c_backpressure_long: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      $rose(vif.pkt_in_bkpr) ##1 vif.pkt_in_bkpr[*8:32]
      ##1 (vif.pkt_in_bkpr == 1'b0));

  c_output_wrap: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      (output_cursor != 0 && output_count >= (LANE_NUM-output_cursor)));
  c_all_output_parallel: cover property (
    @(posedge vif.clk) disable iff (!vif.rst_n)
      (&vif.pkt_out_vld));
  c_reset_reentry: cover property (
    @(posedge vif.clk) $fell(vif.rst_n) ##[4:32] $rose(vif.rst_n));

endmodule
