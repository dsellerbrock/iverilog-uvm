// Issue #2825 / #1344: vpi_chk_error() reports the error of the previous
// VPI call (IEEE 1800-2023 38.2), and cbPLIError / cbError callbacks run
// when a VPI routine fails (38.36.3).
module top;
  logic [7:0] v = 8'h5a;
  initial #1 begin
    $probe;
    $display("DONE");
  end
endmodule
