package otbn_trace_repro_pkg;
  typedef struct packed {
    logic loop_hw_intg_err;
  } controller_bad_int_t;
endpackage

interface otbn_trace_repro_if;
  import otbn_trace_repro_pkg::*;
  logic mirrored;
`ifndef EARLY_DECL
  assign mirrored = controller_bad_int_i.loop_hw_intg_err;
  controller_bad_int_t controller_bad_int_i;
`else
  controller_bad_int_t controller_bad_int_i;
  assign mirrored = controller_bad_int_i.loop_hw_intg_err;
`endif
  assign controller_bad_int_i.loop_hw_intg_err = 1'b1;
endinterface

module top;
  otbn_trace_repro_if trace();
  initial begin
    #1;
    if (trace.mirrored !== 1'b1) $fatal(1, "member read failed");
    $display("PASS");
  end
endmodule
