module issue1530_fixed_array_concat;
  int source[3];
  int target[6];

  initial begin
    source = {1, 2, 3};
    target = {source, 4, 5, 6};
    if (target[0] != 1 || target[1] != 2 || target[2] != 3
        || target[3] != 4 || target[4] != 5 || target[5] != 6)
      $fatal(1, "fixed target did not flatten array item: %p", target);

    $display("PASS fixed target array concatenation");
    $finish(0);
  end
endmodule
