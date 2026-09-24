// Annex A permits a generate-block-qualified parameter in constant_primary.
module generate_parameter_width;
  logic [7:0] storage = 8'hac;
  if (1) begin : g
    localparam int BlkLen = 4;
  end
  wire [3:0] selected = storage[7 -: g.BlkLen];
  initial begin
    #1;
    if (selected !== 4'ha) $fatal(1, "generate parameter width failed");
    $display("PASS generate parameter width");
    $finish(0);
  end
endmodule
