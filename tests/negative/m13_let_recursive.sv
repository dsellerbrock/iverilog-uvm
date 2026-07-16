// M13 negative: a self-recursive let must be diagnosed, not loop
// or crash the compiler.
module top;
  let r(x) = r(x) + 1;
  initial $display("%0d", r(1));
endmodule
