module p20_17_pla;
  logic [1:4] in;
  logic [1:2] ao, oo;
  logic [1:4] mem [1:2];
  initial begin
    mem[1] = 4'b1100; mem[2] = 4'b0011;
    $async$and$array(mem, in, ao);
    $async$or$array(mem, in, oo);
    in = 4'b1100; #1 $display("P1 %b %b", ao, oo);
    in = 4'b1111; #1 $display("P2 %b %b", ao, oo);
    in = 4'b0001; #1 $display("P3 %b %b", ao, oo);
    mem[2] = 4'b0001; #1 $display("P4 %b %b", ao, oo);
  end
endmodule
