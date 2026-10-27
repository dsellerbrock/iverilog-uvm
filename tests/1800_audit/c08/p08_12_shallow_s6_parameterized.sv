module top;
  class P #(parameter N = 4);
    bit [N-1:0] bits;
  endclass
  P #(4) p1, p2;
  initial begin
    p1 = new; p1.bits = 4'b1010; p2 = new p1;
    if (p2.bits != 4'b1010 || $bits(p2.bits) != 4) $fatal(1, "S6 specialization copy failed");
    p2.bits = 4'b0101;
    if (p1.bits != 4'b1010) $fatal(1, "S6 specialization copy aliases source");
    $display("PASS S6 width=%0d source=%b copy=%b", $bits(p2.bits), p1.bits, p2.bits);
  end
endmodule
