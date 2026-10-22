module test;
  int source[4] = '{10, 20, 30, 40};
  int destination[2];

  initial begin
    destination = source[1:2];
    if (destination[0] != 20 || destination[1] != 30)
      $fatal(1, "unpacked array slice copy mismatch: %0d, %0d",
             destination[0], destination[1]);
    $display("PASS unpacked array slice copy");
    $finish;
  end
endmodule
