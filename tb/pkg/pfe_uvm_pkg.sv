`timescale 1ns/1ps
`include "pfe_defines.svh"

package pfe_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_pktin)
  `uvm_analysis_imp_decl(_fe_req)
  `uvm_analysis_imp_decl(_fe_rsp)
  `uvm_analysis_imp_decl(_pktout)
  `uvm_analysis_imp_decl(_reset)
  `uvm_analysis_imp_decl(_cov_pktin)
  `uvm_analysis_imp_decl(_cov_fe_req)
  `uvm_analysis_imp_decl(_cov_pktout)
  `uvm_analysis_imp_decl(_cov_reset)

  `include "pfe_data_vip_wrapper.svh"
  `include "pfe_types.svh"
  `include "pfe_config.svh"
  `include "pfe_input_driver.svh"
  `include "pfe_input_monitor.svh"
  `include "pfe_input_agent.svh"
  `include "pfe_fe_monitor.svh"
  `include "pfe_fe_responder.svh"
  `include "pfe_output_monitor.svh"
  `include "pfe_reset_monitor.svh"
  `include "pfe_scoreboard.svh"
  `include "pfe_coverage.svh"
  `include "pfe_env.svh"
  `include "pfe_sequences.svh"
  `include "pfe_tests.svh"
endpackage
