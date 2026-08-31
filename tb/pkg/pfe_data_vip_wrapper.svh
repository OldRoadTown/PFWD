// The encrypted contest function is included inside pfe_uvm_pkg when
// PFE_USE_REAL_DATA_VIP is defined. Put data_caculate_vip.sv on +incdir.
`ifdef PFE_USE_REAL_DATA_VIP
  `include "data_caculate_vip.sv"
`else
  // Open deterministic fallback used only to compile and self-check the TB.
  // It is deliberately not presented as the contest golden calculation.
  function automatic void data_caculate_vip(
    input  bit [127:0] i_data_in,
    input  bit [1:0]   i_lat_in,
    output bit [127:0] data_cal_o
  );
    int unsigned shift;
    bit [127:0] rotated;
    shift = (int'(i_lat_in) + 1) * 13;
    rotated = (i_data_in << shift) | (i_data_in >> (128-shift));
    data_cal_o = rotated ^ {32'h9e37_79b9, 30'b0, i_lat_in,
                            32'h7f4a_7c15, 32'hd1b5_4a32};
  endfunction
`endif

function automatic bit [127:0] pfe_calculate(
  input bit [127:0] source_data,
  input bit [1:0]   latency
);
  bit [127:0] result;
  data_caculate_vip(source_data, latency, result);
  return result;
endfunction
