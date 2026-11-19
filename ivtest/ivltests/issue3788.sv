module issue3788_row(input wire [7:0] p[1:0], output wire [15:0] q);
  assign q = {p[1], p[0]};
endmodule

module issue3788_word(input wire [7:0] p, output wire [7:0] q);
  assign q = p;
endmodule

module issue3788;
  logic [7:0] a[4:3][7:6][2:3];
  wire [31:0] q, slice_q, broadcast_q, invalid_q;
  issue3788_row c[0:1](a[3], q);
  issue3788_row sliced[1:0](a[3][7:6], slice_q);
  issue3788_row broadcast[3:2](a[3][6][2:3], broadcast_q);
  issue3788_row invalid_index[3:2](a[2][6], invalid_q);

  logic [7:0] samples[-2:2];
  wire [15:0] scalar_q;
  issue3788_word words[2:1](samples[-1:0], scalar_q);

  // Selecting one dimension after the slice leaves a gap between rows.
  // The last dimension remains in the selected shape.
  logic [7:0] b[3:4][5:2][7:6][0:1];
  wire [31:0] strided_q;
  issue3788_row strided[9:8](b[4][4 -: 2][6], strided_q);

  initial begin
    a[3][7][2] = 'h12;
    a[3][7][3] = 'h34;
    a[3][6][2] = 'h56;
    a[3][6][3] = 'h78;
    samples[-1] = 'h9a;
    samples[0] = 'hbc;
    b[4][4][6][0] = 'hde;
    b[4][4][6][1] = 'hf0;
    b[4][3][6][0] = 'h11;
    b[4][3][6][1] = 'h22;
    #1;
    if (q !== 32'h12345678 || slice_q !== 32'h12345678)
      $fatal(1, "Prefix and slice split gave %h and %h", q, slice_q);
    if (scalar_q !== 16'h9abc)
      $fatal(1, "Range split to scalar formals gave %h", scalar_q);
    if (broadcast_q !== 32'h56785678)
      $fatal(1, "Selected broadcast gave %h", broadcast_q);
    if (strided_q !== 32'hdef01122)
      $fatal(1, "Strided slice split gave %h", strided_q);
    if (invalid_q !== 32'hxxxxxxxx)
      $fatal(1, "Out-of-bounds prefix gave %h", invalid_q);

    a[3][6][3] = 'h33;
    b[4][3][6][1] = 'h44;
    #1;
    if (q !== 32'h12345633 || slice_q !== 32'h12345633
        || broadcast_q !== 32'h56335633 || strided_q !== 32'hdef01144)
      $fatal(1, "Selected words stopped following the actual");
    $display("PASSED");
  end
endmodule
