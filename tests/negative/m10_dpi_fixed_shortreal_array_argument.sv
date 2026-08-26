// NEG-DIAG: fixed shortreal array argument 'values' needs float-array marshaling
// NEG-DIAG-COUNT: 1
// Annex H maps shortreal elements to C float. Until direct fixed-array float
// marshaling exists, this legal import form must be rejected without silently
// treating its elements as double.
module m10_dpi_fixed_shortreal_array_argument;
  import "DPI-C" function int sum_values(input shortreal values[2]);
  shortreal values[2];
  int result;
  initial result = sum_values(values);
endmodule
