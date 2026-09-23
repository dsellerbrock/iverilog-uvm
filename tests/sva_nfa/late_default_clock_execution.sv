// IEEE 1800-2017/2023 14.12 and 16.14.6: a module default clocking
// applies to assertions before its declaration. Check actual actions,
// a forward named property, generate scope, and procedural inference.
module late_default_clock_execution;
  logic clk = 0;
  logic a = 1, b = 0, probe = 0;
  int direct_pass = 0, direct_fail = 0;
  int named_pass = 0, named_fail = 0;
  int generated_pass = 0, generated_fail = 0;
  int local_pass = 0, local_fail = 0;
  int implication_fail = 0;
  int procedural_pass = 0, procedural_fail = 0;

  always #5 clk = ~clk;

  direct_a: assert property (b) direct_pass++; else direct_fail++;
  named_a: assert property (named_b) named_pass++; else named_fail++;
  generate
    if (1) begin : inner
      property local_b;
        b;
      endproperty
      generated_a: assert property (b)
        generated_pass++; else generated_fail++;
      local_a: assert property (local_b)
        local_pass++; else local_fail++;
    end
    if (0) begin : inactive
      // If module-end replay loses the generate scope this fails at runtime.
      inactive_a: assert property (1'b0) else $fatal(1, "inactive fired");
    end
  endgenerate
  implication_a: assert property (a |=> b) else implication_fail++;
  // As in first_match.sv, read the synthesized cover count: this tree
  // lowering does not execute a user-supplied cover pass action.
  window_c: cover property (first_match(a ##[1:2] b));

  // This assertion has its own enclosing event control. It must sample at
  // negedge, where probe is 1, despite the module default at posedge.
  always @(negedge clk)
    procedural_a: assert property (probe)
      procedural_pass++; else procedural_fail++;

  property named_b;
    b;
  endproperty
  default clocking cb @(posedge clk); endclocking

  always @(posedge clk) #1 probe = 1;
  always @(negedge clk) #1 probe = 0;

  initial begin
    // At posedges 5,15,25,35: b=0,1,0,1. The implication started
    // at 5 passes at 15; its separate attempt at 15 fails at 25.
    // The first_match cover accepts those starts at 15 and 35.
    @(negedge clk); #1 b = 1;
    @(negedge clk); #1 b = 0; a = 0;
    @(negedge clk); #1 b = 1;
    @(negedge clk); #2;
    if (direct_pass != 2 || direct_fail != 2 ||
        named_pass != 2 || named_fail != 2 ||
        generated_pass != 2 || generated_fail != 2 ||
        local_pass != 2 || local_fail != 2 ||
        implication_fail != 1 ||
        _ivl_sva7_cnt0 != 2 ||
        procedural_pass != 4 || procedural_fail != 0) begin
      $display("FAILED direct %0d/%0d named %0d/%0d generate %0d/%0d local %0d/%0d implication %0d window %0d procedural %0d/%0d",
               direct_pass, direct_fail, named_pass, named_fail,
               generated_pass, generated_fail, local_pass, local_fail,
               implication_fail, _ivl_sva7_cnt0,
               procedural_pass, procedural_fail);
      $fatal(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
