class sv_assoc_missing_key_warning_key;
endclass

class sv_assoc_missing_key_warning_holder;
  int missing[int];
endclass

module sv_assoc_missing_key_warning;
  int missing[int];
  real missing_real[int];
  int missing_string[string];
  int missing_object[sv_assoc_missing_key_warning_key];
  sv_assoc_missing_key_warning_key object_key;
  sv_assoc_missing_key_warning_holder holder;
  int defaulted[int] = '{default: 17};
  logic [31:0] bad_index;
  int index;
  int value;

  function automatic int check_allocated(input int key);
    check_allocated = missing.exists(key) ? 0 : 1;
  endfunction

  function automatic int check_defaulted_allocated(input int key);
    check_defaulted_allocated = defaulted.exists(key) ? 0 : 1;
  endfunction

  function automatic int check_real_allocated(input int key);
    check_real_allocated = missing_real.exists(key) ? 0 : 1;
  endfunction

  initial begin
    bad_index = 32'hxxxx_xxxx;
    value = missing[9];
    if (value !== 0 || missing.exists(9))
      $fatal(1, "missing read changed the array or returned the wrong default");

    value = defaulted[9];
    if (value !== 17 || defaulted.exists(9))
      $fatal(1, "user default changed the array or returned the wrong value");

    defaulted[10] += check_defaulted_allocated(10);
    if (defaulted[10] !== 17 || !defaulted.exists(10))
      $fatal(1, "read-modify-write did not preserve the user default");

    value = defaulted[bad_index];
    if (value !== 17 || defaulted.exists(bad_index))
      $fatal(1, "user default did not handle an invalid read");

    value = missing[bad_index];
    if (value !== 0 || missing.exists(bad_index))
      $fatal(1, "invalid read changed the array or returned the wrong default");

    missing[bad_index] = 5;
    if (missing.num() != 0 || missing.exists(bad_index))
      $fatal(1, "invalid write created an associative-array entry");

    missing[10] = 5;
    if (missing[10] !== 5 || !missing.exists(10))
      $fatal(1, "valid write did not create a missing associative-array entry");

    missing[10]++;
    if (missing[10] !== 6 || !missing.exists(10))
      $fatal(1, "read-modify-write did not allocate the associative entry");

    missing[11] += check_allocated(11);
    if (missing[11] !== 0 || !missing.exists(11))
      $fatal(1, "read-modify-write did not allocate before evaluating its RHS");

    index = 20;
    missing[index + 1] += check_allocated(index + 1);
    if (missing[21] !== 0 || !missing.exists(21))
      $fatal(1, "computed-index read-modify-write did not allocate before its RHS");

    missing[13] = missing[13] + 1;
    if (missing[13] !== 1 || !missing.exists(13))
      $fatal(1, "plain assignment did not preserve its missing-key read");

    missing_real[14] += check_real_allocated(14);
    if (missing_real[14] != 0.0 || !missing_real.exists(14))
      $fatal(1, "real read-modify-write did not allocate before its RHS");

    missing_string["new"]++;
    if (missing_string["new"] !== 1 || !missing_string.exists("new"))
      $fatal(1, "string-key read-modify-write did not allocate the associative entry");

    object_key = new;
    missing_object[object_key]++;
    if (missing_object[object_key] !== 1 || !missing_object.exists(object_key))
      $fatal(1, "object-key read-modify-write did not allocate the associative entry");

    holder = new;
    holder.missing[12]++;
    if (holder.missing[12] !== 1 || !holder.missing.exists(12))
      $fatal(1, "class-property read-modify-write did not allocate the associative entry");

    $display("PASSED");
  end
endmodule
