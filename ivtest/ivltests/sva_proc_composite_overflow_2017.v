module sva_proc_composite_overflow;
  bit root, clk1, clk2;

  property p;
    (@(posedge clk1) 1'b1 |-> 1'b1) and (@(posedge clk2) 1'b1 |-> 1'b1);
  endproperty

  initial begin
    repeat (65)
      check_p: assert property (@(posedge root) 1'b1 |=> p);
    #1; root = 1;
    #1; $display("continued after overflowing the attempt pool");
  end
endmodule
