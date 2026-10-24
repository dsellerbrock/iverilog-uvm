// IEEE 1800-2017 §18.15 / IEEE 1800-2023 §18.15
// Calling srandom() without its required seed argument must fail.
class Packet;
  rand bit [15:0] header;
endclass

module test;
  Packet p;
  initial begin
    p = new;
    p.srandom();
  end
endmodule
