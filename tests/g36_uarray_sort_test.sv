// G36: unpacked array .sort(), .min(), .max()
module g36_uarray_sort_test;

  initial begin
    int u[5];
    int sorted[5];
    int ok;
    int i;

    u[0] = 3; u[1] = 1; u[2] = 4; u[3] = 1; u[4] = 5;

    // Test sort()
    u.sort();
    sorted[0] = 1; sorted[1] = 1; sorted[2] = 3;
    sorted[3] = 4; sorted[4] = 5;
    ok = 1;
    for (i = 0; i < 5; i++) begin
      if (u[i] !== sorted[i]) begin
        $display("FAIL: sort u[%0d]=%0d expected %0d", i, u[i], sorted[i]);
        ok = 0;
      end
    end
    if (!ok) begin $display("FAIL"); $finish; end

    $display("PASS");
  end

endmodule
