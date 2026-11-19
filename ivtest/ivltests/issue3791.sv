module issue3791_net(output wire [7:0] q[3:2], input wire [7:0] seed);
  assign q[3] = seed;
  assign q[2] = seed + 8'd1;
endmodule

module issue3791_var(output var bit [7:0] q[0:1], input wire [7:0] seed);
  always_comb begin
    q[0] = seed;
    q[1] = seed + 8'd2;
  end
endmodule

module issue3791_scalar(output wire signed [3:0] q, input wire [7:0] seed);
  assign q = seed[3:0];
endmodule

module issue3791;
  logic [7:0] a[3:2][5:4][0:1];
  logic [7:0] seed[0:1];
  int word_index = 0;

  // Both elaboration orders must retain the variable and its per-word drivers.
  assign a[2][4][0] = seed[0];
  issue3791_net c[0:1](a[3], seed);
  assign a[2][4][1][7:4] = seed[1][7:4];

  bit [7:0] b[0:2][2:3][1:0];
  bit [7:0] b_copy[2:3][1:0];
  int row_index = 2;
  issue3791_var v[1:0](b[1], seed);

  logic [7:0] s[0:1][1:0];
  issue3791_scalar p[0:1](s[1], seed);

  initial begin
    seed[0] = 8'h18;
    seed[1] = 8'h27;
    a[2][5][word_index] = 8'hf0;
    a[2][4][1][3:0] = 4'ha;
    b_copy = '{'{8'h11, 8'h22}, '{8'h33, 8'h44}};
    b[2] = b_copy;
    b[2][row_index] <= '{8'h55, 8'h66};
    s[0][1] = 8'h43;
    #1;
    if (a[3][5][0] !== 8'h18 || a[3][5][1] !== 8'h19 ||
        a[3][4][0] !== 8'h27 || a[3][4][1] !== 8'h28)
      $fatal(1, "wrong initial net output mapping");
    if (a[2][4][0] !== 8'h18 || a[2][4][1] !== 8'h2a)
      $fatal(1, "wrong initial ordinary continuous drives");
    if (b[1][2][1] !== 8'h18 || b[1][2][0] !== 8'h1a ||
        b[1][3][1] !== 8'h27 || b[1][3][0] !== 8'h29 ||
        b[0][2][1] !== 8'h00 || b[2][3][0] !== 8'h44 ||
        b[2][2][1] !== 8'h55 || b[2][2][0] !== 8'h66)
      $fatal(1, "wrong variable outputs, two-state default, or disjoint copies");
    if (s[1][1] !== 8'hf8 || s[1][0] !== 8'h07 ||
        s[0][1] !== 8'h43 || s[0][0] !== 8'hxx)
      $fatal(1, "wrong initial scalar outputs or disjoint words");

    seed[1] = 8'h3f;
    #1;
    if (a[3][5][0] !== 8'h18 || a[3][5][1] !== 8'h19 ||
        a[3][4][0] !== 8'h3f || a[3][4][1] !== 8'h40 ||
        a[2][4][0] !== 8'h18 || a[2][4][1] !== 8'h3a ||
        a[2][5][0] !== 8'hf0 || a[2][5][1] !== 8'hxx)
      $fatal(1, "wrong updated net outputs or disjoint words");
    if (b[1][2][1] !== 8'h18 || b[1][2][0] !== 8'h1a ||
        b[1][3][1] !== 8'h3f || b[1][3][0] !== 8'h41 ||
        b[0][2][1] !== 8'h00)
      $fatal(1, "wrong updated variable outputs or two-state default");
    if (s[1][1] !== 8'hf8 || s[1][0] !== 8'hff ||
        s[0][1] !== 8'h43 || s[0][0] !== 8'hxx)
      $fatal(1, "wrong updated scalar outputs or disjoint words");
    $display("PASSED");
  end
endmodule
