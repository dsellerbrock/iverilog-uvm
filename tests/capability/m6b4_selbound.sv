// Boundary: a SELECT operand cannot be sampled (%load/preponed needs a
// whole signal), so it still reads live. Documents the known gap.
module top;
  bit clk = 0;
  logic [7:0] v = 0;
  int whole_f = 0, sel_f = 0;
  aw: assert property (@(posedge clk) v == 0)    else whole_f++;
  as: assert property (@(posedge clk) v[0] == 0) else sel_f++;
  initial begin
    #5 v = 8'hFF; clk = 1;
    #5 clk = 0;
    #5 $display("whole_f=%0d (0 = preponed) sel_f=%0d (1 = still live)", whole_f, sel_f);
    $finish(0);
  end
endmodule
