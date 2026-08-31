class pfe_sequencer extends uvm_sequencer #(pfe_input_cycle_item);
  `uvm_component_utils(pfe_sequencer)
  pfe_env_cfg cfg;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class pfe_input_agent extends uvm_agent;
  `uvm_component_utils(pfe_input_agent)

  pfe_env_cfg      cfg;
  pfe_sequencer    sequencer;
  pfe_input_driver driver;
  pfe_input_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_input_agent did not receive pfe_env_cfg")
    monitor = pfe_input_monitor::type_id::create("monitor", this);
    if (cfg.active_input_agent) begin
      sequencer = pfe_sequencer::type_id::create("sequencer", this);
      driver    = pfe_input_driver::type_id::create("driver", this);
      sequencer.cfg = cfg;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.active_input_agent)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
