// R1: a bit- or part-select assertion operand must be sampled in the
// Preponed region, like a whole-signal operand (IEEE 1800-2017 16.5.1).
//
// M6B-4 routed whole-signal operands through %load/preponed but left selects
// alone, because %load/preponed reads a whole signal. So one assertion could
// mix two sampling regions: `flag' saw its Preponed value while `v[0]' saw
// its live one, and a blocking write in the same time slot as the clock was
// visible to the select and invisible to the whole signal. The select now
// samples the whole signal and applies the select to that value.
//
// The discriminator is the comparison, not the count: every operand below is
// written with a BLOCKING assignment in the same time slot as the clock
// edge, and every Preponed value is 0, so every assertion must fail on every
// edge. Against the pre-fix compiler this printed bit=0 part=0 whole=2 --
// the selects read the new value and the assertions wrongly PASSED, which is
// exactly the failure mode a pass/fail count alone cannot see.
//
// R11 follow-on: a HIERARCHICAL operand (`u.q', `u.q[0]') samples too. The
// history enable is a system task taking the signal, so a hierarchical
// reference in the checker's own initial block reaches the other scope's
// signal perfectly well -- it had simply been excluded. Only a
// package-qualified name still reads live, and it warns.
module sub;
  reg [7:0] q = 8'h00;
endmodule

module main;

  sub u();

  reg clk = 0;

  reg [7:0] up   = 8'h00;   // ascending vector
  reg [0:7] down = 8'h00;   // descending vector
  reg       flag = 1'b0;    // whole-signal control, sampled before this fix

  int f_bit = 0, f_part = 0, f_idx = 0, f_down = 0, f_whole = 0;
  int f_hier = 0, f_hbit = 0;

  always @(posedge clk) assert property (@(posedge clk) up[0])     else f_bit++;
  always @(posedge clk) assert property (@(posedge clk) up[3:0])   else f_part++;
  always @(posedge clk) assert property (@(posedge clk) up[4+:2])  else f_idx++;
  always @(posedge clk) assert property (@(posedge clk) down[7])   else f_down++;
  always @(posedge clk) assert property (@(posedge clk) flag)      else f_whole++;
  always @(posedge clk) assert property (@(posedge clk) u.q)      else f_hier++;
  always @(posedge clk) assert property (@(posedge clk) u.q[0])   else f_hbit++;

  initial begin
    // Two clock edges, each preceded in the SAME time slot by blocking
    // writes that set every operand to 1. The Preponed value is 0 each time.
    #5 up = 8'hFF; down = 8'hFF; flag = 1'b1; u.q = 8'hFF; clk = 1;
    #5 clk = 0; up = 8'h00; down = 8'h00; flag = 1'b0; u.q = 8'h00;
    #5 up = 8'hFF; down = 8'hFF; flag = 1'b1; u.q = 8'hFF; clk = 1;
    #5 clk = 0; up = 8'h00; down = 8'h00; flag = 1'b0; u.q = 8'h00;
    #5;

    if (f_whole == 0)
      $display("FAILED -- the whole-signal control never fired (%0d); the test itself is broken",
               f_whole);
    else if (f_bit != f_whole)
      $display("FAILED -- bit-select=%0d whole=%0d; a bit-select operand is read live",
               f_bit, f_whole);
    else if (f_part != f_whole)
      $display("FAILED -- part-select=%0d whole=%0d; a part-select operand is read live",
               f_part, f_whole);
    else if (f_idx != f_whole)
      $display("FAILED -- indexed part-select=%0d whole=%0d", f_idx, f_whole);
    else if (f_down != f_whole)
      $display("FAILED -- descending-vector select=%0d whole=%0d; the select is applied to the sampled value with the wrong bounds",
               f_down, f_whole);
    else if (f_hier != f_whole)
      $display("FAILED -- hierarchical whole-signal=%0d whole=%0d; a hierarchical operand is read live",
               f_hier, f_whole);
    else if (f_hbit != f_whole)
      $display("FAILED -- hierarchical bit-select=%0d whole=%0d", f_hbit, f_whole);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
