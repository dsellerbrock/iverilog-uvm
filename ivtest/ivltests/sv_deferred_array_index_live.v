module test;
  logic [7:0] values [3:0];
  logic [127:0] wide_index;
  logic [1:0] narrow_index;

  initial begin
    values[0] = 8'h11;
    values[1] = 8'h22;
    wide_index = 0;
    narrow_index = 1;
    $strobe("wide=%h oob=%h", values[wide_index],
            values[narrow_index[0 +: 3]]);
    wide_index = 1;
  end
endmodule
