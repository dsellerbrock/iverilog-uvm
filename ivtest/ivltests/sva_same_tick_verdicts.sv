// IEEE 1800-2023 16.14.1: "When the property for the assert statement is
// evaluated to be true, the pass statements of the action_block are
// executed. When the property ... is evaluated to be false, the fail
// statements ... are executed." Each evaluation attempt is evaluated on its
// own, so attempts decided at the same clock run their action once each.
// Edges are at 5, 15, ..., 45: a and c are 1 at 5 and 15, b only at 25.
module sva_same_tick_verdicts;
  bit clk = 0;
  always #5 clk = ~clk;
  bit a, b, c;
  string passes = "", failures = "", upasses = "";

  // The attempts from 5 (via ##2) and 15 (via ##1) both pass at 25.
  a1: assert property (@(posedge clk) a ##[1:2] b)
        passes = {passes, $sformatf(" %0t", $time)}; else ;
  // The same with an unbounded window.
  a3: assert property (@(posedge clk) a ##[1:$] b)
        upasses = {upasses, $sformatf(" %0t", $time)}; else ;
  // The attempts from 5, 15 and 25 all fail at 25.
  a2: assert property (@(posedge clk) c[*1:2] ##1 1'b0)
        else failures = {failures, $sformatf(" %0t", $time)};

  initial begin
    a = 1; b = 0; c = 1;
    #20 a = 0; b = 1; c = 0;
    #10 b = 0;
    #20;
    $display("a1 passes:%s", passes);
    $display("a2 failures:%s", failures);
    $display("a3 passes:%s", upasses);
    $finish;
  end
endmodule
