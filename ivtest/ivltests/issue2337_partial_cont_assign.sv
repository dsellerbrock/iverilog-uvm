module issue2337_partial_cont_assign;
  logic [7:0] partial;
  logic [7:0] disjoint;
  logic [7:0] assigned_z;
  wire [7:0] net_value;

  assign partial[3:0] = 4'b1010;
  assign disjoint[7:6] = 2'b01;
  assign disjoint[3:2] = 2'b10;
  assign assigned_z[3:0] = 4'bzz10;
  assign net_value[3:0] = 4'b1010;

  initial begin
    #1;
    if (partial !== 8'bxxxx1010)
      $fatal(1, "partial variable: %b", partial);
    if (disjoint !== 8'b01xx10xx)
      $fatal(1, "disjoint variable: %b", disjoint);
    if (assigned_z !== 8'bxxxxzz10)
      $fatal(1, "assigned z: %b", assigned_z);
    if (net_value !== 8'bzzzz1010)
      $fatal(1, "net value: %b", net_value);
    $display("PASSED");
  end
endmodule
