class pfe_base_test extends uvm_test;
  `uvm_component_utils(pfe_base_test)

  pfe_env_cfg cfg;
  pfe_env env;
  virtual pfe_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual pfe_if)::get(
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
    if (vif.sva_failure_count != 0)
      `uvm_error("SVA_FAILURES",
        $sformatf("%0d protocol assertion failure(s) were reported",
                  vif.sva_failure_count))
    server = uvm_report_server::get_server();
    failures = server.get_severity_count(UVM_ERROR) +
               server.get_severity_count(UVM_FATAL);
    if (failures != 0)
      `uvm_fatal("PFE_GATE",
        $sformatf("PFE regression gate failed with %0d UVM error/fatal reports",
                  failures))
    else
      `uvm_info("PASSED", "PASSED", UVM_NONE)
  endfunction
endclass
