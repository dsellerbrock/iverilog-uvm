`timescale 1ns/1ps
module sv_output_clockvar_variable_driver_controls;
  logic clk = 0, output_var = 0;

  always #5 clk = ~clk;

  clocking cb @(posedge clk);
    output output_var;
  endclocking

  initial begin
    deassign output_var;
    release output_var;
    output_var <= 1'b1;
    @(posedge clk);
    #1;
    if (output_var !== 1'b1)
      $fatal(1, "legal clockvar driver controls failed");
    $display("PASSED");
    $finish;
  end
endmodule
