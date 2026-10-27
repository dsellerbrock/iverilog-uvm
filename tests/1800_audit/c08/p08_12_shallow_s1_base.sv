module top;
  class B; int x; endclass
  B b1, b2;
  initial begin
    b1 = new; b1.x = 3; b2 = new b1;
    if (b2.x != 3) $fatal(1, "S1 copy failed");
    b2.x = 4;
    if (b1.x != 3) $fatal(1, "S1 copy aliases source");
    $display("PASS S1 base copy source=%0d copy=%0d", b1.x, b2.x);
  end
endmodule
