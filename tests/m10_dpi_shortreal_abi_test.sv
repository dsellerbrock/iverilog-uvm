// IEEE 1800 Annex H maps shortreal to C float in every formal direction and
// as a function result. VVP keeps real values internally as double, so this
// test pins the required float conversion at the DPI boundary.
module m10_dpi_shortreal_abi_test;
  typedef shortreal shortreal_t;
  import "DPI-C" function shortreal_t c_shortreal_all(
      input shortreal_t value, output shortreal_t out_value,
      inout shortreal_t inout_value);

  shortreal_t out_value;
  shortreal_t inout_value = 2.0;
  shortreal_t result;

  initial begin
    result = c_shortreal_all(1.25, out_value, inout_value);
    if (result == 5.25 && out_value == -2.5 && inout_value == 2.5)
      $display("PASS m10_dpi_shortreal_abi_test");
    else
      $display("FAIL shortreal ABI result=%0f out=%0f inout=%0f",
               result, out_value, inout_value);
    $finish;
  end
endmodule
