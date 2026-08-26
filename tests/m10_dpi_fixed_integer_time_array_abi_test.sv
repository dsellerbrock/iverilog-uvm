// Fixed unpacked arrays of the four-state predefined packed types integer
// and time use canonical svLogicVecVal storage: one word per integer element
// and two low-word-first words per time element. This is a control beside the
// scalar and arbitrary-width packed-element ABI tests.
module m10_dpi_fixed_integer_time_array_abi_test;
  import "DPI-C" context function void c_mutate_fixed_integer_time_arrays(
      inout integer integers[3],
      inout time times[2],
      output int status);

  integer integers[3];
  integer expected_integers[3];
  time times[2];
  time expected_times[2];
  int status;
  int errors = 0;

  initial begin
    integers[0] = '0;
    integers[0][0] = 1'b1;
    integers[0][7] = 1'bx;
    integers[1] = '0;
    integers[1][15] = 1'bz;
    integers[1][31] = 1'b1;
    integers[2] = 32'h89ab_cdef;

    times[0] = '0;
    times[0][1] = 1'b1;
    times[0][35] = 1'bx;
    times[0][63] = 1'bz;
    times[1] = 64'h0123_4567_89ab_cdef;
    times[1][17] = 1'bz;
    times[1][52] = 1'bx;
    status = -1;

    c_mutate_fixed_integer_time_arrays(integers, times, status);

    expected_integers[0] = '0;
    expected_integers[0][2] = 1'bx;
    expected_integers[0][30] = 1'b1;
    expected_integers[1] = 32'h1357_9bdf;
    expected_integers[1][9] = 1'bz;
    expected_integers[2] = '0;
    expected_integers[2][0] = 1'bz;
    expected_integers[2][31] = 1'bx;

    expected_times[0] = '0;
    expected_times[0][0] = 1'bx;
    expected_times[0][32] = 1'bz;
    expected_times[0][62] = 1'b1;
    expected_times[1] = 64'hfedc_ba98_7654_3210;
    expected_times[1][5] = 1'bz;
    expected_times[1][60] = 1'bx;

    if (status != 0) begin
      $display("FAIL fixed integer/time ABI C status=0x%0h", status);
      errors++;
    end
    foreach (integers[i]) begin
      if (integers[i] !== expected_integers[i]) begin
        $display("FAIL fixed integer ABI integers[%0d]=%h expected=%h",
                 i, integers[i], expected_integers[i]);
        errors++;
      end
    end
    foreach (times[i]) begin
      if (times[i] !== expected_times[i]) begin
        $display("FAIL fixed time ABI times[%0d]=%h expected=%h",
                 i, times[i], expected_times[i]);
        errors++;
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_integer_time_array_abi_test");
    $finish;
  end
endmodule
