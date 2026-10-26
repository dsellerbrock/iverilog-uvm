module main;
  class c; endclass
  class holder; c object; endclass
  holder h;
  logic q;
  initial q = h.object;
endmodule
