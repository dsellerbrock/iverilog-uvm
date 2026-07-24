module top(output o, input i);
  buf b(o,i);
  specify pulsestyle_ondetect o; showcancelled o; (i => o) = 3; endspecify
endmodule
module tb; reg i=0; wire o; top t(o,i); initial begin #5 $display("PASS"); $finish(0); end endmodule
