// Issue #1256: system task/function arguments are expressions that the
// simulator evaluates only when the application asks for their value.
// IEEE 1800-2023 37.42 detail 7: "If no application asks for the value of
// the argument, it is never evaluated." 36.10.3: an operation is a
// vpiOperation whose operands are reached through vpiOperand.
module top;
  int a = 2, b = 3, count = 0;
  function int bump(int x); count++; return x + 1; endfunction
  task automatic t(int k);
    int local_v = k * 10;
    // The argument reads an automatic local and calls a function.
    if ($value(local_v + bump(a)) != 53) $display("FAILED: automatic argument");
  endtask
  initial begin
    // The probe walks the operand tree: a + (b * 3) has five nodes.
    if ($expr(a + b*3) != 5) $display("FAILED: expression tree");
    $noeval(bump(a) + 1);
    if (count != 0) $display("FAILED: an unrequested argument ran, count=%0d", count);
    if ($twice(bump(b) * 2) != 16) $display("FAILED: twice value");
    if (count != 2) $display("FAILED: two requests ran %0d times", count);
    t(5);
    if (count != 3) $display("FAILED: automatic argument count=%0d", count);
    $display("SV DONE");
  end
endmodule
