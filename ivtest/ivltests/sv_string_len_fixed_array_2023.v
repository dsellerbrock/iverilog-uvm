module main;
  string arr[3] = '{"a", "bb", "ccc"};
  int index;

  initial begin
    if (arr[0].len() != 1 || arr[1].len() != 2 || arr[2].len() != 3)
      $fatal(1, "fixed array string len mismatch");

    for (index = 0; index < 3; index = index + 1) begin
      if (arr[index].len() != index + 1)
        $fatal(1, "variable indexed string len mismatch at %0d", index);
    end

    $display("PASS");
  end
endmodule
