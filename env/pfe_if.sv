`timescale 1ns/1ps
`include "defines.svh"

interface pfe_if #(
  parameter int LANE_NUM = `PFE_LANE_NUM,
  parameter int DATA_W   = `PFE_DATA_W
) (input logic clk);

  logic rst_n;

  logic [LANE_NUM-1:0]             pkt_in_vld;
  logic [LANE_NUM-1:0][DATA_W-1:0] pkt_in_data;
  logic [LANE_NUM-1:0][4:0]        pkt_in_ctrl;
  logic                 pkt_in_bkpr;

  logic [LANE_NUM-1:0]             pkt_out_vld;
  logic [LANE_NUM-1:0][DATA_W-1:0] pkt_out_data;

  longint unsigned cycle_count = 0;

  always @(posedge clk)
    cycle_count <= cycle_count + 1;

  task automatic apply_reset(int unsigned cycles = 6);
    rst_n <= 1'b0;
    repeat (cycles) @(posedge clk);
    #1ps;
    rst_n <= 1'b1;
  endtask

  clocking pkt_drv_cb @(posedge clk);
    default input #1step output #0;
    input  rst_n, pkt_in_bkpr;
    output pkt_in_vld, pkt_in_data, pkt_in_ctrl;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n;
    input pkt_in_vld, pkt_in_data, pkt_in_ctrl, pkt_in_bkpr;
    input pkt_out_vld, pkt_out_data;
  endclocking

  modport dut (
    input  clk, rst_n,
    input  pkt_in_vld, pkt_in_data, pkt_in_ctrl,
    output pkt_in_bkpr,
    output pkt_out_vld, pkt_out_data
  );

endinterface
