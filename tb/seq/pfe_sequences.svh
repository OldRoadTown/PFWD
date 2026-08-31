class pfe_base_sequence extends uvm_sequence #(pfe_input_cycle_item);
  `uvm_object_utils(pfe_base_sequence)
  `uvm_declare_p_sequencer(pfe_sequencer)

  longint unsigned generated_packets;
  int unsigned generated_beats;

  function new(string name = "pfe_base_sequence");
    super.new(name);
  endfunction

  function bit [`PFE_MAX_LANES-1:0] full_mask();
    return (1 << p_sequencer.cfg.lane_num) - 1;
  endfunction

  function pfe_input_cycle_item make_random_beat(
    bit [`PFE_MAX_LANES-1:0] requested_mask,
    string name = "beat"
  );
    pfe_input_cycle_item req;
    pfe_lane_mask_t fixed_mask = requested_mask;
    req = pfe_input_cycle_item::type_id::create(name);
    req.lane_num = p_sequencer.cfg.lane_num;
    if (req.randomize() with { lane_vld == local::fixed_mask; } == 0)
      `uvm_fatal("RAND_FAIL", "failed to randomize PFE input beat")
    return req;
  endfunction

  function void prepare_dependencies(pfe_input_cycle_item req);
    longint unsigned seq = generated_packets;
    req.first_seq_hint = generated_packets;
    for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
      int unsigned max_dp;
      if (!req.lane_vld[lane]) continue;
      max_dp = (seq < 7) ? int'(seq) : 7;
      if (int'(req.dp[lane]) > max_dp)
        req.dp[lane] = (max_dp == 0) ? 0 :
                       pfe_dp_t'($urandom_range(max_dp, 0));
      // Keep the payload random while making accidental equality between
      // neighboring packets vanishingly unlikely.
      req.data[lane] ^= {64'h0, seq};
      seq++;
    end
  endfunction

  task send_beat(pfe_input_cycle_item req);
    prepare_dependencies(req);
    start_item(req);
    finish_item(req);
    generated_packets += longint'(req.packet_count());
    generated_beats++;
  endtask

  task send_idle(int unsigned cycles = 1);
    repeat (cycles) begin
      pfe_input_cycle_item req = make_random_beat('0, "idle");
      send_beat(req);
    end
  endtask

  virtual task body();
    repeat (20) begin
      bit [`PFE_MAX_LANES-1:0] mask;
      mask = pfe_lane_mask_t'(
        $urandom_range((1 << p_sequencer.cfg.lane_num)-1, 0));
      send_beat(make_random_beat(mask));
    end
  endtask
endclass

class pfe_smoke_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_smoke_sequence)
  function new(string name = "pfe_smoke_sequence"); super.new(name); endfunction
  task body();
    repeat (24) begin
      pfe_input_cycle_item req;
      bit [`PFE_MAX_LANES-1:0] mask;
      mask = pfe_lane_mask_t'(
        $urandom_range((1 << p_sequencer.cfg.lane_num)-1, 1));
      req = make_random_beat(mask);
      send_beat(req);
      if ($urandom_range(0, 4) == 0) send_idle(1);
    end
  endtask
endclass

class pfe_random_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_random_sequence)
  function new(string name = "pfe_random_sequence"); super.new(name); endfunction
  task body();
    repeat (p_sequencer.cfg.random_beats) begin
      bit [`PFE_MAX_LANES-1:0] mask;
      mask = pfe_lane_mask_t'(
        $urandom_range((1 << p_sequencer.cfg.lane_num)-1, 0));
      send_beat(make_random_beat(mask));
    end
  endtask
endclass

class pfe_no_dependency_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_no_dependency_sequence)
  function new(string name = "pfe_no_dependency_sequence"); super.new(name); endfunction
  task body();
    repeat (64) begin
      pfe_input_cycle_item req;
      bit [`PFE_MAX_LANES-1:0] mask;
      mask = pfe_lane_mask_t'(
        $urandom_range((1 << p_sequencer.cfg.lane_num)-1, 1));
      req = make_random_beat(mask);
      for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) req.dp[lane] = 0;
      send_beat(req);
    end
  endtask
endclass

class pfe_dependency_distance_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_dependency_distance_sequence)
  function new(string name = "pfe_dependency_distance_sequence"); super.new(name); endfunction
  task body();
    repeat (4) begin
      pfe_input_cycle_item req = make_random_beat(full_mask());
      for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
        longint unsigned seq = generated_packets + longint'(lane);
        req.dp[lane] = pfe_dp_t'((seq < 8) ? seq : (seq % 8));
      end
      send_beat(req);
    end
    for (int distance = 1; distance <= 7; distance++) begin
      repeat (4) begin
        pfe_input_cycle_item req = make_random_beat(full_mask());
        for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++)
          req.dp[lane] = distance[2:0];
        send_beat(req);
      end
    end
  endtask
endclass

class pfe_dependency_chain_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_dependency_chain_sequence)
  function new(string name = "pfe_dependency_chain_sequence"); super.new(name); endfunction
  task body();
    for (int n = 0; n < 32; n++) begin
      int lane = n % p_sequencer.cfg.lane_num;
      pfe_input_cycle_item req = make_random_beat(1 << lane);
      req.dp[lane] = (generated_packets == 0) ? 0 : 1;
      req.latency[lane] = pfe_latency_t'(n % 4);
      send_beat(req);
    end
  endtask
endclass

class pfe_dependency_fanout_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_dependency_fanout_sequence)
  function new(string name = "pfe_dependency_fanout_sequence"); super.new(name); endfunction
  task body();
    repeat (8) begin
      longint unsigned root_seq;
      pfe_input_cycle_item root = make_random_beat(1);
      root.dp[0] = 0;
      root.latency[0] = 3;
      root_seq = generated_packets;
      send_beat(root);
      for (int child = 1; child <= 7; child++) begin
        int lane = child % p_sequencer.cfg.lane_num;
        pfe_input_cycle_item req = make_random_beat(1 << lane);
        req.dp[lane] = pfe_dp_t'(generated_packets - root_seq);
        req.latency[lane] = pfe_latency_t'(child % 4);
        send_beat(req);
      end
    end
  endtask
endclass

class pfe_latency_matrix_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_latency_matrix_sequence)
  function new(string name = "pfe_latency_matrix_sequence"); super.new(name); endfunction
  task body();
    for (int lat = 0; lat < 4; lat++) begin
      for (int dep = 0; dep < 8; dep++) begin
        pfe_input_cycle_item req = make_random_beat(full_mask());
        for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
          req.latency[lane] = lat[1:0];
          req.dp[lane] = dep[2:0];
        end
        send_beat(req);
      end
    end
  endtask
endclass

class pfe_sparse_lane_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_sparse_lane_sequence)
  function new(string name = "pfe_sparse_lane_sequence"); super.new(name); endfunction
  task body();
    for (int mask = 1; mask < (1 << p_sequencer.cfg.lane_num); mask++) begin
      pfe_input_cycle_item req = make_random_beat(pfe_lane_mask_t'(mask));
      send_beat(req);
      if ((mask % 3) == 0) send_idle(1);
    end
  endtask
endclass

class pfe_output_wrap_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_output_wrap_sequence)
  function new(string name = "pfe_output_wrap_sequence"); super.new(name); endfunction
  task body();
    bit [`PFE_MAX_LANES-1:0] masks[$];
    masks.push_back((1 << (p_sequencer.cfg.lane_num-1))-1);
    masks.push_back(3);
    masks.push_back(1);
    masks.push_back(full_mask());
    repeat (12) begin
      foreach (masks[i]) begin
        pfe_input_cycle_item req = make_random_beat(masks[i]);
        for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) req.dp[lane] = 0;
        send_beat(req);
      end
    end
  endtask
