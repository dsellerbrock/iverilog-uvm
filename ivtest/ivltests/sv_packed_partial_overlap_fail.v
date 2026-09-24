module sv_packed_partial_overlap_fail;
  logic [1:0][1:0] overlap;
  assign overlap[0] = 2'b01;
  assign overlap[0][0] = 1'b0;
endmodule
