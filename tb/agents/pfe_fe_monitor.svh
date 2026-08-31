class pfe_fe_monitor extends uvm_component;
  `uvm_component_utils(pfe_fe_monitor)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;
  uvm_analysis_port #(pfe_fe_req) req_ap;
  uvm_analysis_port #(pfe_fe_rsp) rsp_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_ap = new("req_ap", this);
    rsp_ap = new("rsp_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_fe_monitor did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      int unsigned parallelism;
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) continue;
      parallelism = $countones(vif.mon_cb.fwd_pkt_data_vld);

      for (int lane = 0; lane < cfg.lane_num; lane++) begin
        if (vif.mon_cb.fwd_pkt_data_vld[lane]) begin
          pfe_fe_req req;
          req = pfe_fe_req::type_id::create($sformatf("fe_req_%0d", lane));
          req.engine_lane     = lane;
          req.data            = vif.mon_cb.fwd_pkt_data[lane];
          req.latency         = vif.mon_cb.fwd_pkt_lat[lane];
          req.dp_vld          = vif.mon_cb.fwd_pkt_dp_vld[lane];
          req.dp_data         = vif.mon_cb.fwd_pkt_dp_data[lane];
          req.beat_parallelism = parallelism;
          req.cycle           = vif.cycle_count;
          req_ap.write(req);
        end
        if (vif.mon_cb.fwded_pkt_data_vld[lane]) begin
          pfe_fe_rsp rsp;
          rsp = pfe_fe_rsp::type_id::create($sformatf("fe_rsp_%0d", lane));
          rsp.engine_lane = lane;
          rsp.data        = vif.mon_cb.fwded_pkt_data[lane];
          rsp.cycle       = vif.cycle_count;
          rsp_ap.write(rsp);
        end
      end
    end
  endtask
endclass
