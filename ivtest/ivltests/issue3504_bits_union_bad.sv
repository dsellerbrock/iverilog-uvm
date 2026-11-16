// IEEE 1800 20.6.2 / 6.24.3: $bits needs a bit-stream type; an unpacked
// union (or a struct or array that holds one) is not one.
module top;
  typedef union { int a; bit [7:0] b; } uu_t;
  typedef union tagged { int A; bit B; } tu_t;
  typedef struct { int x; uu_t u; } st_t;
  uu_t u; tu_t t; st_t s; uu_t ua[2];
  initial begin
    $display("%0d", $bits(u));
    $display("%0d", $bits(uu_t));
    $display("%0d", $bits(t));
    $display("%0d", $bits(s));
    $display("%0d", $bits(ua));
  end
endmodule
