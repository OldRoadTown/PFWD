`timescale 1ns/1ps

package tc_pkg;
  import uvm_pkg::*;
  import pfe_uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "smoke.sv"
  `include "no_dep.sv"
  `include "dep_distance.sv"
  `include "dep_chain.sv"
  `include "dep_fanout.sv"
  `include "latency.sv"
  `include "sparse_lane.sv"
  `include "output_wrap.sv"
  `include "backpressure.sv"
  `include "parallel.sv"
  `include "scheduler.sv"
  `include "reset.sv"
  `include "random.sv"
  `include "performance.sv"
  `include "lane_config.sv"
endpackage
