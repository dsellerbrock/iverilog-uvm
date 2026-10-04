module sv_assert_control_lookup_stress;
  localparam integer N_ASSERTIONS = 1400;
  logic clk = 0;
  integer failures = 0;

  for (genvar g = 0; g < N_ASSERTIONS; g++) begin : generated
    AlwaysFail_A: assert property (@(posedge clk) 1'b0)
      else failures++;
  end

  initial begin
    // A global control must apply to every generated assertion entry.
    $assertoff(0);
    #1 clk = 1;
    #1 clk = 0;
    if (failures != 0)
      $fatal(1, "assertoff failed across generated entries: %0d", failures);

    $asserton(0);
    #1 clk = 1;
    #1 clk = 0;
    if (failures != N_ASSERTIONS)
      $fatal(1, "asserton lost generated entries: %0d/%0d",
             failures, N_ASSERTIONS);

    $display("PASSED");
    $finish;
  end
endmodule
