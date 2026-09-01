`timescale 1ns/1ps

module EXAM2021_TOP (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         lane_pkt_in_vld   [`LANE_WIDTH],
  input  logic [127:0] lane_pkt_in_data  [`LANE_WIDTH],
  input  logic [4:0]   lane_pkt_in_ctrl  [`LANE_WIDTH],
  output logic         lane_pkt_out_vld  [`LANE_WIDTH],
  output logic [127:0] lane_pkt_out_data [`LANE_WIDTH],
  output logic         pkt_in_bkpr
);
  always_comb begin
    pkt_in_bkpr = 1'b0;
    for (int lane = 0; lane < 4; lane++) begin
      lane_pkt_out_vld[lane] = 1'b0;
      lane_pkt_out_data[lane] = '0;
    end
  end
endmodule
