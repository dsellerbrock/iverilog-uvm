module drv(output wire logic o);
  assign o = 1'b1;
endmodule
module rcv(input wire logic i);
  initial begin
    #1 $display("%b", i);
  end
endmodule
module top;
  interconnect n;
  drv d(n);
  rcv r(n);
endmodule
