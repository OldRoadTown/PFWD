class backpressure extends pfe_base_test;
  `uvm_component_utils(backpressure)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function pfe_base_sequence create_main_sequence();
    return pfe_backpressure_stress_sequence::type_id::create("main_sequence");
  endfunction
endclass
