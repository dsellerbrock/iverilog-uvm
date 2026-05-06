// p60 (Phase 68): assert property (...) pass_action else fail_action (3-arg form).
// With -gsupported-assertions, this form now synthesizes an always block
// using the fail action; pass action is dropped.
module top;
  logic clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  // 3-arg form: pass action ($display) + else fail action ($error).
  assert property (@(posedge clk) a |-> b) $display("PASS action"); else $error("FAIL action");

  // Plain 3-arg form without implication.
  assert property (@(posedge clk) a) $display("PASS plain"); else $error("FAIL plain");

  initial begin
    #50;
    $display("PASS: p60 3-arg assert property compiled and ran");
    $finish;
  end
endmodule
