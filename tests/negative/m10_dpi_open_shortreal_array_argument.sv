// NEG-DIAG: open shortreal array argument 'values' needs float-array marshaling
// NEG-DIAG-COUNT: 1
// An open shortreal array is legal on an imported DPI subroutine, but its
// element pointers must expose C float rather than the runtime's internal
// double representation. Keep the unimplemented boundary loud.
module m10_dpi_open_shortreal_array_argument;
  import "DPI-C" function int sum_values(input shortreal values[]);
  shortreal values[];
  int result;
  initial begin
    values = new[2];
    result = sum_values(values);
  end
endmodule
