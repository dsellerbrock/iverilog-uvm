// M12B-fr: cbForce/cbRelease fire for Verilog force/release and for
// VPI-initiated forces, on whole signals and on bit-selects.
module force_cb;
  reg [3:0] r;
  wire [3:0] w;

  assign w = 4'b0101;

  initial begin
    $force_monitor(r, w);
    r = 4'b0000;
    #1 force r = 4'b1010;         // Verilog force on a reg
    #1 release r;                 // Verilog release
    #1 force w = 4'b1111;         // Verilog force on a wire
    #1 release w;
    #1 $vpi_force(r, "0110");     // VPI force, whole signal
    #1 $vpi_release(r);
    #1 force r[1] = 1'b1;         // Verilog force on a bit-select
    #1 release r[1];
    #1 $display("done r=%b w=%b", r, w);
  end
endmodule
