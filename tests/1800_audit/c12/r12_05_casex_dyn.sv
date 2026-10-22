module m;
  logic [7:0] r=8'b01100110, mask=8'bx0x0x0x0;
  int hit=0;
  initial begin
    casex (r^mask)
      8'b001100xx: hit=1;
      8'b1100xx00: hit=2;
      8'b00xx0011: hit=3;
      8'bxx010100: hit=4;
      default: hit=0;
    endcase
    $display("CX hit=%0d", hit);
  end
endmodule
