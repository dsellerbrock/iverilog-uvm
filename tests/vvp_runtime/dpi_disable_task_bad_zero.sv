// IEEE 1800-2017/2023 35.9(b): after this import is disabled, its C
// implementation must return 1. Returning 0 is a mandatory protocol error.
`timescale 1ns/1ns

module top;
  import "DPI-C" context task dpi_bad_disabled_task();

  int export_entered = 0;

  task dpi_wait_for_disable();
    export_entered++;
    #100;
    $display("UNEXPECTED: disabled exported task resumed");
  endtask
  export "DPI-C" task dpi_wait_for_disable;

  initial begin
    fork : bad_zero_case
      begin : bad_zero_victim
        dpi_bad_disabled_task();
        $display("UNEXPECTED: disabled imported task returned to SystemVerilog");
      end
      begin
        wait (export_entered == 1);
        #1;
        disable bad_zero_victim;
      end
    join
    #1;
    $display("UNEXPECTED: disabled imported task returning 0 was accepted");
    $finish(0);
  end
endmodule
