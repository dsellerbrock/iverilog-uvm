module test;
  int values[*];
  logic [3:0] invalid_key;
  int missing;

  initial begin
    missing = values[4'd2];
    if (missing !== 0 || values.num() != 0)
      $fatal(1, "missing 2-state entry read did not return zero without allocation");
    $display("PASS §7.8.6 missing-entry read");

    invalid_key = 4'bx001;
    values[invalid_key] = 17;
    if (values.num() != 0)
      $fatal(1, "write through invalid X/Z key was not ignored");

    $display("PASS §7.8.6 invalid-key behavior");
    $finish;
  end
endmodule
