module display_width_repro;
  initial begin
    $display("%3h|%3h|%3h", 32'h5, 32'h100, 32'h1234);
    $display("%02X", 32'h3);
    $display("%3o|%3b", 32'h5, 32'h5);
    $display("%h|%0h", 32'h5, 32'h5);
    $finish;
  end
endmodule
