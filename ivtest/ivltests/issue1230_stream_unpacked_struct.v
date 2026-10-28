typedef struct {
  logic [7:0] first;
  logic [7:0] second;
} record_t;

module top;
  record_t record_value;
  logic [15:0] packed_value;

  initial begin
    record_value.first = 8'h9a;
    record_value.second = 8'hbc;
    packed_value = {>>{record_value}};
    if (packed_value !== 16'h9abc)
      $fatal(1, "packed=%h", packed_value);
    $display("PASS: %h", packed_value);
    $display("PASSED");
  end
endmodule
