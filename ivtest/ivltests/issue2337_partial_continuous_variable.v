module issue2337_partial_continuous_variable;
  logic [3:0] data = 4'b1010;
  logic [7:0] partial;
  logic [7:0] explicit_z;
  logic [7:0] separate;
  logic [7:0] mixed;

  assign partial[3:0] = data;
  assign explicit_z[3:0] = 4'b10z1;
  assign separate[7:4] = 4'b1010;
  assign separate[1:0] = 2'b01;
  assign mixed[3:0] = data;

  initial begin
    mixed[7:4] = 4'hc;
    #1;
    if (partial !== 8'bxxxx1010)
      $fatal(1, "partial variable default: %b", partial);
    if (explicit_z !== 8'bxxxx10z1)
      $fatal(1, "explicit z was not preserved: %b", explicit_z);
    if (separate !== 8'b1010xx01)
      $fatal(1, "independent partial assignments: %b", separate);
    if (mixed !== 8'b11001010)
      $fatal(1, "disjoint procedural and continuous writes: %b", mixed);

    data = 4'b0101;
    #1;
    if (partial !== 8'bxxxx0101 || mixed !== 8'b11000101)
      $fatal(1, "continuous value did not update: partial=%b mixed=%b",
             partial, mixed);

    $display("PASSED");
    $finish;
  end
endmodule
