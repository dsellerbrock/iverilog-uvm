// A declared sequence used as an operand of `intersect' or `within' must be
// the same sequence as its inline spelling (IEEE 1800-2017/2023 16.8, 16.9.6,
// 16.9.10). The operand was left as a bare identifier, bound later as a
// variable ("Unable to bind wire/reg/memory"), and its length was judged
// before the declaration was spliced in.
module main;
  logic clk = 0;
  logic a, b, c, d;
  always #5 clk = ~clk;

  sequence s_ab; a ##1 b; endsequence
  sequence s_bc; b ##1 c; endsequence
  sequence s_var; b ##[1:2] c; endsequence
  sequence s_wide; a ##[0:3] c; endsequence

  int named_fixed, inline_fixed, named_var, inline_var;
  int named_within, inline_within, named_within_fixed, inline_within_fixed;

  assert property (@(posedge clk) s_ab intersect s_bc) else named_fixed++;
  assert property (@(posedge clk) (a ##1 b) intersect (b ##1 c)) else inline_fixed++;
  assert property (@(posedge clk) s_ab intersect s_var) else named_var++;
  assert property (@(posedge clk) (a ##1 b) intersect (b ##[1:2] c)) else inline_var++;
  assert property (@(posedge clk) s_bc within s_wide) else named_within++;
  assert property (@(posedge clk) (b ##1 c) within (a ##[0:3] c)) else inline_within++;
  assert property (@(posedge clk) s_bc within (a ##3 c)) else named_within_fixed++;
  assert property (@(posedge clk) (b ##1 c) within (a ##3 c)) else inline_within_fixed++;

  // A fixed pattern that exercises every operator. Each pair counts the failed
  // attempts of the same property written with a declared and an inline
  // sequence; the counts must agree and must not be trivial.
  logic [39:0] pa = 40'b0101_0100_1101_0110_1010_0101_1100_1011_0110_1001;
  logic [39:0] pb = 40'b1011_0110_0101_1010_0110_1001_0011_1101_1001_0110;
  logic [39:0] pc = 40'b0110_1101_1010_0011_0101_1011_1010_0110_0101_1011;
  logic [39:0] pd = 40'b1001_0010_0110_1101_1001_0110_0101_1001_1010_0100;
  int errors;

  task automatic check(string what, int named, int inline_count);
    if (named !== inline_count) begin
      $display("FAILED %s: named %0d inline %0d", what, named, inline_count);
      errors++;
    end
    if (inline_count == 0 || inline_count >= 40) begin
      $display("FAILED %s: pattern is trivial (%0d failures)", what, inline_count);
      errors++;
    end
  endtask

  initial begin
    for (int i = 0; i < 40; i++) begin
      @(negedge clk);
      a = pa[i]; b = pb[i]; c = pc[i]; d = pd[i];
      if (i inside {10, 11, 12, 26, 27, 28}) begin a = 1; b = 1; c = 1; end
    end
    repeat (4) @(negedge clk);
    check("fixed intersect", named_fixed, inline_fixed);
    check("variable intersect", named_var, inline_var);
    check("variable within", named_within, inline_within);
    check("fixed within", named_within_fixed, inline_within_fixed);
    if (errors == 0) $display("PASSED");
    $finish(0);
  end
endmodule
