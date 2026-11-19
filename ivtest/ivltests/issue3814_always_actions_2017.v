module issue3814_always_instance #(parameter int LO = 0, HI = LO)
    (input bit clk, output int passes);
  a: assert property (@(posedge clk) s_always[LO:HI] 1'b1)
    passes++; else ;
endmodule

module issue3814_always_actions;
  localparam int LO = 1, HI = LO + 1;
  localparam logic [63:0] FAR = 64'h8000_0000_0000_0000;
  bit clk, end_clk, unbounded_clk, disable_pulse;
  logic [7:0] operand = 8'h80;
  logic unbounded_operand = 1;
  int overlap_passes, overlap_failures;
  int weak_passes, nonvacuous_passes, strong_failures, far_passes;
  int bare_passes, bare_failures, unbounded_passes, unbounded_failures;
  wire signed [31:0] zero_instance_passes, delayed_instance_passes;

  overlap: assert property (@(posedge clk) always[LO:HI] operand)
    overlap_passes++; else begin
      if ($time != 25) $fatal(1, "unexpected overlap failure at %0t", $time);
      overlap_failures++;
    end

  weak_end: assert property (@(posedge end_clk) always[2:3] 1'b1)
    weak_passes++;
  weak_nonvacuous: assert property (@(posedge end_clk) always[2:3] 1'b1)
    nonvacuous_passes++;
  strong_end: assert property (@(posedge end_clk) s_always[2:3] 1'b1)
    $fatal(1, "incomplete strong window passed"); else strong_failures++;
  far_end: assert property (@(posedge end_clk) always[FAR:FAR] 1'b0)
    far_passes++; else $fatal(1, "far-away window entered");

  killed: assert property (@(posedge end_clk) always[1:$] 1'b1)
    $fatal(1, "killed window passed"); else $fatal(1, "killed window failed");
  disabled: assert property (@(posedge end_clk) disable iff (disable_pulse)
                            s_always[2:3] 1'b1)
    $fatal(1, "disabled window passed"); else $fatal(1, "disabled window failed");

  bare: assert property (@(posedge unbounded_clk) always unbounded_operand)
    bare_passes++; else bare_failures++;
  unbounded: assert property (@(posedge unbounded_clk)
                             always[1:$] unbounded_operand)
    unbounded_passes++; else unbounded_failures++;

  issue3814_always_instance immediate_i(end_clk, zero_instance_passes);
  issue3814_always_instance #(.LO(1), .HI(2))
      delayed_i(end_clk, delayed_instance_passes);

  task automatic tick;
    #5 clk = 1;
    #5 clk = 0;
  endtask

  task automatic tick_unbounded;
    #5 unbounded_clk = 1;
    #5 unbounded_clk = 0;
  endtask

  initial begin
    tick();
    tick();
    $assertoff(0, issue3814_always_actions.overlap);
    operand = 8'b0000000x;
    tick();
    if (overlap_failures != 2 || overlap_passes != 0)
      $fatal(1, "both attempts must fail on the same tick, got %0d failures",
             overlap_failures);

    operand = 8'h80;
    tick();
    if (overlap_passes != 0) $fatal(1, "failed attempt was still live");
    $asserton(0, issue3814_always_actions.overlap);
    tick();
    $assertoff(0, issue3814_always_actions.overlap);
    tick();
    if (overlap_passes != 0) $fatal(1, "passed at the lower bound");
    tick();
    if (overlap_passes != 1) $fatal(1, "did not pass at the upper bound");
    operand = '0;
    tick();

    $assertvacuousoff(0, issue3814_always_actions.weak_nonvacuous);
    repeat (3) begin
      #5 end_clk = 1;
      #5 end_clk = 0;
    end
    if (weak_passes != 0 || nonvacuous_passes != 0 || strong_failures != 0 ||
        far_passes != 0 || zero_instance_passes !== 3 || delayed_instance_passes !== 1)
      $fatal(1, "wrong pre-finish bounded verdicts");
    $assertoff(0, issue3814_always_actions.weak_end,
                  issue3814_always_actions.strong_end);
    $assertkill(0, issue3814_always_actions.killed);
    $asserton(0, issue3814_always_actions.killed);
    #1 disable_pulse = 1;
    #1 disable_pulse = 0;

    repeat (2) tick_unbounded();
    unbounded_operand = 0;
    tick_unbounded();
    if (bare_failures != 3 || unbounded_failures != 2)
      $fatal(1, "unbounded attempts did not fail together");
    unbounded_operand = 1;
    repeat (2) tick_unbounded();
    if (bare_passes != 0 || unbounded_passes != 0 ||
        bare_failures != 3 || unbounded_failures != 2)
      $fatal(1, "wrong pre-finish unbounded verdicts: fail %0d/%0d, pass %0d/%0d",
             bare_failures, unbounded_failures, bare_passes, unbounded_passes);
    if (weak_passes != 0 || nonvacuous_passes != 0 ||
        strong_failures != 0 || far_passes != 0)
      $fatal(1, "pending window resolved before finish");
    $finish(0);
  end

  final begin
    if (overlap_passes != 1 || overlap_failures != 2 ||
        weak_passes != 3 || nonvacuous_passes != 1 || strong_failures != 3 ||
        far_passes != 3 || bare_passes != 2 || unbounded_passes != 3 ||
        bare_failures != 3 || unbounded_failures != 2)
      $fatal(1, "wrong finish verdicts: overlap %0d/%0d, weak %0d/%0d, strong %0d, far %0d, unbounded %0d/%0d",
             overlap_passes, overlap_failures, weak_passes, nonvacuous_passes,
             strong_failures, far_passes, bare_passes, unbounded_passes);
    $display("PASS");
  end
endmodule
