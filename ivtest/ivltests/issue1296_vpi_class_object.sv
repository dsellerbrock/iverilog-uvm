module top;
  class Packet; int x; endclass
  class Child extends Packet; int y; endclass

  Packet p, q, null_p;
  Child c;

  initial begin
    c = new;
    p = c;
    p.x = 7;
    q = new;
    null_p = null;
    #2;
  end
endmodule
