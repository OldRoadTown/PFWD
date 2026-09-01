class pfe_output_monitor extends uvm_component;
  `uvm_component_utils(pfe_output_monitor)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;
  uvm_analysis_port #(pfe_out_packet) ap;
  int unsigned next_lane;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_output_monitor did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    next_lane = 0;
    forever begin
      int unsigned count;
      bit [`PFE_MAX_LANES-1:0] expected_mask;
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) begin
        next_lane = 0;
        continue;
      end

      count = $countones(vif.mon_cb.pkt_out_vld);
      if (count == 0) continue;
      expected_mask = '0;
      for (int offset = 0; offset < count; offset++)
        expected_mask[(next_lane + offset) % cfg.lane_num] = 1'b1;
      if (vif.mon_cb.pkt_out_vld !==
          expected_mask[`PFE_LANE_NUM-1:0])
        `uvm_error("PKTOUT_MASK",
          $sformatf("cycle=%0d cursor=%0d expected_mask=0x%0h actual_mask=0x%0h",
                    vif.cycle_count, next_lane,
                    expected_mask, vif.mon_cb.pkt_out_vld))

      for (int offset = 0; offset < cfg.lane_num; offset++) begin
        int lane;
        pfe_out_packet pkt;
        lane = (next_lane + offset) % cfg.lane_num;
        if (!vif.mon_cb.pkt_out_vld[lane]) continue;
        pkt = pfe_out_packet::type_id::create($sformatf("out_%0d", lane));
        pkt.lane            = lane;
        pkt.data            = vif.mon_cb.pkt_out_data[lane];
        pkt.beat_count      = count;
        pkt.beat_start_lane = next_lane;
        pkt.wrapped         = ((next_lane + count) >= cfg.lane_num);
        pkt.cycle           = vif.cycle_count;
        ap.write(pkt);
      end
      next_lane = (next_lane + count) % cfg.lane_num;
    end
  endtask
endclass
