class pfe_base_test extends uvm_test;
  `uvm_component_utils(pfe_base_test)

  pfe_env_cfg cfg;
  pfe_env env;
  virtual pfe_if #(`PFE_LANE_NUM) vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual pfe_if #(`PFE_LANE_NUM))::get(
          this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "pfe_base_test did not receive pfe_if")
    cfg = pfe_env_cfg::type_id::create("cfg");
    cfg.vif = vif;
    cfg.lane_num = `PFE_LANE_NUM;
    cfg.load_plusargs();
    if (cfg.lane_num < `PFE_MIN_LANES || cfg.lane_num > `PFE_MAX_LANES)
      `uvm_fatal("LANE_NUM", $sformatf("unsupported LANE_NUM=%0d", cfg.lane_num))
    uvm_config_db#(pfe_env_cfg)::set(this, "env", "cfg", cfg);
    env = pfe_env::type_id::create("env", this);
  endfunction

  virtual function pfe_base_sequence create_main_sequence();
    return pfe_smoke_sequence::type_id::create("main_sequence");
  endfunction

  task run_sequence_with_watchdog(pfe_base_sequence seq);
    bit finished = 1'b0;
    fork
      begin
        seq.start(env.input_agent.sequencer);
        finished = 1'b1;
      end
      begin
        repeat (cfg.watchdog_cycles) @(posedge vif.clk);
        if (!finished)
          `uvm_fatal("STIMULUS_TIMEOUT",
            $sformatf("sequence did not complete within %0d cycles",
                      cfg.watchdog_cycles))
      end
    join_any
    disable fork;
  endtask

  task run_phase(uvm_phase phase);
    pfe_base_sequence seq;
    phase.raise_objection(this);
    wait (vif.rst_n === 1'b1);
    seq = create_main_sequence();
    run_sequence_with_watchdog(seq);
    env.scoreboard.wait_for_output_count(seq.generated_packets,
                                         cfg.drain_timeout_cycles);
    repeat (5) @(posedge vif.clk);
    phase.drop_objection(this);
  endtask

  function void final_phase(uvm_phase phase);
    uvm_report_server server;
    int unsigned failures;
    super.final_phase(phase);
    server = uvm_report_server::get_server();
    failures = server.get_severity_count(UVM_ERROR) +
               server.get_severity_count(UVM_FATAL);
    if (failures != 0)
      $fatal(1, "PFE regression gate failed with %0d UVM error/fatal reports",
             failures);
  endfunction
endclass

`define PFE_DECLARE_TEST(TEST_CLASS, SEQ_CLASS) \
class TEST_CLASS extends pfe_base_test; \
  `uvm_component_utils(TEST_CLASS) \
  function new(string name, uvm_component parent); super.new(name, parent); endfunction \
  virtual function pfe_base_sequence create_main_sequence(); \
    return SEQ_CLASS::type_id::create("main_sequence"); \
  endfunction \
endclass

`PFE_DECLARE_TEST(pfe_smoke_test,               pfe_smoke_sequence)
`PFE_DECLARE_TEST(pfe_lane_config_test,          pfe_random_sequence)
`PFE_DECLARE_TEST(pfe_no_dependency_test,        pfe_no_dependency_sequence)
`PFE_DECLARE_TEST(pfe_dependency_distance_test,  pfe_dependency_distance_sequence)
`PFE_DECLARE_TEST(pfe_dependency_chain_test,     pfe_dependency_chain_sequence)
`PFE_DECLARE_TEST(pfe_dependency_fanout_test,    pfe_dependency_fanout_sequence)
`PFE_DECLARE_TEST(pfe_latency_matrix_test,       pfe_latency_matrix_sequence)
`PFE_DECLARE_TEST(pfe_sparse_lane_test,          pfe_sparse_lane_sequence)
`PFE_DECLARE_TEST(pfe_output_wraparound_test,    pfe_output_wrap_sequence)
`PFE_DECLARE_TEST(pfe_backpressure_stress_test,  pfe_backpressure_stress_sequence)
`PFE_DECLARE_TEST(pfe_fe_parallel_completion_test, pfe_fe_parallel_sequence)
`PFE_DECLARE_TEST(pfe_scheduler_corner_test,     pfe_scheduler_corner_sequence)
`PFE_DECLARE_TEST(pfe_constrained_random_test,   pfe_random_sequence)
`PFE_DECLARE_TEST(pfe_lane4_performance_test,    pfe_performance_sequence)

class pfe_reset_test extends pfe_base_test;
  `uvm_component_utils(pfe_reset_test)
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

`undef PFE_DECLARE_TEST
