module issue2056_wildcard_integral_width;
  int values[*];
  initial begin
    values[32'd8] = 8;
    values[8'b00001000] = 80;
    $display("entries=%0d at_4=%0d", values.num(), values[4'b1000]);
    $finish;
  end
endmodule
