module sv_packed_indexed_part_nonleaf;
  logic [1:0][2:0][7:0] w;
  integer m;
  logic [15:0] selected;

  initial begin
    w = 48'h0123456789ab;
    m = 2;
    selected = w[0][m+:2];
    if (selected !== 16'hxx67)
      $fatal(1, "w[0][m+:2] = %h, expected xx67", selected);
    $display("%h", selected);
    m = 1;
    selected = w[0][m-:2];
    if (selected !== 16'h89ab)
      $fatal(1, "w[0][m-:2] = %h, expected 89ab", selected);
    $display("PASSED");
    $finish(0);
  end
endmodule
