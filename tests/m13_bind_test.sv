// M13: SystemVerilog bind directives (IEEE 1800-2017 23.11).
// Covers: description-level bind, module-item bind, named/positional
// parameter overrides, port connections to target-INTERNAL signals,
// multiple instances per directive, multiple dut instances each
// receiving the bound instances, bind into an interface, and a bound
// SVA checker (the canonical bind use case) firing on a violation.

module m13b_dut(input logic clk, input logic [3:0] d);
  logic [3:0] q;               // internal, not a port
  always @(posedge clk) q <= d;
endmodule

module m13b_watcher #(parameter int GAIN = 1)
                    (input logic clk, input logic [3:0] v);
  int acc = 0;
  always @(posedge clk) acc += v * GAIN;
endmodule

module m13b_sva_chk(input logic clk, input int cnt);
  int violations = 0;
  a_nonneg: assert property (@(posedge clk) cnt >= 0)
    else violations++;
endmodule

module m13b_fifo(input logic clk, input logic push, input logic pop);
  // NBA-driven: the M9 assertion engine's sampling model equals
  // Preponed for NBA-driven logic (blocking updates racing the clock
  // edge are a documented race, in event semantics too).
  int count = 0;
  always @(posedge clk) count <= count + (push ? 1 : 0) - (pop ? 1 : 0);
endmodule

interface m13b_bus_if(input logic clk);
  logic [7:0] data;
  logic valid;
endinterface

module m13b_ifc_chk(input logic clk, input logic v);
  int vcount = 0;
  always @(posedge clk) if (v) vcount++;
endmodule

// Description-level binds: named parameter override observing an
// INTERNAL signal; positional override with two instances at once.
bind m13b_dut m13b_watcher #(.GAIN(10)) w_q(.clk(clk), .v(q));
bind m13b_dut m13b_watcher #(2) w_d(.clk(clk), .v(d)), w_d2(.clk(clk), .v(d));
// SVA checker bound into the fifo, reading its internal count.
bind m13b_fifo m13b_sva_chk chk(.clk(clk), .cnt(count));
// Bind into an interface definition.
bind m13b_bus_if m13b_ifc_chk pc(.clk(clk), .v(valid));

module m13b_mid(input logic clk);
  logic [3:0] d = 4'd3;
  m13b_dut u_in(.clk(clk), .d(d));
endmodule

module m13_bind_test_top;
  logic clk = 0;
  logic [3:0] d = 4'd1;
  logic push = 0, pop = 0;

  m13b_dut  u0(.clk(clk), .d(d));
  m13b_mid  m0(.clk(clk));
  m13b_fifo f0(.clk(clk), .push(push), .pop(pop));
  m13b_bus_if bus(.clk(clk));

  // Module-item-level bind is also legal.
  bind m13b_dut m13b_watcher #(.GAIN(100)) w_mi(.clk(clk), .v(d));

  int errors = 0;
  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d expected=%0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    bus.valid = 1;
    pop = 1;                    // drive fifo count negative
    repeat (4) #5 clk = ~clk;   // 2 posedges
    pop = 0;
    #1;

    // u0: d=1. w_q sees q (x->0 first edge, then 1): 0*10 + 1*10 = 10.
    check("u0.w_q.acc", u0.w_q.acc, 10);
    check("u0.w_d.acc", u0.w_d.acc, 4);      // 1*2 * 2 edges
    check("u0.w_d2.acc", u0.w_d2.acc, 4);
    check("u0.w_mi.acc", u0.w_mi.acc, 200);  // 1*100 * 2 edges
    // m0.u_in: d=3, GAIN=2, 2 edges => 12
    check("m0.u_in.w_d.acc", m0.u_in.w_d.acc, 12);
    check("m0.u_in.w_q.acc", m0.u_in.w_q.acc, 30);  // q: 0,3 -> 3*10
    // fifo: count goes 0,-1,-2 sampled at 2 posedges -> cnt>=0 fails
    // at the second edge only (first edge samples count==0).
    check("fifo violations", f0.chk.violations, 1);
    check("fifo count", f0.count, -2);
    // interface bind: valid high for 2 posedges
    check("bus.pc.vcount", bus.pc.vcount, 2);

    if (errors == 0) $display("PASS: m13 bind semantics");
    else $display("FAIL: m13 bind semantics (%0d errors)", errors);
    $finish(0);
  end
endmodule
