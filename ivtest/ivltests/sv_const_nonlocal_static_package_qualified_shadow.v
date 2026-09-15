package p; int state=7; function automatic int f; int state=3; return p::state+state; endfunction endpackage
module test; localparam int X=p::f(); endmodule
