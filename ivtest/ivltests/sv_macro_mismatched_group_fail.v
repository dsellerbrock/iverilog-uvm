`define SECOND(a, b) b

module sv_macro_mismatched_group_fail;
  initial $display(`SECOND((1,2}, 73));
endmodule
