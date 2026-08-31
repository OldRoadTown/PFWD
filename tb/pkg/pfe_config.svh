class pfe_env_cfg extends uvm_object;
  virtual pfe_if #(`PFE_LANE_NUM) vif;

  int unsigned lane_num             = `PFE_LANE_NUM;
  int unsigned random_beats         = 200;
  int unsigned drain_timeout_cycles = 10000;
  int unsigned watchdog_cycles      = 20000;
  int unsigned reset_cycles         = 6;
  bit          active_input_agent   = 1'b1;
  bit          enable_fe_checks     = 1'b1;
  bit          enable_perf_checks   = 1'b1;

  real perf_base_throughput = -1.0;
  real perf_min_tput_ratio  = 0.90;
  real perf_base_avg_e2e    = -1.0;
  real perf_max_e2e_ratio   = 1.10;
  real perf_base_bkpr_ratio = -1.0;
  real perf_max_bkpr_delta  = 0.05;
  string perf_result_file   = "pfe_perf.csv";

  `uvm_object_utils_begin(pfe_env_cfg)
    `uvm_field_int(lane_num, UVM_DEC)
    `uvm_field_int(random_beats, UVM_DEC)
    `uvm_field_int(drain_timeout_cycles, UVM_DEC)
    `uvm_field_int(watchdog_cycles, UVM_DEC)
    `uvm_field_int(reset_cycles, UVM_DEC)
    `uvm_field_int(active_input_agent, UVM_BIN)
    `uvm_field_int(enable_fe_checks, UVM_BIN)
    `uvm_field_int(enable_perf_checks, UVM_BIN)
    `uvm_field_real(perf_base_throughput, UVM_DEC)
    `uvm_field_real(perf_min_tput_ratio, UVM_DEC)
    `uvm_field_real(perf_base_avg_e2e, UVM_DEC)
    `uvm_field_real(perf_max_e2e_ratio, UVM_DEC)
    `uvm_field_string(perf_result_file, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "pfe_env_cfg");
    super.new(name);
  endfunction

  function void load_plusargs();
    void'($value$plusargs("PFE_RANDOM_BEATS=%d", random_beats));
    void'($value$plusargs("PFE_DRAIN_TIMEOUT=%d", drain_timeout_cycles));
    void'($value$plusargs("PFE_WATCHDOG=%d", watchdog_cycles));
    void'($value$plusargs("PFE_PERF_FILE=%s", perf_result_file));
    void'($value$plusargs("PFE_BASE_TPUT=%f", perf_base_throughput));
    void'($value$plusargs("PFE_MIN_TPUT_RATIO=%f", perf_min_tput_ratio));
    void'($value$plusargs("PFE_BASE_E2E=%f", perf_base_avg_e2e));
    void'($value$plusargs("PFE_MAX_E2E_RATIO=%f", perf_max_e2e_ratio));
    void'($value$plusargs("PFE_BASE_BKPR=%f", perf_base_bkpr_ratio));
    void'($value$plusargs("PFE_MAX_BKPR_DELTA=%f", perf_max_bkpr_delta));
  endfunction
endclass
