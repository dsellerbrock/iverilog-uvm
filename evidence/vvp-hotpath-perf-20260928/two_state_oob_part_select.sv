// DD-065 reducer: out-of-range bits of a part select of a two-state vector,
// assigned to a two-state variable, are left x in that variable.
module test;
  bit [99:0] bv;
  bit [7:0] br;
  int b;
  initial begin
    bv = '1;
    b = 96;
    br = bv[b +: 8];
    $display("br=%b (a two-state variable cannot hold x)", br);
  end
endmodule
