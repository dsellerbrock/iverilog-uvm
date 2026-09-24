module local_parameter_width;
  localparam int BlkLen = 4;
  logic [7:0] storage = 8'hac;
  wire [3:0] selected = storage[7 -: BlkLen];
  initial begin
    #1;
    if (selected !== 4'ha) $fatal(1, "local constant width failed");
    $display("PASS local constant width");
    $finish(0);
  end
endmodule
