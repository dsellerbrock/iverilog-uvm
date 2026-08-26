// IEEE 1800-2017/2023 35.9(c): a disabled imported function must call
// svAckDisabledState() before its C implementation returns.
`timescale 1ns/1ns

module top;
  import "DPI-C" context function void dpi_bad_unacked_function();

  function void dpi_disable_unacked_parent();
    disable missing_ack_victim;
  endfunction
  export "DPI-C" function dpi_disable_unacked_parent;

  initial begin
    fork : missing_ack_victim
      begin
        dpi_bad_unacked_function();
        $display("UNEXPECTED: disabled imported function returned to SystemVerilog");
      end
    join
    #1;
    $display("UNEXPECTED: missing svAckDisabledState was accepted");
    $finish(0);
  end
endmodule
