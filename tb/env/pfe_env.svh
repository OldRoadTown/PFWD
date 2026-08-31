class pfe_env extends uvm_env;
  `uvm_component_utils(pfe_env)

  pfe_env_cfg       cfg;
  pfe_input_agent   input_agent;
  pfe_fe_monitor    fe_monitor;
  pfe_fe_responder  fe_responder;
  pfe_output_monitor output_monitor;
  pfe_reset_monitor reset_monitor;
  pfe_scoreboard    scoreboard;
  pfe_coverage      coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_env did not receive pfe_env_cfg")
    uvm_config_db#(pfe_env_cfg)::set(this, "*", "cfg", cfg);
    input_agent   = pfe_input_agent::type_id::create("input_agent", this);
    fe_monitor    = pfe_fe_monitor::type_id::create("fe_monitor", this);
    fe_responder  = pfe_fe_responder::type_id::create("fe_responder", this);
    output_monitor = pfe_output_monitor::type_id::create("output_monitor", this);
    reset_monitor = pfe_reset_monitor::type_id::create("reset_monitor", this);
    scoreboard    = pfe_scoreboard::type_id::create("scoreboard", this);
    coverage      = pfe_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    input_agent.monitor.ap.connect(scoreboard.pktin_imp);
    input_agent.monitor.ap.connect(coverage.pktin_imp);
    fe_monitor.req_ap.connect(scoreboard.fe_req_imp);
    fe_monitor.req_ap.connect(coverage.fe_req_imp);
    fe_monitor.rsp_ap.connect(scoreboard.fe_rsp_imp);
    output_monitor.ap.connect(scoreboard.pktout_imp);
    output_monitor.ap.connect(coverage.pktout_imp);
    reset_monitor.ap.connect(scoreboard.reset_imp);
    reset_monitor.ap.connect(coverage.reset_imp);
  endfunction
endclass
