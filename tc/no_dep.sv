class no_dep extends pfe_base_test;
  `uvm_component_utils(no_dep)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function pfe_base_sequence create_main_sequence();
    return pfe_no_dependency_sequence::type_id::create("main_sequence");
  endfunction
endclass
