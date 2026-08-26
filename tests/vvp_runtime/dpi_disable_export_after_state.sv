// IEEE 1800-2017/2023 35.9(d): once an imported subroutine enters disabled
// state, that C invocation may not make another call to an SV export.
`timescale 1ns/1ns

module top;
  import "DPI-C" context function void dpi_bad_export_after_disable();

  function void dpi_disable_export_parent();
    disable export_after_victim;
  endfunction

  function int dpi_forbidden_export();
    $display("UNEXPECTED: post-disable export body executed");
    return 17;
  endfunction

  export "DPI-C" function dpi_disable_export_parent;
  export "DPI-C" function dpi_forbidden_export;

  initial begin
    fork : export_after_victim
      begin
        dpi_bad_export_after_disable();
        $display("UNEXPECTED: disabled imported function returned to SystemVerilog");
      end
    join
    #1;
    $display("UNEXPECTED: post-disable export call was accepted");
    $finish(0);
  end
endmodule
