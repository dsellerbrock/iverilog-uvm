// IEEE 1800-2023 25.6: interface signals reached through a modport port
// are module path terminals, including interface variables written by a
// continuous assignment or an always_ff in the module (the 25.6 example).
// Reads inside the module see the undelayed value, everything else the
// delayed one, as for an ordinary output port (IEEE-unsettled; ruling of
// 2026-11-10).
interface itf;
  logic a, y;
  logic c, d, q;
  modport m(input a, output y);
  modport f(input c, d, output q);
endinterface

module buf1(itf.m ch);
  assign ch.y = ch.a;
  logic own;
  assign own = ch.y;     // the module's own, undelayed view
  specify
    (ch.a => ch.y) = 5;
  endspecify
endmodule

module ff(itf.f ch);
  always_ff @(posedge ch.c) ch.q <= ch.d;
  specify
    (posedge ch.c => (ch.q +: ch.d)) = (5, 6);
  endspecify
endmodule

module top;
  itf i();
  buf1 u(i.m);
  ff   v(i.f);
  reg fail = 0;

  task check(input got, input exp, input [8*8-1:0] what);
    if (got !== exp) begin
      $display("FAILED: t=%0t %0s=%b, expected %b", $time, what, got, exp);
      fail = 1;
    end
  endtask

  initial begin
    i.a = 0; i.c = 0; i.d = 1;
    #10 i.a = 1;
    #1 check(i.y, 1'b0, "y");
       check(u.own, 1'b1, "own");
    #5 check(i.y, 1'b1, "y");          // rise 5 after a
    #4 i.c = 1;                          // t=20: q <= 1
    #4 check(i.q, 1'bx, "q");
    #2 check(i.q, 1'b1, "q");          // rise 5 after the clock edge
    #4 i.c = 0; i.d = 0;
    #10 i.c = 1;                         // t=40: q <= 0
    #5 check(i.q, 1'b1, "q");
    #2 check(i.q, 1'b0, "q");          // fall 6 after the clock edge
    if (!fail) $display("PASSED");
  end
endmodule
