// M9-NFA dual-run seed: cover property counting through the automaton
// engine. Both engines name the match counter identically
// (_ivl_sva<inst>_cnt0, inst in source order), so displaying it puts
// the COUNT into the verdict stream — parity proves count equality,
// not just silence. The second cover carries a pass statement to pin
// the shared loud-drop warning (neither engine executes cover pass
// statements; the drop must never be silent).
module cover_counts;
  logic clk = 0, a = 0, b = 0, w = 0, v = 0;
  always #5 clk = ~clk;

  c1: cover property (@(posedge clk) a ##1 b);            // inst 0
  c2: cover property (@(posedge clk) w |-> ##[1:2] v)     // inst 1
        $display("never printed: cover pass statements are dropped loudly");

  initial begin
    @(negedge clk) a = 1; b = 1;      // sampled 1 at 15/25/35
    repeat (3) @(negedge clk);
    a = 0; b = 0;                     // attempts @15,@25 match; @35 misses
    @(negedge clk) w = 1;             // w@55: v@65 or v@75
    @(negedge clk) w = 0; v = 1;      // v@65: one covered attempt
    @(negedge clk) v = 0;
    @(negedge clk);
    $display("c1 count=%0d c2 count=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
