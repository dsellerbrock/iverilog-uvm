`define LIB_A

`ifdef (LIB_A && !LIB_B)
module ifdef_expr_library;
endmodule
`else
module ifdef_expr_library_wrong;
endmodule
`endif
