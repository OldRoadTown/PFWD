`ifndef PFE_LINT_UVM_MACROS_SVH
`define PFE_LINT_UVM_MACROS_SVH

`define uvm_object_utils(T) typedef uvm_object_registry#(T) type_id;
`define uvm_component_utils(T) typedef uvm_component_registry#(T) type_id;
`define uvm_object_utils_begin(T) typedef uvm_object_registry#(T) type_id;
`define uvm_object_utils_end
`define uvm_field_int(ARG, FLAG)
`define uvm_field_real(ARG, FLAG)
`define uvm_field_string(ARG, FLAG)
`define uvm_declare_p_sequencer(SEQR) SEQR p_sequencer;

`define uvm_info(ID, MSG, VERBOSITY) begin $display("%s: %s", ID, MSG); end
`define uvm_warning(ID, MSG) begin $warning("%s: %s", ID, MSG); end
`define uvm_error(ID, MSG) begin $error("%s: %s", ID, MSG); end
`define uvm_fatal(ID, MSG) begin $error("%s: %s", ID, MSG); end

`define uvm_analysis_imp_decl(SFX) \
class uvm_analysis_imp``SFX #(type T = uvm_object, type IMP = uvm_component) \
  extends uvm_analysis_if#(T); \
  IMP implementation; \
  function new(string name, IMP implementation); \
    this.implementation = implementation; \
  endfunction \
  virtual function void write(T value); implementation.write``SFX(value); endfunction \
endclass

`endif
