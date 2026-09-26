// A real bitwise operand is not integral. PEBinary::test_width() has a
// nonzero real fallback, but that must not make this coverpoint bin legal.
module test;
  covergroup cg with function sample(real value, bit [3:0] mask);
    cp: coverpoint (value & ~mask) { bins zero = {0}; }
  endgroup
  cg c;
  initial begin
    c = new;
    $display("UNSUPPORTED_DIAGNOSTIC");
  end
endmodule
