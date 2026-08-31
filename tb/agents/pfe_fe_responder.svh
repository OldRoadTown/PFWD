class pfe_fe_responder extends uvm_component;
  `uvm_component_utils(pfe_fe_responder)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;
  bit             busy      [`PFE_MAX_LANES];
  int unsigned    remaining [`PFE_MAX_LANES];
  bit [127:0]     result    [`PFE_MAX_LANES];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_fe_responder did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    clear_outputs();
    clear_state();
    forever begin
      @(vif.fe_drv_cb);
      clear_outputs();
      if (!vif.fe_drv_cb.rst_n) begin
        clear_state();
        continue;
      end

      for (int lane = 0; lane < cfg.lane_num; lane++) begin
        bit was_busy;
        was_busy = busy[lane];

        if (busy[lane]) begin
          if (remaining[lane] == 1) begin
            vif.fe_drv_cb.fwded_pkt_data_vld[lane] <= 1'b1;
            vif.fe_drv_cb.fwded_pkt_data[lane]     <= result[lane];
            busy[lane]      = 1'b0;
            remaining[lane] = 0;
          end else begin
            remaining[lane]--;
          end
        end

        if (!vif.fe_drv_cb.fwd_pkt_data_vld[lane]) continue;
        if (was_busy) begin
          `uvm_error("FE_OVERBOOK",
            $sformatf("cycle=%0d engine=%0d received FEIN while busy",
                      vif.cycle_count, lane))
          continue;
        end

        accept_request(lane);
      end
    end
  endtask

  task clear_outputs();
    vif.fe_drv_cb.fwded_pkt_data_vld <= '0;
    for (int i = 0; i < cfg.lane_num; i++)
      vif.fe_drv_cb.fwded_pkt_data[i] <= '0;
  endtask

  function void clear_state();
    for (int i = 0; i < `PFE_MAX_LANES; i++) begin
      busy[i]      = 1'b0;
      remaining[i] = 0;
      result[i]    = '0;
    end
  endfunction

  task accept_request(int lane);
    bit [127:0] source;
    int unsigned latency_cycles;
    source = vif.fe_drv_cb.fwd_pkt_data[lane];
    if (vif.fe_drv_cb.fwd_pkt_dp_vld[lane])
      source ^= vif.fe_drv_cb.fwd_pkt_dp_data[lane];
    result[lane] = pfe_calculate(source, vif.fe_drv_cb.fwd_pkt_lat[lane]);
    latency_cycles = int'(vif.fe_drv_cb.fwd_pkt_lat[lane]) + 1;

    // A one-cycle FE operation is driven immediately after the sampling edge;
    // the DUT observes it at the following rising edge.
    if (latency_cycles == 1) begin
      vif.fe_drv_cb.fwded_pkt_data_vld[lane] <= 1'b1;
      vif.fe_drv_cb.fwded_pkt_data[lane]     <= result[lane];
    end else begin
      busy[lane]      = 1'b1;
      remaining[lane] = latency_cycles - 1;
    end
  endtask
endclass
