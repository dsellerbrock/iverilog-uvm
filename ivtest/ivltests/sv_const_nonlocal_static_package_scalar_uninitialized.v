package p; int state; function automatic int f; return state; endfunction endpackage
module test; localparam int X=p::f(); endmodule
