// A current compiler image is rewritten by the runner to the historical
// %dpi/call/task opcode. When this imported task is disabled, its void C ABI
// has no channel for the IEEE 1800-2017/2023 35.9 acknowledgment and the new
// runtime must diagnose that limitation instead of guessing a status.
`timescale 1ns/1ns

module top;
  import "DPI-C" context task dpi_legacy_disabled_task();

  int export_entered;

  task automatic dpi_legacy_wait();
    export_entered++;
    #100;
    $display("UNEXPECTED: legacy disabled export resumed");
  endtask
  export "DPI-C" task dpi_legacy_wait;

  initial begin
    fork : legacy_disable_case
      begin : victim
        dpi_legacy_disabled_task();
        $display("UNEXPECTED: legacy disabled import returned to SV");
      end
      begin
        wait (export_entered == 1);
        #1;
        disable victim;
      end
    join
    #1;
    $display("UNEXPECTED: legacy disabled void task was accepted");
    $finish(0);
  end
endmodule
