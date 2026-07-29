// IEEE 1800-2017 18.4: rand/randc is restricted to integral types.
// `string` is not integral. Campaign 6 wave 2.
class C;
  randc string s;
endclass
module rand_string_illegal;
  initial begin
    C c = new();
    c.s = "hello";
  end
endmodule
