// M12-3: VPI force/release of a single bit-select (sig[i]) plus
// cbForce/cbRelease callbacks registered on the bit-select handle.
// Previously vpi_put_value(vpiForceFlag) on a bit handle was a loud
// sorry and a force callback could not attach to a bit-select handle.
module top;
  reg [7:0] sig;
  initial begin
    sig = 8'h00;
    #1 $bf_setup;              // register cbForce/cbRelease on sig[3]
    #1 $bf_force3;             // vpi_put_value(sig[3], 1, vpiForceFlag)
    #1 $display("force[3]: sig=%h (expect 08)", sig);
    sig = 8'h00;              // driven low; the forced bit must hold
    #1 $display("hold:     sig=%h (expect 08)", sig);
    #1 $bf_rel3;              // vpi_put_value(sig[3], vpiReleaseFlag)
    #1 sig = 8'h55;
    #1 $display("released: sig=%h (expect 55)", sig);
    #1 $finish(0);
  end
endmodule
