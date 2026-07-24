// Generic interface ports (IEEE 1800-2017 25.3.3): `interface i` and
// `interface.mp i` formals typed per instantiation from the connected
// actual — including the same generic module bound to two DIFFERENT
// interfaces, and a one-level pass-through of the formal to a nested
// generic port. Was a loud sorry.
interface if_a(input logic clk);
  logic [7:0] data;
  logic valid;
  modport mon (input data, valid, clk);
endinterface

interface if_b(input logic clk);
  logic [15:0] data;
  logic valid;
endinterface

module probe(interface i);
  int seen = 0;
  logic [15:0] last = 0;
  always @(posedge i.clk)
    if (i.valid) begin
      seen++;
      last = i.data;
    end
endmodule

module probe_mp(interface.mon i);
  int seen = 0;
  always @(posedge i.clk) if (i.valid) seen++;
endmodule

module inner(interface i);
  int seen = 0;
  always @(posedge i.clk) if (i.valid) seen++;
endmodule

module outer(interface i);
  inner u(i);   // forward the generic formal
endmodule

module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  logic clk = 0;
  always #5 clk = ~clk;
  if_a ia(clk);
  if_b ib(clk);

  probe pa(ia);          // one generic module...
  probe pb(ib);          // ...two different interfaces
  probe_mp pm(ia.mon);   // generic with modport actual
  outer po(ia);          // pass-through

  initial begin
    @(negedge clk) begin
       ia.data = 8'hA5;    ia.valid = 1;
       ib.data = 16'hBEEF; ib.valid = 1;
    end
    @(negedge clk) begin ia.valid = 0; ib.valid = 0; end
    #12;
    check("per-instance typing", main.pa.last == 16'h00A5
          && main.pb.last == 16'hBEEF);
    check("counts", main.pa.seen == 1 && main.pb.seen == 1);
    check("modport actual", main.pm.seen == 1);
    check("pass-through", main.po.u.seen == 1);
    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
