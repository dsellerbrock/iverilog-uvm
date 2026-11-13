module issue2933_inner(input .b(w[6:3]), output .q(r[7:4]));
  logic [7:0] w, r;
  initial r = 8'h0f;
endmodule

module issue2933_bits(input .bit_port(w[2]), input .part_port(w[6:4]));
  logic [7:0] w;
  initial w[0] = 1;
endmodule

module issue2933_select_port;
  logic [3:0] b = 4'ha;
  wire [3:0] q;
  issue2933_inner dut(.b(b), .q(q));
  issue2933_bits bits(.bit_port(b[0]), .part_port(b[3:1]));
  initial begin
    #1;
    if (dut.w !== 8'bx1010xxx || q !== 4'h0 ||
        bits.w !== 8'bx101x0x1)
      $fatal(1, "initial: w=%b q=%h", dut.w, q);
    b = 4'h3;
    dut.r = 8'hc0;
    #1;
    if (dut.w !== 8'bx0011xxx || q !== 4'hc ||
        bits.w !== 8'bx001x1x1)
      $fatal(1, "updated: w=%b q=%h", dut.w, q);
    $display("PASS");
  end
endmodule
