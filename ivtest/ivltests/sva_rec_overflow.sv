// One long-lived recursive attempt must report pool exhaustion as an error.
module sva_rec_overflow;
  reg clk = 0, start = 1;
  always #5 clk = ~clk;
  property always_one;
    1'b1 and (1'b1 |=> always_one);
  endproperty
  assert property (@(posedge clk) start |-> always_one)
    else $display("UNEXPECTED FAILURE");
  initial begin
    #10 start = 0;
    #195 $display("END");
    $finish;
  end
endmodule
