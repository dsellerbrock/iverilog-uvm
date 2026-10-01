// A size cast needs an integral operand (IEEE 1800-2017/2023 6.24.1).
// Commercial tools also size-cast a string-typed value as its packed bytes
// (OpenTitan prim_lfsr: `64'(LfsrType)' with a `localparam string' override),
// so Icarus does too, only under -gcommercial-unsafe;
// sv_string_size_cast_fail keeps strict mode.
module sub #(parameter LfsrType = "GAL_XOR") (output int sel);
  if (64'(LfsrType) == 64'("GAL_XOR")) begin : g1 assign sel = 1; end
  else if (64'(LfsrType) == "FIB_XNOR") begin : g2 assign sel = 2; end
  else begin : g3 assign sel = 3; end
endmodule
module test;
  localparam string Fib = "FIB_XNOR";
  string s = "AB";
  int a, b;
  sub u1 (a);
  sub #(.LfsrType(Fib)) u2 (b);
  initial #1 begin
    if (a == 1 && b == 2 && 16'(s) == 16'h4142 && 8'(s) == 8'h42)
      $display("PASSED");
    else $display("FAILED %0d %0d %h", a, b, 16'(s));
  end
endmodule
