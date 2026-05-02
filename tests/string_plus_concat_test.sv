// Phase 63b: SystemVerilog `string + string` concatenation operator.
//
// Pre-fix: `s = a + b` where a, b are strings emitted bytecode that
// cast both strings to vec4, %add'd them as packed vectors, then
// cast back to string.  When the strings differed in length, the
// vec4 sizes differed and the runtime hit
//   vvp_vector4_t::add: Assertion `size_ == that.size_' failed
//
// Real impl: in PEBinary::elaborate_expr, if op is '+' and both
// operands are string-typed, build a NetEConcat with IVL_VT_STRING
// element type so codegen routes through string_ex_concat (which
// emits %concat/str opcodes).
`timescale 1ns/1ps

module top;
  initial begin
    string a, b, c, d;
    a = "hello";
    b = " world";
    c = a + b;
    if (c != "hello world")
      $fatal(1, "FAIL/T1: c='%s' expected 'hello world'", c);

    // Multi-way concat (chained +)
    d = "left:" + a + "/" + b + ":right";
    if (d != "left:hello/ world:right")
      $fatal(1, "FAIL/T2: d='%s'", d);

    // Mixed: empty + non-empty
    a = "";
    b = "alone";
    c = a + b;
    if (c != "alone")
      $fatal(1, "FAIL/T3: c='%s'", c);

    $display("PASS: string + string concatenation");
    $finish;
  end
endmodule
