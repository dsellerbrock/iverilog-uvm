// NFA-EXPECT-FALLBACK: the focused symbolic checker is shared by both modes.
// IEEE 1800-2017/2023 16.8, 16.9.2.1 and 16.12.7: a named sequence is
// flattened before checking its per-instance consequent bound.
module named_consequent_checker #(parameter int W = 2)(
    input logic clk, rst_n, start, ready, literal_start);
  integer passes = 0, failures = 0;
  integer plain_passes = 0, plain_failures = 0;
  integer direct_passes = 0, direct_failures = 0;
  integer function_passes = 0, function_failures = 0;
  integer literal_failures = 0;
  integer expected_passes = 0, expected_failures = 0;
  logic [W:0] live = '0;

  sequence begin_attempt(s);
    s;
  endsequence
  sequence begin_attempt_plain;
    start;
  endsequence
  function automatic logic boolean_function(input logic s);
    boolean_function = s;
  endfunction

  checked: assert property (@(posedge clk) disable iff (!rst_n)
      begin_attempt(start) |=> !ready[*W] ##1 ready)
    passes++;
  else failures++;
  plain: assert property (@(posedge clk) disable iff (!rst_n)
      begin_attempt_plain |=> !ready[*W] ##1 ready)
    plain_passes++;
  else plain_failures++;
  direct: assert property (@(posedge clk) disable iff (!rst_n)
      start |=> !ready[*W] ##1 ready)
    direct_passes++;
  else direct_failures++;
  function_control: assert property (@(posedge clk) disable iff (!rst_n)
      boolean_function(start) |=> !ready[*W] ##1 ready)
    function_passes++;
  else function_failures++;

  // One isolated literal attempt checks the non-symbolic W=2/3 boundaries
  // without relying on literal/automaton same-tick overlap behavior.
  // Literal [*0] is an existing NFA-only shape, covered separately by
  // parameter_consequent_repeat_timing_nfa_only.sv.
  generate
    if (W == 2) begin : two
      literal: assert property (@(posedge clk) disable iff (!rst_n)
          literal_start |=> !ready[*2] ##1 ready)
        ; else literal_failures++;
    end else if (W == 3) begin : three
      literal: assert property (@(posedge clk) disable iff (!rst_n)
          literal_start |=> !ready[*3] ##1 ready)
        ; else literal_failures++;
    end
  endgenerate

  // Independent per-attempt reference model. At a clock, bit W awaits ready;
  // lower bits await !ready. A new start occupies bit 0 after those checks.
  always @(negedge rst_n) live = '0;
  always @(posedge clk) begin
    logic sampled_start, sampled_ready;
    sampled_start = start;
    sampled_ready = ready;
    // The assertion samples operands before NBA but evaluates disable iff
    // afterward. Delay the reference verdict so an NBA reset wins this tick.
    #1;
    if (rst_n) begin
      for (int i = 0; i <= W; i++) if (live[i]) begin
        if (i == W) begin
          if (sampled_ready === 1'b1) expected_passes++;
          else expected_failures++;
        end else if (sampled_ready !== 1'b0) expected_failures++;
      end
      live = sampled_ready === 1'b0 ? live << 1 : '0;
      if (sampled_start === 1'b1) live[0] = 1'b1;
      else expected_passes++;  // Vacuous implication.
    end else live = '0;
  end

  always @(negedge clk) begin
    #1;
    if (passes != expected_passes || failures != expected_failures ||
        plain_passes != expected_passes ||
        plain_failures != expected_failures ||
        direct_passes != expected_passes || direct_failures != expected_failures ||
        function_passes != expected_passes ||
        function_failures != expected_failures) begin
      $display("FAILED W=%0d: named %0d/%0d plain %0d/%0d direct %0d/%0d function %0d/%0d model %0d/%0d at %0t",
          W, passes, failures, plain_passes, plain_failures,
          direct_passes, direct_failures,
          function_passes, function_failures,
          expected_passes, expected_failures, $time);
      $finish_and_return(1);
    end
  end
endmodule

module named_antecedent_parameter_consequent_repeat;
  logic clk = 0, rst_n = 1, start = 0, ready = 0, literal_start = 0;
  always #5 clk = ~clk;
  named_consequent_checker #(.W(0)) zero (.*);
  named_consequent_checker #(.W(2)) two (.*);
  named_consequent_checker #(.W(3)) three (.*);

  task automatic drive(input logic s, r);
    @(negedge clk);
    start = s;
    ready = r;
    literal_start = 0;
  endtask

  initial begin
    drive(1, 0);  // New attempts in all three instances.
    literal_start = 1;
    drive(1, 1);  // W=0 completes; W=2/3 fail early; overlap a new start.
    drive(1, 0);
    drive(1, 0);
    drive(0, 0);
    drive(0, 1);  // W=2 and W=3 have different final-due ages.
    drive(1, 0);
    drive(1, 0);
    drive(0, 1);  // Multiple live attempts can fail on the same tick.
    drive(0, 1);
    drive(1, 0);
    drive(0, 0);
    // Off-clock reset pulse must clear live obligations, even if the level
    // is deasserted before the next posedge.
    #2 rst_n = 0;
    #1 rst_n = 1;
    drive(0, 1);
    drive(1, 0);
    drive(0, 0);
    drive(0, 0);
    drive(0, 1);
    drive(0, 0);
    drive(1, 0);
    drive(0, 1'bx); // Unknown ready fails a due finish or !ready match.
    drive(1, 0);
    drive(0, 1'bz); // High impedance does the same.
    drive(1, 0);
    drive(0, 0);
    // This reset is scheduled in NBA on the first pending keep/finish tick.
    // The observed disable level must cancel it before any verdict.
    @(posedge clk) rst_n <= 0;
    @(negedge clk) begin
      rst_n = 1;
      start = 0;
      ready = 1;
    end
    drive(0, 1);
    drive(0, 0);
    @(negedge clk);
    #2;
    if (two.literal_failures != 1 || three.literal_failures != 1) begin
      $display("FAILED: literal controls %0d/%0d",
          two.literal_failures, three.literal_failures);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
