class pfe_coverage extends uvm_component;
  `uvm_component_utils(pfe_coverage)

  pfe_env_cfg cfg;
  virtual pfe_if #(`PFE_LANE_NUM) vif;
  uvm_analysis_imp_cov_pktin #(pfe_packet, pfe_coverage) pktin_imp;
  uvm_analysis_imp_cov_pktout #(pfe_out_packet, pfe_coverage) pktout_imp;
  uvm_analysis_imp_cov_reset #(pfe_reset_event, pfe_coverage) reset_imp;

  int unsigned dependency_fanout[longint unsigned];
  int unsigned current_chain_depth;

  covergroup input_cg with function sample(
    int unsigned lane_num,
    int unsigned lane,
    int unsigned beat_count,
    bit [`PFE_MAX_LANES-1:0] lane_mask,
    bit [1:0] latency,
    bit [2:0] dp,
    int unsigned mask_kind,
    int unsigned chain_depth,
    int unsigned fanout
  );
    option.per_instance = 1;
    cp_lane_num: coverpoint lane_num {
      bins configured = {`PFE_LANE_NUM};
      illegal_bins unsupported = default;
    }
    cp_lane: coverpoint lane { bins lanes[] = {[0:`PFE_LANE_NUM-1]}; }
    cp_beat_count: coverpoint beat_count {
      bins counts[] = {[1:`PFE_LANE_NUM]};
    }
    cp_lane_mask: coverpoint lane_mask {
      bins masks[] = {[1:(1<<`PFE_LANE_NUM)-1]};
    }
    cp_mask_kind: coverpoint mask_kind {
      bins single = {0}; bins sparse = {1}; bins full = {2};
    }
    cp_latency: coverpoint latency { bins latency_1_to_4[] = {[0:3]}; }
    cp_dp: coverpoint dp { bins distances[] = {[0:7]}; }
    cp_chain: coverpoint chain_depth {
      bins none = {0}; bins short = {[1:3]}; bins long = {[4:15]};
      bins very_long = {[16:$]};
    }
    cp_fanout: coverpoint fanout {
      bins none = {0}; bins one = {1}; bins many = {[2:7]};
    }
    latency_x_dp: cross cp_latency, cp_dp;
    lane_x_latency_x_dp: cross cp_lane, cp_latency, cp_dp;
  endgroup

  covergroup output_cg with function sample(
    int unsigned lane,
    int unsigned beat_count,
    int unsigned start_lane,
    bit wrapped
  );
    option.per_instance = 1;
    cp_lane: coverpoint lane { bins lanes[] = {[0:`PFE_LANE_NUM-1]}; }
    cp_count: coverpoint beat_count {
      bins counts[] = {[1:`PFE_LANE_NUM]};
    }
    cp_start: coverpoint start_lane {
      bins lanes[] = {[0:`PFE_LANE_NUM-1]};
    }
    cp_wrap: coverpoint wrapped;
    start_x_count: cross cp_start, cp_count;
  endgroup

  covergroup bkpr_cg with function sample(int unsigned streak);
    option.per_instance = 1;
    cp_streak: coverpoint streak {
      bins none = {0}; bins short = {[1:3]}; bins moderate = {[4:15]};
      bins long = {[16:$]};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pktin_imp = new("pktin_imp", this);
    pktout_imp = new("pktout_imp", this);
    reset_imp = new("reset_imp", this);
    input_cg = new;
    output_cg = new;
    bkpr_cg = new;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pfe_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "pfe_coverage did not receive pfe_env_cfg")
    vif = cfg.vif;
  endfunction

  function void write_cov_pktin(pfe_packet pkt);
    int unsigned fanout = 0;
    int unsigned mask_kind;
    if (pkt.dp == 1) current_chain_depth++;
    else current_chain_depth = 0;
    if (pkt.dp != 0) begin
      longint unsigned dep_seq = pkt.seq_num - longint'(pkt.dp);
      dependency_fanout[dep_seq]++;
      fanout = dependency_fanout[dep_seq];
    end
    if (pkt.input_beat_count == 1) mask_kind = 0;
    else if (pkt.input_beat_count == cfg.lane_num) mask_kind = 2;
    else mask_kind = 1;
    input_cg.sample(cfg.lane_num, pkt.input_lane, pkt.input_beat_count,
                    pkt.input_lane_mask, pkt.latency, pkt.dp, mask_kind,
                    current_chain_depth, fanout);
  endfunction

  function void write_cov_pktout(pfe_out_packet pkt);
    output_cg.sample(pkt.lane, pkt.beat_count, pkt.beat_start_lane,
                     pkt.wrapped);
  endfunction

  function void write_cov_reset(pfe_reset_event ev);
    dependency_fanout.delete();
    current_chain_depth = 0;
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned streak = 0;
    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) begin
        if (streak != 0) bkpr_cg.sample(streak);
        streak = 0;
      end else if (vif.mon_cb.pkt_in_bkpr) begin
        streak++;
      end else if (streak != 0) begin
        bkpr_cg.sample(streak);
        streak = 0;
      end
    end
  endtask
endclass
