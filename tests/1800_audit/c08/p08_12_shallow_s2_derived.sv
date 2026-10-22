module top;
  class B; int x; endclass
  class D extends B; int y; endclass
  D d1, d2;
  initial begin
    d1 = new; d1.x = 3; d1.y = 8; d2 = new d1;
    if (d2.x != 3 || d2.y != 8) $fatal(1, "S2 copy failed");
    d2.x = 4; d2.y = 9;
    if (d1.x != 3 || d1.y != 8) $fatal(1, "S2 copy aliases source");
    $display("PASS S2 derived source=%0d/%0d copy=%0d/%0d", d1.x, d1.y, d2.x, d2.y);
  end
endmodule
