module outer;
 module inner;
  initial $display("INNER");
 endmodule
endmodule
module top; outer o(); endmodule
