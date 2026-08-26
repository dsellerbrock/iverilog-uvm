// NEG-DIAG: DPI function result type is not permitted by IEEE 1800 Annex H.8.9
// NEG-DIAG-COUNT: 2
// IEEE 1800-2023 H.8.9 permits integer atom and scalar bit/logic DPI
// function results, but not packed bit/logic vector results. Width one does
// not turn an explicitly packed logic [0:0] into a scalar logic result.
module m10_dpi_packed_function_return;
  typedef bit [7:0] packed_bit_t;
  typedef logic [0:0] packed_logic_t;
  import "DPI-C" function packed_bit_t c_bad_packed_bit_return();
  import "DPI-C" function packed_logic_t c_bad_packed_logic_return();
endmodule
