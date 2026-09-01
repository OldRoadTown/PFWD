class dep_fanout extends pfe_base_test;
  `uvm_component_utils(dep_fanout)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function pfe_base_sequence create_main_sequence();
    return pfe_dependency_fanout_sequence::type_id::create("main_sequence");
  endfunction
endclass
