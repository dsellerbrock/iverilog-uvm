// IEEE 1800-2017 18.4: rand/randc is restricted to integral types (2-state/
// 4-state, enums, and aggregates thereof). real/shortreal is not integral.
// Campaign 6 wave 2 (rand CONTAINER/TYPE correctness cluster).
class C;
  rand real r;
endclass
module rand_real_illegal;
  initial begin
    C c = new();
    c.r = 1.0;
  end
endmodule
