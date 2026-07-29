// IEEE 1800-2017 18.4: rand/randc is restricted to integral types.
// `chandle` is not integral (it is storage-compatible with a 64-bit atom,
// but is a distinct declared type). Campaign 6 wave 2.
class C;
  rand chandle h;
endclass
module rand_chandle_illegal;
  initial begin
    C c = new();
  end
endmodule
