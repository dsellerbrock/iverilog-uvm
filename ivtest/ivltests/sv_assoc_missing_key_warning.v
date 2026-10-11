module sv_assoc_missing_key_warning;
  int missing[int];
  int defaulted[int] = '{default: 17};
  logic [31:0] bad_index;
  int value;

  initial begin
    bad_index = 32'hxxxx_xxxx;
    value = missing[9];
    if (value !== 0 || missing.exists(9))
      $fatal(1, "missing read changed the array or returned the wrong default");

    value = defaulted[9];
    if (value !== 17 || defaulted.exists(9))
      $fatal(1, "user default changed the array or returned the wrong value");

    value = defaulted[bad_index];
    if (value !== 17 || defaulted.exists(bad_index))
      $fatal(1, "user default did not handle an invalid read");

    value = missing[bad_index];
    if (value !== 0 || missing.exists(bad_index))
      $fatal(1, "invalid read changed the array or returned the wrong default");

    missing[bad_index] = 5;
    if (missing.num() != 0)
      $fatal(1, "invalid write allocated an associative-array entry");

    missing[10]++;
    if (missing[10] !== 1 || !missing.exists(10))
      $fatal(1, "read-modify-write did not allocate the associative entry");

    $display("PASSED");
  end
endmodule
