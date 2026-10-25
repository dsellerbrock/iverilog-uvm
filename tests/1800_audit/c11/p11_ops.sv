module p11_ops;
  logic [3:0] a = 4'b10xz, b = 4'b1100;
  logic [7:0] u = 8'b1001_0110, r;
  logic signed [7:0] s = 8'sb1001_0110;
  logic c;
  integer i;
  initial begin
    $display("BW %b %b %b %b %b", a & b, a | b, a ^ b, ~a, a ~^ b);
    $display("RD %b %b %b %b %b %b %b %b %b %b", &4'b1111, &4'b1x11, &4'b10x1, |4'b0x00, |4'b0x10,
             ^4'b1101, ^4'b1x00, ~&4'b1111, ~|4'b0000, ~^4'b1101);
    $display("SH %b %b %b %b %b", u >> 2, u << 3, s >>> 2, s >> 2, u >>> 2);
    r = 8'hFF << 1'bx; $display("SX %b", r);
    c = 1'bx; $display("CQ %b %b", c ? 4'b1010 : 4'b1001, 1'bz ? 4'b0000 : 4'b0000);
    $display("PR %0d %0d %0d %b %0d %0d", 1 + 2 << 1, 2 ** 3 ** 2, -2 ** 2, 4'b1100 ^ 4'b1010 & 4'b0110,
             1 & 2 == 2, 0 ? 1 : 0 ? 2 : 3);
    i = -12 / 3;     $display("IL %0d", i);
    i = -'d12 / 3;   $display("IL %0d", i);
    i = -'sd12 / 3;  $display("IL %0d", i);
    i = -4'sd12 / 3; $display("IL %0d", i);
  end
endmodule
