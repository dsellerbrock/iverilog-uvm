module test;
  int hits = 0;

  initial begin
    cover (1'b1) hits++;
    cover (1'b0) hits += 100;

    if (hits != 1)
      $fatal(1, "cover action hits=%0d", hits);
    $display("PASSED");
  end
endmodule
