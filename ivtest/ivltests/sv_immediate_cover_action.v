module test;
  integer hits = 0;

  // A direct null action used to create an initial process with a null
  // statement pointer and crash during elaboration.
  initial cover (1);

  initial begin
    cover (1) hits += 1;
    cover (0) hits += 100;

    if (hits == 1)
      $display("PASSED");
    else
      $display("FAILED hits=%0d", hits);
  end
endmodule
