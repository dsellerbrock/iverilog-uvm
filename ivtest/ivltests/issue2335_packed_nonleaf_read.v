module issue2335_packed_nonleaf_read;
  logic [1:0][2:0][7:0] w;
  integer o, m;

  initial begin
    w = 48'h0123456789ab;
    o = 0;
    m = 2;
    $display("%h", w[o][m+:2]);
    m = 3;
    $display("%h", w[o][m]);
  end
endmodule
