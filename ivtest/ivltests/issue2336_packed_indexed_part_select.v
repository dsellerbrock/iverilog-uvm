module issue2336_packed_indexed_part_select;
  logic [1:0][2:0][7:0] w;
  integer m;

  initial begin
    w = 48'h0123456789ab;
    m = 2;
    $display("%h", w[0][m+:2]);
  end
endmodule
