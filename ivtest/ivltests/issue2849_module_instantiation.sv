module a; endmodule
module b(input i); endmodule
module top;
  wire i;
  a u;
  b v(.*, .*);
  initial $display("ok");
endmodule
