// NFA-EXPECT-FALLBACK: the focused symbolic checker is shared by both modes.
// IEEE 1800-2017/2023 16.9.2.1 and 16.12.7: each instance uses its own
// exact consequent bound, including the empty-repeat case W=0.
module consequent_checker #(parameter int W = 2)(
    input logic clk, rst_n, start, ready);
  integer passes = 0, failures = 0;
  integer expected_passes = 0, expected_failures = 0;
  logic [W:0] live = '0;

  checked: assert property (@(posedge clk) disable iff (!rst_n)
      start |=> !ready[*W] ##1 ready)
    passes++;
  else failures++;

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
    if (passes != expected_passes || failures != expected_failures) begin
      $display("FAILED W=%0d: symbolic %0d/%0d model %0d/%0d at %0t",
          W, passes, failures, expected_passes, expected_failures, $time);
      $finish_and_return(1);
    end
  end
endmodule

module parameter_consequent_repeat;
  logic clk = 0, rst_n = 1, start = 0, ready = 0;
  always #5 clk = ~clk;
  consequent_checker #(.W(0)) zero (.*);
  consequent_checker #(.W(2)) two (.*);
  consequent_checker #(.W(3)) three (.*);

  task automatic drive(input logic s, r);
    @(negedge clk);
    start = s;
    ready = r;
  endtask

  initial begin
    drive(1, 0);  // New attempts in all three instances.
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
    $display("PASSED");
    $finish;
  end
endmodule
