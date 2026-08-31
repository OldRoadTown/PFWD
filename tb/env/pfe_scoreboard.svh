class pfe_scoreboard extends uvm_component;
  `uvm_component_utils(pfe_scoreboard)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;

  uvm_analysis_imp_pktin #(pfe_packet, pfe_scoreboard) pktin_imp;
  uvm_analysis_imp_fe_req #(pfe_fe_req, pfe_scoreboard) fe_req_imp;
  uvm_analysis_imp_fe_rsp #(pfe_fe_rsp, pfe_scoreboard) fe_rsp_imp;
  uvm_analysis_imp_pktout #(pfe_out_packet, pfe_scoreboard) pktout_imp;
  uvm_analysis_imp_reset #(pfe_reset_event, pfe_scoreboard) reset_imp;

  pfe_packet packet_db[longint unsigned];
  pfe_packet inflight_by_engine[`PFE_MAX_LANES];
  longint unsigned next_output_seq;

  longint unsigned accepted_count;
  longint unsigned dispatched_count;
  longint unsigned completed_count;
  longint unsigned output_count;
  longint unsigned first_accept_cycle;
  longint unsigned last_output_cycle;
  longint unsigned dispatch_wait_sum;
  longint unsigned e2e_sum;
  longint unsigned max_dispatch_wait;
  longint unsigned max_e2e;
  longint unsigned observed_cycles;
  longint unsigned bkpr_cycles;
  longint unsigned current_bkpr_streak;
  longint unsigned max_bkpr_streak;
  longint unsigned fe_dispatch_slots;
  longint unsigned output_slots;
  int unsigned reset_epoch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pktin_imp = new("pktin_imp", this);
    fe_req_imp = new("fe_req_imp", this);
    fe_rsp_imp = new("fe_rsp_imp", this);
    pktout_imp = new("pktout_imp", this);
    reset_imp = new("reset_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_scoreboard did not receive pfe_env_cfg")
    vif = cfg.vif;
    clear_model();
  endfunction

  function void clear_model();
    packet_db.delete();
    for (int i = 0; i < `PFE_MAX_LANES; i++) inflight_by_engine[i] = null;
    next_output_seq      = 0;
    accepted_count       = 0;
    dispatched_count     = 0;
    completed_count      = 0;
    output_count         = 0;
    first_accept_cycle   = 0;
    last_output_cycle    = 0;
    dispatch_wait_sum    = 0;
    e2e_sum              = 0;
    max_dispatch_wait    = 0;
    max_e2e              = 0;
    observed_cycles      = 0;
    bkpr_cycles          = 0;
    current_bkpr_streak  = 0;
    max_bkpr_streak      = 0;
    fe_dispatch_slots    = 0;
    output_slots         = 0;
  endfunction

  function void write_reset(pfe_reset_event ev);
    reset_epoch++;
    clear_model();
    `uvm_info("RESET_MODEL",
      $sformatf("scoreboard flushed by reset at cycle=%0d epoch=%0d",
                ev.cycle, reset_epoch), UVM_MEDIUM)
  endfunction

  function void write_pktin(pfe_packet observed);
    pfe_packet pkt;
    longint unsigned dp_distance;
    if (packet_db.exists(observed.seq_num)) begin
      `uvm_error("DUP_INPUT_SEQ",
        $sformatf("duplicate accepted sequence %0d", observed.seq_num))
      return;
    end

    $cast(pkt, observed.clone());
    dp_distance = longint'(pkt.dp);
    if (pkt.seq_num < dp_distance) begin
      `uvm_error("ILLEGAL_DP",
        $sformatf("seq=%0d lane=%0d has dp=%0d before enough history",
                  pkt.seq_num, pkt.input_lane, pkt.dp))
      pkt.dp = 0;
    end

    if (pkt.dp != 0) begin
      pkt.dependency_seq = pkt.seq_num - dp_distance;
      if (!packet_db.exists(pkt.dependency_seq)) begin
        `uvm_error("MISSING_DEP",
          $sformatf("seq=%0d references unavailable dependency seq=%0d",
                    pkt.seq_num, pkt.dependency_seq))
        pkt.expected_dp_data = '0;
      end else begin
        pkt.expected_dp_data = packet_db[pkt.dependency_seq].expected_data;
      end
    end

    pkt.expected_data = pfe_calculate(
      pkt.data ^ ((pkt.dp != 0) ? pkt.expected_dp_data : 128'b0),
      pkt.latency);
    packet_db[pkt.seq_num] = pkt;
    if (accepted_count == 0) first_accept_cycle = pkt.accepted_cycle;
    accepted_count++;
  endfunction

  function void write_fe_req(pfe_fe_req req);
    pfe_packet match;
    int unsigned candidates = 0;
    longint unsigned matched_seq;

    if (req.engine_lane >= cfg.lane_num) begin
      `uvm_error("FE_LANE", $sformatf("invalid FE engine lane=%0d", req.engine_lane))
      return;
    end
    if (inflight_by_engine[req.engine_lane] != null) begin
      `uvm_error("FE_REUSE",
        $sformatf("cycle=%0d engine=%0d reused before response; old_seq=%0d",
                  req.cycle, req.engine_lane,
                  inflight_by_engine[req.engine_lane].seq_num))
      return;
    end

    foreach (packet_db[seq]) begin
      pfe_packet candidate = packet_db[seq];
      bit expected_dp_vld = (candidate.dp != 0);
      if (candidate.dispatched) continue;
      if (candidate.data !== req.data) continue;
      if (candidate.latency !== req.latency) continue;
      if (expected_dp_vld !== req.dp_vld) continue;
      if (expected_dp_vld && candidate.expected_dp_data !== req.dp_data) continue;
      if (candidates == 0) begin
        match = candidate;
        matched_seq = seq;
      end
      candidates++;
    end

    if (candidates == 0) begin
      `uvm_error("UNEXPECTED_FE_REQ",
        $sformatf("cycle=%0d engine=%0d data=%032h lat=%0d dp_vld=%0b dp_data=%032h",
                  req.cycle, req.engine_lane, req.data, req.latency,
                  req.dp_vld, req.dp_data))
      return;
    end
    if (candidates > 1)
      `uvm_warning("AMBIGUOUS_FE_REQ",
        $sformatf("cycle=%0d engine=%0d matched %0d identical packets; choosing lowest seq=%0d",
                  req.cycle, req.engine_lane, candidates, matched_seq))

    if (match.dp != 0) begin
      pfe_packet dep = packet_db[match.dependency_seq];
      if (!dep.completed || dep.completion_cycle >= req.cycle)
        `uvm_error("DEPENDENCY_EARLY",
          $sformatf("seq=%0d dispatched cycle=%0d before dependency seq=%0d was available; completed=%0b completion_cycle=%0d",
                    match.seq_num, req.cycle, dep.seq_num,
                    dep.completed, dep.completion_cycle))
    end
    match.dispatched     = 1'b1;
    match.dispatch_cycle = req.cycle;
    match.engine_lane    = req.engine_lane;
    inflight_by_engine[req.engine_lane] = match;
    dispatched_count++;
    dispatch_wait_sum += req.cycle - match.accepted_cycle;
    if ((req.cycle - match.accepted_cycle) > max_dispatch_wait)
      max_dispatch_wait = req.cycle - match.accepted_cycle;
  endfunction

  function void write_fe_rsp(pfe_fe_rsp rsp);
    pfe_packet pkt;
    if (rsp.engine_lane >= cfg.lane_num ||
        inflight_by_engine[rsp.engine_lane] == null) begin
      `uvm_error("UNEXPECTED_FE_RSP",
        $sformatf("cycle=%0d engine=%0d data=%032h has no outstanding request",
                  rsp.cycle, rsp.engine_lane, rsp.data))
      return;
    end
    pkt = inflight_by_engine[rsp.engine_lane];
    if (rsp.data !== pkt.expected_data)
      `uvm_error("FE_DATA_MISMATCH",
        $sformatf("seq=%0d engine=%0d cycle=%0d expected=%032h actual=%032h",
                  pkt.seq_num, rsp.engine_lane, rsp.cycle,
                  pkt.expected_data, rsp.data))
    pkt.completed        = 1'b1;
    pkt.completion_cycle = rsp.cycle;
    completed_count++;
    inflight_by_engine[rsp.engine_lane] = null;
  endfunction

  function void write_pktout(pfe_out_packet out_pkt);
    pfe_packet expected;
    longint unsigned e2e;
    int unsigned expected_lane;
    if (!packet_db.exists(next_output_seq)) begin
      `uvm_error("UNEXPECTED_PKTOUT",
        $sformatf("cycle=%0d lane=%0d data=%032h no expected seq=%0d",
                  out_pkt.cycle, out_pkt.lane, out_pkt.data, next_output_seq))
      return;
    end

    expected = packet_db[next_output_seq];
    expected_lane = int'(next_output_seq % longint'(cfg.lane_num));
    if (out_pkt.lane != expected_lane)
      `uvm_error("PKTOUT_ORDER",
        $sformatf("seq=%0d cycle=%0d expected_lane=%0d actual_lane=%0d",
                  next_output_seq, out_pkt.cycle, expected_lane, out_pkt.lane))
    if (!expected.completed)
      `uvm_error("PKTOUT_EARLY",
        $sformatf("seq=%0d output at cycle=%0d before FE completion",
                  next_output_seq, out_pkt.cycle))
    if (out_pkt.data !== expected.expected_data)
      `uvm_error("PKTOUT_DATA",
        $sformatf("seq=%0d lane=%0d cycle=%0d expected=%032h actual=%032h",
                  next_output_seq, out_pkt.lane, out_pkt.cycle,
                  expected.expected_data, out_pkt.data))
    if (expected.output_seen)
      `uvm_error("DUP_PKTOUT", $sformatf("seq=%0d was output more than once", next_output_seq))

    expected.output_seen  = 1'b1;
    expected.output_cycle = out_pkt.cycle;
    e2e = out_pkt.cycle - expected.accepted_cycle;
    e2e_sum += e2e;
    if (e2e > max_e2e) max_e2e = e2e;
    last_output_cycle = out_pkt.cycle;
    output_count++;
    next_output_seq++;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) continue;
      observed_cycles++;
      if (vif.mon_cb.pkt_in_bkpr) begin
        bkpr_cycles++;
        current_bkpr_streak++;
        if (current_bkpr_streak > max_bkpr_streak)
          max_bkpr_streak = current_bkpr_streak;
      end else begin
        current_bkpr_streak = 0;
      end
      fe_dispatch_slots += $countones(vif.mon_cb.fwd_pkt_data_vld);
      output_slots      += $countones(vif.mon_cb.pkt_out_vld);
    end
  endtask

  task wait_for_output_count(longint unsigned expected_count,
                             int unsigned timeout_cycles);
    bit timed_out = 1'b0;
    fork
      begin
        wait (output_count >= expected_count);
      end
      begin
        repeat (timeout_cycles) @(posedge vif.clk);
        timed_out = (output_count < expected_count);
      end
    join_any
    disable fork;
    if (timed_out)
      `uvm_error("DRAIN_TIMEOUT",
        $sformatf("after %0d cycles expected_outputs=%0d actual_outputs=%0d accepted=%0d dispatched=%0d completed=%0d",
                  timeout_cycles, expected_count, output_count,
                  accepted_count, dispatched_count, completed_count))
  endtask

  function real throughput();
    longint unsigned span;
    if (output_count == 0 || last_output_cycle < first_accept_cycle) return 0.0;
    span = last_output_cycle - first_accept_cycle + 1;
    return real'(output_count) / real'(span);
  endfunction

  function real avg_e2e();
    if (output_count == 0) return 0.0;
    return real'(e2e_sum) / real'(output_count);
  endfunction

  function real bkpr_ratio();
    if (observed_cycles == 0) return 0.0;
    return real'(bkpr_cycles) / real'(observed_cycles);
  endfunction

  function void check_phase(uvm_phase phase);
    real tput = throughput();
    real e2e = avg_e2e();
    real bkpr = bkpr_ratio();
    super.check_phase(phase);

    if (accepted_count != output_count)
      `uvm_error("PACKET_BALANCE",
        $sformatf("accepted=%0d output=%0d pending=%0d",
                  accepted_count, output_count, accepted_count-output_count))

    if (!cfg.enable_perf_checks) return;
    if (cfg.perf_base_throughput > 0.0 &&
        tput < cfg.perf_base_throughput * cfg.perf_min_tput_ratio)
      `uvm_error("PERF_THROUGHPUT",
        $sformatf("throughput=%0.6f baseline=%0.6f required_ratio=%0.3f",
                  tput, cfg.perf_base_throughput, cfg.perf_min_tput_ratio))
    if (cfg.perf_base_avg_e2e > 0.0 &&
        e2e > cfg.perf_base_avg_e2e * cfg.perf_max_e2e_ratio)
      `uvm_error("PERF_LATENCY",
        $sformatf("avg_e2e=%0.3f baseline=%0.3f allowed_ratio=%0.3f",
                  e2e, cfg.perf_base_avg_e2e, cfg.perf_max_e2e_ratio))
    if (cfg.perf_base_bkpr_ratio >= 0.0 &&
        bkpr > cfg.perf_base_bkpr_ratio + cfg.perf_max_bkpr_delta)
      `uvm_error("PERF_BKPR",
        $sformatf("bkpr_ratio=%0.6f baseline=%0.6f allowed_delta=%0.3f",
                  bkpr, cfg.perf_base_bkpr_ratio, cfg.perf_max_bkpr_delta))
  endfunction

  function void report_phase(uvm_phase phase);
    int fd;
    string test_name = "unknown";
    real avg_dispatch = 0.0;
    void'($value$plusargs("UVM_TESTNAME=%s", test_name));
    if (dispatched_count != 0)
      avg_dispatch = real'(dispatch_wait_sum) / real'(dispatched_count);

    `uvm_info("PFE_PERF",
      $sformatf("test=%s lanes=%0d accepted=%0d output=%0d cycles=%0d throughput=%0.6f avg_dispatch=%0.3f max_dispatch=%0d avg_e2e=%0.3f max_e2e=%0d bkpr_ratio=%0.6f max_bkpr=%0d",
                test_name, cfg.lane_num, accepted_count, output_count,
                observed_cycles, throughput(), avg_dispatch, max_dispatch_wait,
                avg_e2e(), max_e2e, bkpr_ratio(), max_bkpr_streak), UVM_NONE)

    fd = $fopen(cfg.perf_result_file, "w");
    if (fd == 0) begin
      `uvm_warning("PERF_FILE", $sformatf("cannot open %s", cfg.perf_result_file))
      return;
    end
    $fdisplay(fd, "test,lane_num,accepted,output,observed_cycles,sim_cycles,throughput,avg_dispatch,max_dispatch,avg_e2e,max_e2e,bkpr_ratio,max_bkpr,fe_slots,out_slots");
    $fdisplay(fd, "%s,%0d,%0d,%0d,%0d,%0d,%0.9f,%0.6f,%0d,%0.6f,%0d,%0.9f,%0d,%0d,%0d",
              test_name, cfg.lane_num, accepted_count, output_count,
              observed_cycles, vif.cycle_count, throughput(), avg_dispatch, max_dispatch_wait,
              avg_e2e(), max_e2e, bkpr_ratio(), max_bkpr_streak,
              fe_dispatch_slots, output_slots);
    $fclose(fd);
  endfunction
endclass
