class X;
  rand bit [3:0] x;
  constraint p;
  constraint p { x == 1; }
endclass
module main; X obj = new; endmodule
