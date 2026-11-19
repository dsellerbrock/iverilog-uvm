module issue3814_always_zero;
  bit clk;
  logic [7:0] operand = 8'h80;
  int edges, passes, failures;

  always @(posedge clk) begin
    edges++;
    case (edges)
      1: operand <= 8'b0000000x;
      2: operand <= 8'b0000000z;
      3: operand <= '0;
      4: operand <= 8'h80;
    endcase
  end

  a: assert property (@(posedge clk) s_always[0:0] operand) begin
    if (edges != 1 || operand !== 8'b0000000x)
      $fatal(1, "expected the sampled wide value and a Reactive pass action");
    passes++;
  end else failures++;

  task automatic tick;
    #5 clk = 1;
    #5 clk = 0;
  endtask

  initial begin
    tick();
    if (passes != 1 || failures != 0) $fatal(1, "wrong age-zero verdict");
    repeat (3) tick();
    if (passes != 1 || failures != 3) $fatal(1, "X, Z and 0 must fail");
    $assertpassoff(0, issue3814_always_zero.a);
    tick();
    $finish(0);
  end

  final begin
    if (passes != 1 || failures != 3) $fatal(1, "extra verdict");
    $display("PASS");
  end
endmodule
