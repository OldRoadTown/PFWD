class pfe_reset_monitor extends uvm_component;
  `uvm_component_utils(pfe_reset_monitor)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;
  uvm_analysis_port #(pfe_reset_event) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_reset_monitor did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      pfe_reset_event ev;
      @(negedge vif.rst_n);
      ev = pfe_reset_event::type_id::create("reset_asserted");
      ev.asserted = 1'b1;
      ev.cycle = vif.cycle_count;
      ap.write(ev);
    end
  endtask
endclass
