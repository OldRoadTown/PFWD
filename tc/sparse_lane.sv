`timescale 1ns/1ps
package tc_pkg;
import uvm_pkg::*;
import pfe_uvm_pkg::*;
`include "uvm_macros.svh"
localparam string TC_NAME = "sparse_lane";

class sparse_lane extends pfe_base_test;
  `uvm_component_utils(sparse_lane)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function pfe_base_sequence create_main_sequence();
    return pfe_sparse_lane_sequence::type_id::create("main_sequence");
  endfunction
endclass
endpackage
