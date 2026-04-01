module test;
  function automatic int leaf(int x);
    int sum;
    sum = 0;
    for (int i = 0; i < 4; i++) begin
      if (i == x) continue;
      sum += i;
    end
    return sum;
  endfunction

  function automatic int mid(int x);
    return leaf(x);
  endfunction

  initial begin
    if (mid(2) !== 4) begin
      $display("FAIL mid(2)=%0d", mid(2));
      $finish(1);
    end
    if (mid(4) !== 6) begin
      $display("FAIL mid(4)=%0d", mid(4));
      $finish(1);
    end
    $display("PASS");
  end
endmodule
