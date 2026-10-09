module m10_dpi_shortreal_array_test;
  import "DPI-C" function int c_fixed_input(input shortreal values[2]);
  import "DPI-C" function void c_fixed_output(output shortreal values[2]);
  import "DPI-C" function void c_fixed_inout(inout shortreal values[2]);
  import "DPI-C" function int c_open_input(input shortreal values[]);
  import "DPI-C" function void c_open_output(output shortreal values[]);
  import "DPI-C" function void c_open_inout(inout shortreal values[]);
  import "DPI-C" function int c_open_2d_input(input shortreal values[][]);

  shortreal fixed_input[2];
  shortreal fixed_output[2];
  shortreal fixed_inout[2];
  shortreal open_input[];
  shortreal open_output[];
  shortreal open_inout[];
  shortreal open_2d_input[][];
  int failures = 0;

  initial begin
    fixed_input[0] = 1.25;
    fixed_input[1] = -2.5;
    if (c_fixed_input(fixed_input) != 1) failures++;
    c_fixed_output(fixed_output);
    if (fixed_output[0] != 4.5 || fixed_output[1] != -6.25)
      failures++;
    fixed_inout[0] = 2.0;
    fixed_inout[1] = 3.0;
    c_fixed_inout(fixed_inout);
    if (fixed_inout[0] != 2.25 || fixed_inout[1] != 3.5)
      failures++;

    open_input = new[2];
    open_input[0] = 1.5;
    open_input[1] = -3.0;
    if (c_open_input(open_input) != 1) failures++;
    open_output = new[2];
    c_open_output(open_output);
    if (open_output[0] != 7.5 || open_output[1] != -8.25)
      failures++;
    open_inout = new[2];
    open_inout[0] = 4.0;
    open_inout[1] = 5.0;
    c_open_inout(open_inout);
    if (open_inout[0] != 4.5 || open_inout[1] != 5.75)
      failures++;

    open_2d_input = new[2];
    foreach (open_2d_input[i]) open_2d_input[i] = new[2];
    open_2d_input[0][0] = 1.25;
    open_2d_input[0][1] = 2.5;
    open_2d_input[1][0] = 3.75;
    open_2d_input[1][1] = 5.0;
    if (!c_open_2d_input(open_2d_input)) failures++;

    if (failures == 0) $display("PASS m10_dpi_shortreal_array_test");
    else $display("FAIL m10_dpi_shortreal_array_test (%0d)", failures);
    $finish(0);
  end
endmodule
