checker issue1545_checker_implicit_untyped(a);
endchecker

module issue1545_checker_implicit_untyped_top;
  logic a;
  issue1545_checker_implicit_untyped ci(a);
  initial begin
    a = 1'b1;
    $display("PASS");
  end
endmodule
