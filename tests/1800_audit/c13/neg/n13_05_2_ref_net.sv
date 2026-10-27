module top;
  wire w;
  task automatic t(ref logic x); endtask
  initial t(w);
endmodule
