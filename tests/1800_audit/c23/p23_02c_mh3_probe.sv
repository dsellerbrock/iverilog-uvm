module mh3([5:0] x);
 initial $display("MH3 %0d", $bits(x));
endmodule
module top;
 mh3 m3(.x(6'h2a));
endmodule
