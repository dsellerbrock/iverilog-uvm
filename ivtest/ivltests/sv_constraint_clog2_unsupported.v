// IEEE 1800-2017/2023 20.8.1 and 7.12: invalid or unrepresentable
// arguments/with clauses must remain diagnosed, never folded to a guess.
package p;
  parameter int N = 64;
  class k;
    localparam int N = 8;
  endclass
endpackage
class reduction_shadow #(parameter int item = 64);
  rand int q[2];
  constraint c { q.sum() with ($clog2(item)) == 2; }
endclass
class method_shadow;
  rand int v;
  function int N(); return 8; endfunction
endclass
module main;
  parameter int N = 64;
  int v, n;
  reduction_shadow r;
  method_shadow m;
  initial begin
    r = new;
    m = new;
    if (!m.randomize() with { v == $clog2(N); }) $finish;
    if (!std::randomize(v) with { v == $clog2(.a(8)); }) $finish;
    if (!std::randomize(v) with { v == $clog2(p::k::N); }) $finish;
    if (!std::randomize(v) with { v == $clog2(n); }) $finish;
    if (!std::randomize(v) with { v == $clog2(32'bx); }) $finish;
    if (!std::randomize(v) with { v == $clog2(real'(8)); }) $finish;
    if (!std::randomize(v) with { v == $clog2(string'(8)); }) $finish;
    if (!std::randomize(v) with { v == $clog2(8) with (0); }) $finish;
    begin : nonintegral_shadow
      localparam real N = 8.0;
      if (!std::randomize(v) with { v == $clog2(N); }) $finish;
    end
    begin : unknown_shadow
      localparam logic [31:0] N = 'x;
      if (!std::randomize(v) with { v == $clog2(N); }) $finish;
    end
    begin : variable_shadow
      int N;
      N = 8;
      if (!std::randomize(v) with { v == $clog2(N); }) $finish;
    end
  end
endmodule
