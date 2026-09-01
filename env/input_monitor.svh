class pfe_input_monitor extends uvm_component;
  `uvm_component_utils(pfe_input_monitor)

  pfe_env_cfg cfg;
  virtual pfe_if vif;
  uvm_analysis_port #(pfe_packet) ap;
  longint unsigned next_seq;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_input_monitor did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    next_seq = 0;
    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) begin
        next_seq = 0;
        continue;
      end
      if (vif.mon_cb.pkt_in_bkpr) continue;

      for (int lane = 0; lane < cfg.lane_num; lane++) begin
        pfe_packet pkt;
        if (!vif.mon_cb.pkt_in_vld[lane]) continue;
        pkt = pfe_packet::type_id::create($sformatf("pkt_%0d", next_seq));
        pkt.data           = vif.mon_cb.pkt_in_data[lane];
        pkt.latency        = vif.mon_cb.pkt_in_ctrl[lane][1:0];
        pkt.dp             = vif.mon_cb.pkt_in_ctrl[lane][4:2];
        pkt.input_lane     = lane;
        pkt.seq_num        = next_seq;
        pkt.accepted_cycle = vif.cycle_count;
        pkt.input_beat_count = $countones(vif.mon_cb.pkt_in_vld);
        pkt.input_lane_mask  = '0;
        pkt.input_lane_mask[`PFE_LANE_NUM-1:0] = vif.mon_cb.pkt_in_vld;
        ap.write(pkt);
        next_seq++;
      end
    end
  endtask
endclass
