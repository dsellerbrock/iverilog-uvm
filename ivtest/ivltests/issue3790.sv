module issue3790_child(input wire [7:0] tag, output wire [7:0] q[3:2]);
  assign q[3] = tag;
  assign q[2] = tag ^ 8'h11;
endmodule

module issue3790_variable(input wire [7:0] tag, output var logic [7:0] q[3:2]);
  always @* begin
    q[3] = tag;
    q[2] = tag ^ 8'h11;
  end
endmodule

module issue3790_strength(input wire strong_driver, output wire q[0:0]);
  assign (weak0, weak1) q[0] = strong_driver ? 1'bz : 1'b0;
  assign q[0] = strong_driver ? 1'b1 : 1'bz;
endmodule

module issue3790;
  wire [7:0] result[6:5][0:1];
  issue3790_child c[0:1](16'h3151, result);

  wire [7:0] selected[4:3][1:2][9:8];
  assign selected[3][1][9] = 8'h99;
  issue3790_child row[4:3](16'h2345, selected[4]);

  wire [7:0] strided[5:2][7:6][0:1];
  issue3790_child slice[9:8](16'h6789, strided[4 -: 2][6]);

  wire [7:0] broadcast[4:5];
  issue3790_child shared[3:2](16'h00ff, broadcast);

  wire [7:0] variable_broadcast[4:5];
  issue3790_variable isolated[3:2](16'h00ff, variable_broadcast);

  wire strength_broadcast[0:0];
  issue3790_strength strengths[0:1](2'b01, strength_broadcast);

  wire [7:0] singleton[4:4][2:3];
  issue3790_child alone[7:7](8'hac, singleton);

  reg [7:0] tag = 8'h82;
  wire [7:0] #3 delayed[0:1][2:3];
  issue3790_child delayed_row[1:1](tag, delayed[1]);

  initial begin
    #1;
    if ({result[6][0], result[6][1], result[5][0], result[5][1]}
        !== 32'h31205140)
      $fatal(1, "wrong whole-net split");
    if ({selected[4][1][9], selected[4][1][8], selected[4][2][9], selected[4][2][8]}
        !== 32'h23324554)
      $fatal(1, "wrong selected row split");
    if ({selected[3][1][9], selected[3][1][8], selected[3][2][9], selected[3][2][8]}
        !== 32'h99zzzzzz)
      $fatal(1, "selected row drove neighboring words");
    if ({strided[4][6][0], strided[4][6][1], strided[3][6][0], strided[3][6][1]}
        !== 32'h67768998 || {strided[4][7][0], strided[3][7][1]} !== 16'hzzzz)
      $fatal(1, "wrong strided split");
    if ({broadcast[4], broadcast[5]} !== 16'hxxxx)
      $fatal(1, "broadcast lost resolution");
    if ({variable_broadcast[4], variable_broadcast[5]} !== 16'hxxxx
        || {isolated[3].q[3], isolated[2].q[3]} !== 16'h00ff)
      $fatal(1, "variable output lost resolution or isolation");
    if (strength_broadcast[0] !== 1'b1)
      $fatal(1, "broadcast lost drive strength");
    if ({singleton[4][2], singleton[4][3]} !== 16'hacbd)
      $fatal(1, "singleton instance array did not split");

    #3;
    if ({delayed[1][2], delayed[1][3]} !== 16'h8293)
      $fatal(1, "delayed row was not driven");
    tag = 8'h64;
    #1;
    if ({delayed[1][2], delayed[1][3]} !== 16'h8293)
      $fatal(1, "output bypassed the net delay");
    #3;
    if ({delayed[1][2], delayed[1][3]} !== 16'h6475
        || {delayed[0][2], delayed[0][3]} !== 16'hzzzz)
      $fatal(1, "wrong delayed row or neighbor");
    $display("PASSED");
  end
endmodule
