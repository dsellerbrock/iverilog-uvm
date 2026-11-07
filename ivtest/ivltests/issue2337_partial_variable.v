module issue2337_partial_variable;
  logic [7:0] default_bits;
  logic [7:0] explicit_z;
  logic [7:0] split_bits;
  logic [1:0] low_source, high_source;

  assign default_bits[3:0] = 4'b1010;
  assign explicit_z[3:0] = 4'b1010;
  assign explicit_z[4] = 1'bz;
  assign split_bits[1:0] = low_source;
  assign split_bits[3:2] = high_source;

  initial begin
    low_source = 2'b01;
    high_source = 2'b10;
    #1;
    if (default_bits !== 8'bxxxx1010)
      $fatal(1, "unwritten packed variable bits must retain x");
    if (explicit_z !== 8'bxxxz1010)
      $fatal(1, "explicit z must remain distinct from unwritten bits");
    if (split_bits !== 8'bxxxx1001)
      $fatal(1, "disjoint continuous drivers lost packed variable bits");

    low_source = 2'b10;
    high_source = 2'b01;
    #1;
    if (split_bits !== 8'bxxxx0110)
      $fatal(1, "continuous packed variable drivers did not update");

    $display("PASSED");
    $finish(0);
  end
endmodule
