`timescale 1ns/1ns
module issue3551_delayed_actual;
  bit clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  sequence s(q);
    q ##1 b;
  endsequence

  int passes[2];
  task automatic matched(int which);
    if (passes[which] >= 3 || $time != 25 + 10 * passes[which])
      $fatal(1, "assertion %0d matched at unexpected time %0t", which, $time);
    passes[which]++;
  endtask

  positional: assert property (@(posedge clk) s(a ##1 b))
    matched(0); else $fatal(1, "positional assertion failed at %0t", $time);
  named_actual: assert property (@(posedge clk) s(.q(a ##1 b)))
    matched(1); else $fatal(1, "named assertion failed at %0t", $time);

  initial begin
    #50;
    if (passes[0] != 3 || passes[1] != 3)
      $fatal(1, "expected three matches per assertion, saw %0d and %0d",
             passes[0], passes[1]);
    $display("PASSED");
    $finish(0);
  end
endmodule
