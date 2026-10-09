`define A
`ifdef(A && B)
module should_not_compile;
`endif

module test;
endmodule
