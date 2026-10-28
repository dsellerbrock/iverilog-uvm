typedef struct { int x; int a[string]; } SA;
module top; SA s; initial begin s = '{default:5}; $display("ASSOC_EXISTS=%0d ASSOC_VALUE=%0d", s.a.exists("k"), s.a["k"]); end endmodule
