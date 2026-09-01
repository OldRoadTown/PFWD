`timescale 1ns/1ps
package tc_pkg;
import uvm_pkg::*;
import pfe_uvm_pkg::*;
`include "uvm_macros.svh"
localparam string TC_NAME = "reset";

class pfe_test extends pfe_base_test;
  `uvm_component_utils(pfe_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_phase(uvm_phase phase);
    pfe_smoke_sequence before_reset;
    pfe_smoke_sequence after_reset;
    phase.raise_objection(this);
    wait (vif.rst_n === 1'b1);

    before_reset = pfe_smoke_sequence::type_id::create("before_reset");
    run_sequence_with_watchdog(before_reset);
    env.scoreboard.wait_for_output_count(before_reset.generated_packets,
                                         cfg.drain_timeout_cycles);
    repeat (2) @(posedge vif.clk);
    vif.apply_reset(cfg.reset_cycles);
    wait (vif.rst_n === 1'b1);

    after_reset = pfe_smoke_sequence::type_id::create("after_reset");
    run_sequence_with_watchdog(after_reset);
    env.scoreboard.wait_for_output_count(after_reset.generated_packets,
                                         cfg.drain_timeout_cycles);
    repeat (5) @(posedge vif.clk);
    phase.drop_objection(this);
  endtask
endclass
endpackage
