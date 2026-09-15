package p; string state="mutable"; function automatic string f; return state; endfunction endpackage
module test; localparam string X=p::f(); endmodule
