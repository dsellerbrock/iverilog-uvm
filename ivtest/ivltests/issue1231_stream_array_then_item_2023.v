module top;
  logic [7:0] items[0:1];
  logic [7:0] tail;
  logic [23:0] packed_value;
  initial begin
    items[0] = 8'h12;
    items[1] = 8'h34;
    tail = 8'h56;
    packed_value = {>>{items, tail}};
    if (packed_value !== 24'h123456) $fatal(1, "packed=%h", packed_value);
    $display("PASSED");
  end
endmodule
