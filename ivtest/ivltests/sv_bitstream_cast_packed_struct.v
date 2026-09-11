// A packed-struct cast target is a bit-compatible reinterpretation
// (correctly handled, no warning) -- unaffected by L37's unpacked-struct
// hard-error fix; kept as a positive-path sibling to
// sv_bitstream_cast_unpacked_struct_fail.v.

module test;
  typedef struct packed {
    logic [3:0] a;
    logic [3:0] b;
  } s_t;
  s_t s;
  logic [7:0] v;
  initial begin
    v = 8'hAB;
    s = s_t'(v);
    if (s.a == 4'hA && s.b == 4'hB)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
