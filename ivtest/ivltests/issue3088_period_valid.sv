module top;
  reg clk = 0;
  reg enable = 1;
  specify
    $period(posedge clk, 1);
    $period(negedge clk &&& enable, 1);
    $period(edge [01, 10] clk, 1);
  endspecify
  initial begin
    #2 clk = 1;
    #2 clk = 0;
    #2 $display("PASS");
  end
endmodule
