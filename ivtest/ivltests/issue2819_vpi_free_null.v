// IEEE 1800-2023 38.38: vpi_release_handle() (vpi_free_object()) returns 0
// on failure; a NULL handle is a failed call, not a reason to abort.
module top;
  logic [7:0] v = 8'h5a;
  initial #1 begin
    $probe;
    $display("DONE");
  end
endmodule
