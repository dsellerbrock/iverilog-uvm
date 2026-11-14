// IEEE 1800-2023 17.3: the static instance s registers its a1; the procedural
// instances p and w (.* connections) each register the a1 placed in top's
// always procedure, and their module-scope copies of ck register none.
checker ck(event clk, logic a);
  a1: assert property (@clk a);
endchecker

module top;
  logic clk = 0, a = 1;
  ck s(posedge clk, a);
  always @(posedge clk) begin
    ck p(posedge clk, a);
    ck w(.*);
  end
  initial begin
    #1 $list_assertions(3);
    $finish;
  end
endmodule
