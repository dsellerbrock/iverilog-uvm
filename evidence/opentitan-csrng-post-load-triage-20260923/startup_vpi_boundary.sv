`timescale 1ns/1ps

module startup_vpi_boundary;
  wire known = 1'b1;
  wire forwarded = known;
  bit default_zero;
  reg callback_seen;

  initial begin
    if (callback_seen !== 1'b1)
      $fatal(1, "StartOfSim callback did not precede the time-zero process");
    #1;
    if (known !== 1'b1 || forwarded !== 1'b1 || default_zero !== 1'b0)
      $fatal(1, "initial net delivery was lost");
    $display("PASSED");
    $finish(0);
  end
endmodule
