// The slice itself is legal, but object-backed element value-copy lowering
// is not established by the integral-only queue conversion path.
module test;
  string words[3:0];
  string q[$];
  initial begin
    q = words[2:1];
  end
endmodule
