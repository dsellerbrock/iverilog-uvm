package p;
  typedef struct packed { logic v; logic [7:0] d; } t;
endpackage
module m #(parameter int N = 2) (input p::t a, output p::t o [N]);
  for (genvar i = 0; i < N; i++) begin : g
    assign o[i].v = a.v;
    assign o[i].d = a.d;
  end
endmodule
module top;
  p::t a; p::t o [2];
  m #(.N(2)) u (.a(a), .o(o));
  initial begin
    a.v = 1; a.d = 8'hA5; #1;
    if (o[0].v===1 && o[0].d===8'hA5 && o[1].d===8'hA5) $display("PASSED");
    else $display("FAILED o0=%b/%h o1=%b/%h", o[0].v,o[0].d,o[1].v,o[1].d);
  end
endmodule
