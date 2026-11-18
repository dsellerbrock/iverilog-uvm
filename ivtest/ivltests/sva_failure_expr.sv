module sva_failure_expr;
  bit clk = 0, a = 0, b = 0, c = 0;
  logic d = 0;
  always #5 clk = ~clk;

  fixed_seq: assert property (@(posedge clk)
                             a ##1 b ##1 c ##0 d) else ;
  ranged_seq: assert property (@(posedge clk)
                              a ##1 b[*1:2] ##1 c) else ;

  initial begin
    #1 $watch_failures;
    a = 1;
    #8 a = 0; b = 1;
    #10 a = 1;
    #10 b = 0;
    #10 a = 0; b = 1;
    #10 c = 1; d = 1'bx;
    #10 $print_failures;
    $finish(0);
  end
endmodule