endclass

class pfe_backpressure_stress_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_backpressure_stress_sequence)
  function new(string name = "pfe_backpressure_stress_sequence"); super.new(name); endfunction
  task body();
    repeat (256) begin
      pfe_input_cycle_item req = make_random_beat(full_mask());
      for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
        req.latency[lane] = 3;
        req.dp[lane] = 0;
      end
      send_beat(req);
    end
  endtask
endclass

class pfe_fe_parallel_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_fe_parallel_sequence)
  function new(string name = "pfe_fe_parallel_sequence"); super.new(name); endfunction
  task body();
    for (int lat = 0; lat < 4; lat++) begin
      repeat (32) begin
        pfe_input_cycle_item req = make_random_beat(full_mask());
        for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
          req.latency[lane] = lat[1:0];
          req.dp[lane] = 0;
        end
        send_beat(req);
      end
    end
  endtask
endclass

class pfe_scheduler_corner_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_scheduler_corner_sequence)
  function new(string name = "pfe_scheduler_corner_sequence"); super.new(name); endfunction
  task body();
    repeat (12) begin
      longint unsigned root_seq;
      pfe_input_cycle_item root = make_random_beat(1);
      root.dp[0] = 0;
      root.latency[0] = 3;
      root_seq = generated_packets;
      send_beat(root);

      for (int child = 1; child <= 7; child++) begin
        int lane = child % p_sequencer.cfg.lane_num;
        pfe_input_cycle_item dep = make_random_beat(1 << lane);
        dep.dp[lane] = pfe_dp_t'(generated_packets-root_seq);
        dep.latency[lane] = pfe_latency_t'(3-(child%4));
        send_beat(dep);
      end
      repeat (8) begin
        pfe_input_cycle_item free_pkt = make_random_beat(full_mask());
        for (int lane = 0; lane < p_sequencer.cfg.lane_num; lane++) begin
          free_pkt.dp[lane] = 0;
          free_pkt.latency[lane] = pfe_latency_t'(
            (generated_packets+longint'(lane)) % 4);
        end
        send_beat(free_pkt);
      end
    end
  endtask
endclass

class pfe_performance_sequence extends pfe_base_sequence;
  `uvm_object_utils(pfe_performance_sequence)
  function new(string name = "pfe_performance_sequence"); super.new(name); endfunction
  task body();
    if (p_sequencer.cfg.lane_num != 4)
      `uvm_fatal("PERF_TOPOLOGY", "pfe_performance_sequence requires LANE_NUM=4")

    // Phase A: latency-1 saturated independent traffic.
    repeat (128) begin
      pfe_input_cycle_item req = make_random_beat(full_mask());
      for (int lane = 0; lane < 4; lane++) begin
        req.latency[lane] = 0;
        req.dp[lane] = 0;
      end
      send_beat(req);
    end
    // Phase B: latency-4 saturated independent traffic.
    repeat (128) begin
      pfe_input_cycle_item req = make_random_beat(full_mask());
      for (int lane = 0; lane < 4; lane++) begin
        req.latency[lane] = 3;
        req.dp[lane] = 0;
      end
      send_beat(req);
    end
    // Phase C: mix slow dependencies with free packets to expose HOL stalls.
    repeat (32) begin
      pfe_input_cycle_item req = make_random_beat(full_mask());
      for (int lane = 0; lane < 4; lane++) begin
        req.latency[lane] = (lane == 0) ? 3 : 0;
        req.dp[lane] = pfe_dp_t'(
          (generated_packets > 7 && lane != 3) ? (lane+1) : 0);
      end
      send_beat(req);
    end
  endtask
endclass
