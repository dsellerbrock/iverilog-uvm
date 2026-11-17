module main;
  bit clk, d, x, y, z;
  always @(posedge clk) begin
    x = $past(d);
    #1;
  end
  always @(posedge clk) begin
    y = $rose(d);
    if (d) begin
      repeat (2) #1;
    end
  end
  always @(posedge clk) begin
    z = $stable(d);
    d = #1 x;
  end
endmodule
