// IEEE 1800 Annex H scalar logic export: pure output storage is initialized
// from the SV declaration default (X for 4-state logic), never from the C
// caller's output object and never from a two-state zero seed.
module m10_dpi_export_output_logic_default_test;
  import "DPI-C" context function int c_check_output_logic_default();

  function automatic logic sv_output_logic_default(
      output logic untouched, output logic observed);
    observed = untouched;
    return observed;
  endfunction
  export "DPI-C" function sv_output_logic_default;

  initial begin
    if (c_check_output_logic_default() == 0)
      $display("PASS m10_dpi_export_output_logic_default_test");
    else
      $display("FAIL m10_dpi_export_output_logic_default_test");
    $finish;
  end
endmodule
