module packed_force_overlap;
  logic [1:0][2:0] value = 6'b10_011_1;
  initial begin
    #1;
    $packed_force_overlap_check;
  end
endmodule
