module stream_widths;
  typedef enum int { BaudRate115200 = 115200 } baud_rate_e;
  baud_rate_e baud_rate;
  int uart_clk_freq_khz;
  bit [27:0] passthrough_filters;
  bit [7:0] uart_freq_arr[8];
  bit [7:0] uart_clk_freq_arr[8];
  bit [7:0] sw_filter_config[4];

  initial begin
    baud_rate = BaudRate115200;
    uart_clk_freq_khz = 24_000;
    passthrough_filters = 28'habc1234;
`ifdef WIDEN
    uart_freq_arr = {<<byte{64'(baud_rate)}};
    uart_clk_freq_arr = {<<byte{64'(uart_clk_freq_khz * 1000)}};
    sw_filter_config = {<<byte{32'(passthrough_filters)}};
`else
    uart_freq_arr = {<<byte{baud_rate}};
    uart_clk_freq_arr = {<<byte{uart_clk_freq_khz * 1000}};
    sw_filter_config = {<<byte{passthrough_filters}};
`endif
    $display("UART=%02h %02h %02h %02h %02h %02h %02h %02h",
             uart_freq_arr[0], uart_freq_arr[1], uart_freq_arr[2], uart_freq_arr[3],
             uart_freq_arr[4], uart_freq_arr[5], uart_freq_arr[6], uart_freq_arr[7]);
    $display("SPI=%02h %02h %02h %02h", sw_filter_config[0], sw_filter_config[1],
             sw_filter_config[2], sw_filter_config[3]);
    if (!(uart_freq_arr[0] == 8'h00 && uart_freq_arr[1] == 8'hc2 &&
          uart_freq_arr[2] == 8'h01 && uart_freq_arr[3] == 8'h00 &&
          uart_freq_arr[4] == 8'h00 && uart_freq_arr[7] == 8'h00)) $fatal(1, "UART bytes");
    if (!(uart_clk_freq_arr[0] == 8'h00 && uart_clk_freq_arr[1] == 8'h36 &&
          uart_clk_freq_arr[2] == 8'h6e && uart_clk_freq_arr[3] == 8'h01 &&
          uart_clk_freq_arr[4] == 8'h00 && uart_clk_freq_arr[7] == 8'h00)) $fatal(1, "clock bytes");
    if (!(sw_filter_config[0] == 8'h34 && sw_filter_config[1] == 8'h12 &&
          sw_filter_config[2] == 8'hbc && sw_filter_config[3] == 8'h0a)) $fatal(1, "SPI bytes");
    $display("PASS: widened streams preserve little-endian byte order");
    $finish;
  end
endmodule
