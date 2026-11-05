module sv_packed_indexed_runtime_prefix_bounds;
  logic [1:0][2:0][7:0] w;
  integer o, m;

  initial begin
    w = 48'h0123456789ab;
    o = 0;
    m = 2;
    if (w[o][m+:2] !== 16'hxx67)
      $fatal(1, "w[o][m+:2] = %h, expected xx67", w[o][m+:2]);

    m = 3;
    if (w[o][m] !== 8'hxx)
      $fatal(1, "w[o][m] = %h, expected xx", w[o][m]);

    m = 1;
    if (w[o][m+:2] !== 16'h6789)
      $fatal(1, "w[o][m+:2] = %h, expected 6789", w[o][m+:2]);

    $display("PASSED");
  end
endmodule
