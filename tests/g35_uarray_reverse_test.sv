// G35: unpacked array .reverse()
module g35_uarray_reverse_test;

  initial begin
    int u[5];
    int expected[5];
    int i;
    int ok;

    // Initialize
    for (i = 0; i < 5; i++) u[i] = i + 1;

    // Reverse
    u.reverse();

    // Expected: [5, 4, 3, 2, 1]
    expected[0] = 5; expected[1] = 4; expected[2] = 3;
    expected[3] = 2; expected[4] = 1;

    ok = 1;
    for (i = 0; i < 5; i++) begin
      if (u[i] !== expected[i]) begin
        $display("FAIL: u[%0d]=%0d expected %0d", i, u[i], expected[i]);
        ok = 0;
      end
    end

    if (ok)
      $display("PASS");
    else
      $display("FAIL");
  end

endmodule
