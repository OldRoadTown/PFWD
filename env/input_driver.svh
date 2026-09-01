class pfe_input_driver extends uvm_driver #(pfe_input_cycle_item);
  `uvm_component_utils(pfe_input_driver)

  pfe_env_cfg cfg;
  virtual pfe_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_input_driver did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    pfe_input_cycle_item req = null;
    bit req_presented = 1'b0;
    drive_idle();
    forever begin
      @(vif.pkt_drv_cb);

      if (!vif.pkt_drv_cb.rst_n) begin
        drive_idle();
        req_presented = 1'b0;
        continue;
      end

      // A request driven during the preceding cycle is accepted only at an
      // edge where backpressure is low. Do not acknowledge it earlier: BKPR
      // may rise after the request was first presented, in which case the
      // same sequence item must be retained and retried.
      if (req != null && req_presented && !vif.pkt_drv_cb.pkt_in_bkpr) begin
        seq_item_port.item_done();
        req = null;
        req_presented = 1'b0;
      end

      if (vif.pkt_drv_cb.pkt_in_bkpr) begin
        drive_idle();
        req_presented = 1'b0;
        continue;
      end

      if (req == null)
        seq_item_port.try_next_item(req);

      if (req == null) begin
        drive_idle();
        req_presented = 1'b0;
      end else begin
        drive_item(req);
        req_presented = 1'b1;
      end
    end
  endtask

  task drive_idle();
    vif.pkt_drv_cb.pkt_in_vld <= '0;
    for (int i = 0; i < cfg.lane_num; i++) begin
      vif.pkt_drv_cb.pkt_in_data[i] <= '0;
      vif.pkt_drv_cb.pkt_in_ctrl[i] <= '0;
    end
  endtask

  task drive_item(pfe_input_cycle_item req);
    vif.pkt_drv_cb.pkt_in_vld <= req.lane_vld[`PFE_LANE_NUM-1:0];
    for (int i = 0; i < cfg.lane_num; i++) begin
      vif.pkt_drv_cb.pkt_in_data[i] <= req.data[i];
      vif.pkt_drv_cb.pkt_in_ctrl[i] <= {req.dp[i], req.latency[i]};
    end
    `uvm_info("PKTIN_DRV", req.convert2string(), UVM_HIGH)
  endtask
endclass
