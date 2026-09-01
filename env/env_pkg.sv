`timescale 1ns/1ps
`include "defines.svh"

package pfe_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_pktin)
  `uvm_analysis_imp_decl(_pktout)
  `uvm_analysis_imp_decl(_reset)
  `uvm_analysis_imp_decl(_cov_pktin)
  `uvm_analysis_imp_decl(_cov_pktout)
  `uvm_analysis_imp_decl(_cov_reset)

  `include "data_vip.svh"
  `include "types.svh"
  `include "config.svh"
  `include "input_driver.svh"
  `include "input_monitor.svh"
  `include "input_agent.svh"
  `include "output_monitor.svh"
  `include "reset_monitor.svh"
  `include "scoreboard.svh"
  `include "coverage.svh"
  `include "env.svh"
  `include "sequences.svh"
  `include "base_test.svh"
endpackage
