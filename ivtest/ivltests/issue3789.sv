module issue3789_word(input wire [7:0] p, output wire [7:0] q);
  assign q = p;
endmodule

module issue3789_wide(input wire signed [15:0] p, output wire [15:0] q);
  assign q = p;
endmodule

module issue3789_row(input wire [7:0] p[1:0], output wire [15:0] q);
  assign q = {p[1], p[0]};
endmodule

module issue3789;
  logic [7:0] a[7:4];
  logic signed [95:0] base;
  wire [15:0] up_q, down_q;
  issue3789_word up[0:1](a[base +: 2], up_q);
  issue3789_word down[0:1](a[base -: 2], down_q);

  logic [7:0] cube[1:0][4:3][1:0];
  bit signed [7:0] bits[1:0][4:3][1:0];
  int row;
  logic [3:0] col;
  wire [15:0] prefix_q;
  wire [31:0] bits_q, broadcast_q;
  issue3789_word prefix[1:0](cube[row][col], prefix_q);
  issue3789_wide two_state[1:0](bits[row][col], bits_q);
  issue3789_row broadcast[1:0](cube[row][col], broadcast_q);

  logic [7:0] matrix[-2:0][4:2][-1:0][0:1];
  int first, start, lane;
  wire [31:0] strided_q;
  function automatic int first_index(input int index);
    return index;
  endfunction
  issue3789_row strided[0:1](matrix[first_index(first)][start -: 2][lane], strided_q);

  initial begin
    for (int k = 4; k <= 7; k++) a[k] = k;
    base = 4;
    #1;
    if (up_q !== 16'h0504 || down_q !== 16'h04xx)
      $fatal(1, "base 4 gave +: %h and -: %h", up_q, down_q);
    base = 6;
    #1;
    if (up_q !== 16'h0706 || down_q !== 16'h0605)
      $fatal(1, "base 6 gave +: %h and -: %h", up_q, down_q);
    a[6] = 16;
    #1;
    if (up_q !== 16'h0710 || down_q !== 16'h1005)
      $fatal(1, "selected word update gave +: %h and -: %h", up_q, down_q);
    base = 7;
    #1;
    if (up_q !== 16'hxx07 || down_q !== 16'h0710)
      $fatal(1, "upper boundary gave +: %h and -: %h", up_q, down_q);
    base = 3;
    #1;
    if (up_q !== 16'h04xx || down_q !== 16'hxxxx)
      $fatal(1, "lower boundary gave +: %h and -: %h", up_q, down_q);
    base = (96'sd1 << 70) + 4;
    #1;
    if (up_q !== 16'hxxxx || down_q !== 16'hxxxx)
      $fatal(1, "wide out-of-range base gave +: %h and -: %h", up_q, down_q);
    base = 'x;
    #1;
    if (up_q !== 16'hxxxx || down_q !== 16'hxxxx)
      $fatal(1, "unknown base gave +: %h and -: %h", up_q, down_q);

    cube[0][3][1] = 'h11;
    cube[0][3][0] = 'h22;
    cube[1][3][1] = 'h33;
    cube[1][3][0] = 'h44;
    bits[0][3][1] = -2;
    bits[0][3][0] = 5;
    bits[1][3][1] = -3;
    bits[1][3][0] = 6;
    row = 0;
    col = 3;
    #1;
    if (prefix_q !== 16'h1122 || bits_q !== 32'hfffe0005
        || broadcast_q !== 32'h11221122)
      $fatal(1, "initial prefix gave %h, %h, %h", prefix_q, bits_q, broadcast_q);
    // A flat-only bounds check would read the initialized row [1][3].
    col = 5;
    #1;
    if (prefix_q !== 16'hxxxx || bits_q !== 32'h0 || broadcast_q !== 32'hxxxxxxxx)
      $fatal(1, "invalid second index gave %h, %h, %h", prefix_q, bits_q, broadcast_q);
    col = 'z;
    #1;
    if (prefix_q !== 16'hxxxx || bits_q !== 32'h0 || broadcast_q !== 32'hxxxxxxxx)
      $fatal(1, "unknown second index gave %h, %h, %h", prefix_q, bits_q, broadcast_q);
    row = 1;
    col = 3;
    #1;
    if (prefix_q !== 16'h3344 || bits_q !== 32'hfffd0006
        || broadcast_q !== 32'h33443344)
      $fatal(1, "changed prefix gave %h, %h, %h", prefix_q, bits_q, broadcast_q);
    cube[1][3][1] = 'h55;
    #1;
    if (prefix_q !== 16'h5544 || broadcast_q !== 32'h55445544)
      $fatal(1, "selected row update gave %h, %h", prefix_q, broadcast_q);

    matrix[-1][4][-1][0] = 'h61;
    matrix[-1][4][-1][1] = 'h62;
    matrix[-1][3][-1][0] = 'h71;
    matrix[-1][3][-1][1] = 'h72;
    matrix[0][2][-1][0] = 'h81;
    matrix[0][2][-1][1] = 'h82;
    matrix[-1][3][0][0] = 'h91;
    matrix[-1][3][0][1] = 'h92;
    first = -1;
    start = 4;
    lane = -1;
    #1 if (strided_q !== 32'h61627172)
      $fatal(1, "strided slice gave %h", strided_q);
    start = 5;
    #1 if (strided_q !== 32'hxxxx6162)
      $fatal(1, "strided slice crossed the first dimension: %h", strided_q);
    lane = -2;
    #1 if (strided_q !== 32'hxxxxxxxx)
      $fatal(1, "strided slice used an invalid trailing index: %h", strided_q);
    $display("PASSED");
  end
endmodule
