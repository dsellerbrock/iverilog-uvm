module m10_dpi_export_fixed_array_test;
  import "DPI-C" context function int c_check_export_arrays();

  function automatic int sv_mutate_fixed_arrays(
      input int input_values[2],
      inout int inout_values[2],
      output int output_values[2],
      inout logic [7:0] packed_values[2]);
    int errors = 0;

    if (input_values[0] != 11 || input_values[1] != -12)
      errors++;
    if (inout_values[0] != 21 || inout_values[1] != -22)
      errors++;
    if (packed_values[0] !== 8'h12 || packed_values[1] !== 8'h34)
      errors++;

    inout_values[0] = 31;
    inout_values[1] = -32;
    output_values[0] = 41;
    output_values[1] = -42;
    packed_values[0] = 8'hx3;
    packed_values[1] = 8'hz5;
    return errors;
  endfunction
  export "DPI-C" function sv_mutate_fixed_arrays;

  initial begin
    int status;
    status = c_check_export_arrays();
    if (status == 0)
      $display("PASS m10_dpi_export_fixed_array_test");
    else
      $display("FAIL m10_dpi_export_fixed_array_test status=%0d", status);
    $finish;
  end
endmodule
