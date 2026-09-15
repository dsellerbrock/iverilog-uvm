package p; string state; function automatic string f; return state; endfunction endpackage
module test; localparam string X=p::f(); endmodule
