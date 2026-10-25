// IEEE 1800-2017/2023 6.8, Table 6-7: unpacked-struct members retain
// their declared type's default initial value.
module issue1156_unpacked_struct_default_2state;
  typedef struct { logic [7:0] a; bit [3:0] b; int c; } r_t;
  r_t z;

  initial begin
    $display("%b %b %0d", z.a, z.b, z.c);
    if (z.a !== 8'hxx || z.b !== 4'b0000 || z.c !== 0)
      $fatal(1, "incorrect unpacked struct default values");
    z.a[3] = 1'b1;
    $display("%b %b %0d", z.a, z.b, z.c);
    if (z.a !== 8'bxxxx1xxx || z.b !== 4'b0000 || z.c !== 0)
      $fatal(1, "member write changed unpacked struct defaults");
    $display("PASSED unpacked struct default values");
  end
endmodule
