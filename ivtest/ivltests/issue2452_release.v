module issue2452_release;
  logic [3:0] m[2][];
  initial begin
    release m[0][0];
  end
endmodule
