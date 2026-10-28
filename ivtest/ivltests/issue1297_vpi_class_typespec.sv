module top;
  class Packet; int x; endclass
  Packet p;
  initial begin p = new; p.x = 7; end
endmodule
