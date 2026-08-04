module fifo #(parameter W=4) (input logic [W-1:0] d, output logic [W-1:0] q);
  assign q = d;
endmodule
module chk #(parameter W=4) (input logic [W-1:0] d, q);
  initial #1 if (q !== d) $display("FAILED chk W=%0d", W); else $display("CHK_OK_%0d", W);
endmodule
module binder;
  bind i_one chk #(.W(4)) u_chk (.d(d), .q(q));
endmodule
module main;
  logic [3:0] a = 4'h9;
  logic [3:0] y;
  fifo #(.W(4)) i_one (.d(a), .q(y));
  fifo #(.W(4)) i_two (.d(a), .q());
  initial #2 $display("PASSED");
endmodule
