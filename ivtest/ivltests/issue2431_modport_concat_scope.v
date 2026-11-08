// IEEE 1800-2017/2023 25.5.4: a modport expression is evaluated in the
// interface. A concatenation port's operands name interface members even
// when the connected instance is named differently from the module's
// interface port, and wherever the module sits in the source.
module early(interface p);
  logic [7:0] r;
  initial begin
    #3 p.W = 8'h34;
    #1 r = p.V;
  end
endmodule

interface J;
  logic [7:0] s = 8'hAB;
  modport C (output .W({s[3:0], s[7:4]}), input .V({s[3:0], s[7:4]}));
endinterface

module late(interface i);
  logic [7:0] r;
  initial begin
    i.W = 8'h12;
    #1 r = i.V;
  end
endmodule

module top;
  J j(), q();
  late k(j.C);
  early e(q.C);
  initial begin
    #2;
    if (j.s !== 8'h21 || k.r !== 8'h12) $display("FAILED j.s=%h k.r=%h", j.s, k.r);
    #3;
    if (q.s !== 8'h43 || e.r !== 8'h34) $display("FAILED q.s=%h e.r=%h", q.s, e.r);
    $display("PASSED");
  end
endmodule
