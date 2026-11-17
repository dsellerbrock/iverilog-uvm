module issue2452_force;
  logic [3:0] m[2][];
  initial begin
    force m[0][0] = 4'h3;
  end
endmodule
