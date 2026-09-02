`ifndef PFE_DEFINES_SVH
`define PFE_DEFINES_SVH

// The contest RTL selects its topology with cumulative LANE_x macros.  Test
// the highest selector first because, for example, LANE_7 may also enable the
// lower-lane helper macros used to instantiate FE_1 through FE_7.
`ifdef LANE_7
  `define PFE_RTL_LANE_NUM 7
`elsif LANE_6
  `define PFE_RTL_LANE_NUM 6
`elsif LANE_5
  `define PFE_RTL_LANE_NUM 5
`elsif LANE_4
  `define PFE_RTL_LANE_NUM 4
`elsif LANE_3
  `define PFE_RTL_LANE_NUM 3
`elsif LANE_2
  `define PFE_RTL_LANE_NUM 2
`endif

`ifndef PFE_LANE_NUM
  `ifdef PFE_RTL_LANE_NUM
    `define PFE_LANE_NUM `PFE_RTL_LANE_NUM
    `define PFE_LANE_NUM_FROM_RTL
  `else
    // Keep a numeric value available so parsing/elaboration can finish far
    // enough for harness to issue a clear error in a real-DUT auto run.
    `define PFE_LANE_NUM 4
    `ifdef PFE_REAL_DUT
      `define PFE_LANE_NUM_RTL_MISSING
    `else
      `define PFE_LANE_NUM_FALLBACK
    `endif
  `endif
`endif

`define PFE_MIN_LANES 3
`define PFE_MAX_LANES 7
`define PFE_DATA_W    128
`define PFE_CTRL_W    5

`endif
