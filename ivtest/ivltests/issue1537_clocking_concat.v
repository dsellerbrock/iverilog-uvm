module issue1537_clocking_concat;
  logic clk, a, b;
  wire [1:0] q;

  clocking cb @(posedge clk);
    input pair = {a,b};
    output opair = {q[1:0]};
  endclocking

  initial begin
    clk = 0;
    a = 1;
    b = 0;
    #1 cb.opair <= 2'b10;
    #4 clk = 1;
    #1;
    if (cb.pair !== 2'b10 || q !== 2'b10)
      $fatal(1, "clocking concatenation failed: pair=%b q=%b", cb.pair, q);
    $display("issue1537 clocking concatenation passed");
    $finish;
  end
endmodule
