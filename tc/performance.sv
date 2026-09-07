class performance extends pfe_base_test;
  `uvm_component_utils(performance)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function longint unsigned reference_active_cycles(int unsigned lane_num);
    case (lane_num)
      3: return 905;
      4, 5, 6, 7: return 453;
      default: return 0;
    endcase
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.perf_base_active_cycles = reference_active_cycles(cfg.lane_num);
    if (cfg.perf_base_active_cycles == 0)
      `uvm_fatal("PERF_TOPOLOGY",
        $sformatf("no performance reference for lane_num=%0d", cfg.lane_num))
  endfunction

  virtual function pfe_base_sequence create_main_sequence();
    return pfe_performance_sequence::type_id::create("main_sequence");
  endfunction
endclass
