// M13-6: an edge-descriptor list on a timing-check event must select
// WHICH transitions arm the check (IEEE 1800-2017 31.4.2 / 1364 15.5).
//
// The synthesized checker tracks the event signal's previous value so it
// can match a (previous, current) transition against the descriptors, but
// that tracker was only ever written from an `always @(sig)' block, which
// does not run at time 0. It therefore sat at the x sentinel until the
// FIRST transition -- and that transition consequently matched no
// descriptor at all.
//
// The failure mode was worse than ignoring the descriptor: for a signal
// starting at 0, `$setup(edge[01] d, ...)' reported NOTHING where plain
// `$setup(d, ...)' reported the violation, so adding a descriptor silently
// discarded a real violation. The tracker is now primed at time 0 from the
// signal's own value.
//
// Requires -gspecify; the whole specify block is inert without it, which is
// the established opt-in and is deliberately silent.
//
// Same stimulus reaches all three instances, so the violation COUNTS and
// TIMES are what discriminate:
//   d rises at t=10, clock at t=11 -> setup 1 < 10, transition 0->1
//   d falls at t=31, clock at t=32 -> setup 1 < 10, transition 1->0
// so:  edge[01]     -> only t=11
//      edge[10]     -> only t=32
//      edge[01,10]  -> both
//      no descriptor-> both

module dut_rise(input clk, d);
  specify $setup(edge[01] d, posedge clk, 10); endspecify
endmodule

module dut_fall(input clk, d);
  specify $setup(edge[10] d, posedge clk, 10); endspecify
endmodule

module dut_both(input clk, d);
  specify $setup(edge[01,10] d, posedge clk, 10); endspecify
endmodule

module dut_any(input clk, d);
  specify $setup(d, posedge clk, 10); endspecify
endmodule

module main;

  reg clk_r = 0;
  reg clk_f = 0;
  reg clk_b = 0;
  reg clk_a = 0;
  reg d = 0;

  dut_rise u_rise(clk_r, d);
  dut_fall u_fall(clk_f, d);
  dut_both u_both(clk_b, d);
  dut_any  u_any (clk_a, d);

  task automatic clk_all(input value);
    begin
      clk_r = value;
      clk_f = value;
      clk_b = value;
      clk_a = value;
    end
  endtask

  initial begin
    // First transition of d: 0 -> 1 at t=10. This is the one the unprimed
    // tracker used to swallow.
    #10 d = 1;
    #1  clk_all(1'b1);
    #10 clk_all(1'b0);

    // Second transition: 1 -> 0 at t=31.
    #10 d = 0;
    #1  clk_all(1'b1);
    #10 clk_all(1'b0);

    #5 $display("PASSED");
    $finish(0);
  end

endmodule
