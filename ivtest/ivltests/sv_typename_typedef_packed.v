module main;
  typedef bit node;
  node [2:0] X;

  initial begin
    if ($typename(X) != "bit [2:0]") begin
      $display("FAIL: $typename(X) = %s", $typename(X));
      $finish;
    end
    $display("PASS");
  end
endmodule
