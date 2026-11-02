module issue905_default_argument_scope;
  int a = 100;

  function automatic int k(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  initial begin
    $display("%0d %0d %0d", k(), k(5), k(5, 7));
    $finish;
  end
endmodule
