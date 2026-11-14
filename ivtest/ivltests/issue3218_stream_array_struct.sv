typedef struct { logic [7:0] first, second; } record_t;
module top;
  logic [7:0] items[0:1];
  record_t r;
  logic [31:0] value;
  initial begin
    items[0] = 8'h12; items[1] = 8'h34;
    r.first = 8'h56; r.second = 8'h78;
    value = {>>{items, r}};
    if (value !== 32'h12345678) $fatal(1, "array then struct: %h", value);
    value = {>>{r, items}};
    if (value !== 32'h56781234) $fatal(1, "struct then array: %h", value);
    value = {<<8{items, r}};
    if (value !== 32'h78563412) $fatal(1, "reversed stream: %h", value);
    r.first = 8'hx5; items[1] = 8'hz4;
    value = {>>{items, r}};
    if (value !== 32'h12z4x578) $fatal(1, "four-state stream: %h", value);
    $display("PASSED");
  end
endmodule
