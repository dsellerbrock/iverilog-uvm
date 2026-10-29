module first_match_suffix_cut;
  logic clk=0, a=0, b=0, c=0, d=0, z=0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) first_match(a ##[1:3] b ##1 c) ##1 d);
  cover property (@(posedge clk) first_match(a ##[1:3] b ##1 c) ##0 z);

  task idle; repeat (3) @(negedge clk); endtask

  initial begin
    // The first b has no following c; a later b completes the operand.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;
    @(negedge clk) b=0;
    @(negedge clk) b=1;
    @(negedge clk) b=0; c=1;
    @(negedge clk) c=0; d=1;
    @(negedge clk) d=0;
    idle;

    // A failed ##0 continuation is still too late to change the wrapper's
    // endpoint; the later c/z pair must not rescue this cover attempt.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;
    @(negedge clk) b=0; c=1;
    @(negedge clk) c=0; b=1;
    @(negedge clk) b=0; c=1; z=1;
    @(negedge clk) c=0; z=0;
    idle;

    // Both b paths complete, but first_match selects the earlier whole
    // operand endpoint (c@2), so only its d@3 continuation counts.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;
    @(negedge clk) b=0; c=1;
    @(negedge clk) c=0; b=1; d=1;
    @(negedge clk) b=0; c=1; d=0;
    @(negedge clk) c=0; d=1;
    @(negedge clk) d=0;
    idle;

    $display("first_match_suffix_cut_count=%0d", _ivl_sva0_cnt0);
    $display("first_match_zero_suffix_cut_count=%0d", _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
