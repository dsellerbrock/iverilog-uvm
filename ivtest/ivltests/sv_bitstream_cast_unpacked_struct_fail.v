// A packed value can be cast to an unpacked struct destination
// (IEEE 1800-2017 6.24.3).

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
    if (s.a !== 4'hA || s.b !== 4'hB)
      $fatal(1, "bit-stream cast produced %h %h", s.a, s.b);
    $display("PASSED");
  end
endmodule
