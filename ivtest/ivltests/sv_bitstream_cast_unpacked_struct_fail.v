// A vector cast to an unpacked struct is a legal bit-stream cast
// (IEEE 1800-2017/2023 6.24.3), but full bit-stream casting (arbitrary
// queues/dynamic arrays/nested aggregates on either side) is not yet
// implemented. This used to warn and then CRASH the compiler
// (ivl_expr_value asserted on a null child expression, because the
// fallback handed codegen a vector-shaped expression where a
// struct-shaped one was required). Now it is a clean, loud rejection
// instead (L37). A packed-struct cast target is unaffected -- see
// sv_bitstream_cast_packed_struct.v.

module test;
  typedef struct {
    logic [3:0] a;
    logic [3:0] b;
  } s_t;
  s_t s;
  logic [7:0] v;
  initial begin
    v = 8'hAB;
    s = s_t'(v);
    $display("FAILED");
  end
endmodule
