// Known-width wide coverpoints must fail compilation for unsupported bin
// forms, rather than silently dropping coverage or matching low 64 bits.
class wide_bad_cov;
  covergroup cg with function sample(logic [127:0] x, bit y);
    cp: coverpoint x {
      bins one = {128'h1};
      ignore_bins ignored = {128'h2};
      illegal_bins illegal = {128'h3};
      wildcard bins wild = {128'h1_0000_0000_0000_0000};
      bins trans = (128'h1 => 128'h2);
      bins interval = {[128'h2:128'h3]};
      bins sized[2] = {128'h4, 128'h5};
      bins fill_math = {'1 - 1};
    }
    s: coverpoint y { bins zero = {0}; bins one = {1}; }
    cr: cross cp, s {
      bins intersection = binsof(cp.one) intersect {128'h1};
    }
  endgroup
endclass
module top; endmodule
