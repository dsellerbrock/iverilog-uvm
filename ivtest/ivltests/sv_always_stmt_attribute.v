// IEEE 1800-2017 A.6.4: statement ::= {attribute_instance} statement_item,
// so attributes may sit between `always` and the body. Reduced from the
// OpenTitan AST models' always (* xprop_off *) @( * ) processes.
module main;
  logic a, q;
  always (* xprop_off *) @( * ) begin
    q = ~a;
  end
  initial begin
    a = 1'b0; #1;
    if (q !== 1'b1) begin $display("FAILED q=%b", q); $finish; end
    a = 1'b1; #1;
    if (q !== 1'b0) begin $display("FAILED q=%b", q); $finish; end
    $display("PASSED");
  end
endmodule
