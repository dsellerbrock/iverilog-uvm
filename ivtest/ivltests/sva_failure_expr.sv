`timescale 1ps/1ps

module sva_failure_expr;
  localparam time BASE = 64'h1_0000_0000;
  bit clk = 0, a = 0, b = 0, c = 0, e = 0;
  bit arm = 0, gate = 0, disabled = 0;
  logic d = 0;
  initial begin
    #BASE;
    forever #5 clk = ~clk;
  end

  fixed_seq: assert property (@(posedge clk)
                             a ##1 b ##1 c ##0 d ##0 e) else ;
  ranged_seq: assert property (@(posedge clk)
                              a ##1 b[*1:2] ##1 c) else begin
    // The callback still names the verdict tick after this timed action.
    if ($time == BASE + 35) #1;
  end

  property local_implication;
    bit saved;
    @(posedge clk) (arm, saved = gate) |=> b[*1:2] ##1 saved;
  endproperty
  local_seq: assert property (local_implication) else ;
  disabled_seq: assert property (@(posedge clk) disable iff (disabled)
                                 a ##1 b[*1:2] ##1 c) else ;
  killed_seq: assert property (@(posedge clk) a ##1 b[*1:2] ##1 c) else ;
  deep_seq: assert property (@(posedge clk) arm |-> ##256 e) else ;

  int cycle = 0, proc_order = 0;
  always @(posedge clk) cycle <= cycle + 1;
  always @(posedge clk) begin
    for (int n = 0; n < 2; ++n) begin
      automatic int id = cycle == 2 ? 2 : n;
      if (cycle == 0 || (cycle == 2 && n == 0))
        proc_seq: assert property ((id != 0) ##1 b[*1:2] ##1 c)
          else proc_order = 10 * proc_order + id;
    end
  end

  initial begin
    #(BASE + 1) a = 1; arm = 1;
    #5 $watch_failures;  // The first attempts are already live.
    $assertoff(0, sva_failure_expr.disabled_seq);
    $assertoff(0, sva_failure_expr.killed_seq);
    #3 a = 0; arm = 0; b = 1; gate = 1;
    // At tick 25 the shorter match has failed, but a longer match can
    // still succeed. Abort the two other live copies before tick 35.
    #17 disabled = 1;
    $assertkill(0, sva_failure_expr.killed_seq);
    #3 b = 0;
    #10 a = 1;
    #10 b = 1;
    #10 b = 0; c = 1; d = 1'bx;
    #10;
    if (proc_order != 12) $fatal(1, "Wrong queued action order: %0d", proc_order);
    $assertkill(0, sva_failure_expr.fixed_seq, sva_failure_expr.ranged_seq);
    #2500 $print_failures;
    $finish(0);
  end
endmodule
