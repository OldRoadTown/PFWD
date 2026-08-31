typedef enum int {
  PFE_ERR_DEPENDENCY,
  PFE_ERR_FE_DISPATCH,
  PFE_ERR_FE_DATA,
  PFE_ERR_ORDER,
  PFE_ERR_DROP_DUP,
  PFE_ERR_TIMEOUT,
  PFE_ERR_PERFORMANCE
} pfe_error_kind_e;

typedef bit [`PFE_MAX_LANES-1:0] pfe_lane_mask_t;
typedef bit [2:0] pfe_dp_t;
typedef bit [1:0] pfe_latency_t;

class pfe_input_cycle_item extends uvm_sequence_item;
  rand pfe_lane_mask_t lane_vld;
  rand bit [127:0] data    [`PFE_MAX_LANES];
  rand pfe_latency_t latency [`PFE_MAX_LANES];
  rand pfe_dp_t      dp      [`PFE_MAX_LANES];

  int unsigned     lane_num;
  longint unsigned first_seq_hint;

  constraint c_lane_num {
    lane_num inside {[`PFE_MIN_LANES:`PFE_MAX_LANES]};
  }

  constraint c_inactive_lanes {
    foreach (lane_vld[i]) {
      if (i >= lane_num) lane_vld[i] == 1'b0;
      if (!lane_vld[i]) {
        data[i]    == '0;
        latency[i] == '0;
        dp[i]      == '0;
      }
    }
  }

  `uvm_object_utils(pfe_input_cycle_item)

  function new(string name = "pfe_input_cycle_item");
    super.new(name);
    lane_num = `PFE_LANE_NUM;
  endfunction

  function int unsigned packet_count();
    int unsigned count = 0;
    for (int i = 0; i < lane_num; i++) count += lane_vld[i];
    return count;
  endfunction

  function string convert2string();
    return $sformatf("lanes=%0d mask=0x%0h first_seq=%0d packets=%0d",
                     lane_num, lane_vld, first_seq_hint, packet_count());
  endfunction
endclass

class pfe_packet extends uvm_sequence_item;
  bit [127:0]      data;
  bit [1:0]        latency;
  bit [2:0]        dp;
  int unsigned     input_lane;
  longint unsigned seq_num;
  longint unsigned accepted_cycle;
  longint unsigned dispatch_cycle;
  longint unsigned completion_cycle;
  longint unsigned output_cycle;
  longint unsigned dependency_seq;
  bit [127:0]      expected_dp_data;
  bit [127:0]      expected_data;
  bit              dispatched;
  bit              completed;
  bit              output_seen;
  int              engine_lane = -1;
  int unsigned     input_beat_count;
  bit [`PFE_MAX_LANES-1:0] input_lane_mask;

  `uvm_object_utils_begin(pfe_packet)
    `uvm_field_int(data, UVM_HEX)
    `uvm_field_int(latency, UVM_DEC)
    `uvm_field_int(dp, UVM_DEC)
    `uvm_field_int(input_lane, UVM_DEC)
    `uvm_field_int(seq_num, UVM_DEC)
    `uvm_field_int(accepted_cycle, UVM_DEC)
    `uvm_field_int(dispatch_cycle, UVM_DEC)
    `uvm_field_int(completion_cycle, UVM_DEC)
    `uvm_field_int(output_cycle, UVM_DEC)
    `uvm_field_int(dependency_seq, UVM_DEC)
    `uvm_field_int(expected_dp_data, UVM_HEX)
    `uvm_field_int(expected_data, UVM_HEX)
    `uvm_field_int(dispatched, UVM_BIN)
    `uvm_field_int(completed, UVM_BIN)
    `uvm_field_int(output_seen, UVM_BIN)
    `uvm_field_int(engine_lane, UVM_DEC)
    `uvm_field_int(input_beat_count, UVM_DEC)
    `uvm_field_int(input_lane_mask, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "pfe_packet");
    super.new(name);
  endfunction
endclass

class pfe_fe_req extends uvm_sequence_item;
  int unsigned     engine_lane;
  bit [127:0]      data;
  bit [1:0]        latency;
  bit              dp_vld;
  bit [127:0]      dp_data;
  int unsigned     beat_parallelism;
  longint unsigned cycle;

  `uvm_object_utils_begin(pfe_fe_req)
    `uvm_field_int(engine_lane, UVM_DEC)
    `uvm_field_int(data, UVM_HEX)
    `uvm_field_int(latency, UVM_DEC)
    `uvm_field_int(dp_vld, UVM_BIN)
    `uvm_field_int(dp_data, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "pfe_fe_req");
    super.new(name);
  endfunction
endclass

class pfe_fe_rsp extends uvm_sequence_item;
  int unsigned     engine_lane;
  bit [127:0]      data;
  longint unsigned cycle;

  `uvm_object_utils_begin(pfe_fe_rsp)
    `uvm_field_int(engine_lane, UVM_DEC)
    `uvm_field_int(data, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "pfe_fe_rsp");
    super.new(name);
  endfunction
endclass

class pfe_out_packet extends uvm_sequence_item;
  int unsigned     lane;
  bit [127:0]      data;
  int unsigned     beat_count;
  int unsigned     beat_start_lane;
  bit              wrapped;
  longint unsigned cycle;

  `uvm_object_utils_begin(pfe_out_packet)
    `uvm_field_int(lane, UVM_DEC)
    `uvm_field_int(data, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "pfe_out_packet");
    super.new(name);
  endfunction
endclass

class pfe_reset_event extends uvm_sequence_item;
  bit              asserted;
  longint unsigned cycle;
  `uvm_object_utils(pfe_reset_event)
  function new(string name = "pfe_reset_event");
    super.new(name);
  endfunction
endclass
