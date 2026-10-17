module converter_wide_index;
  reg [255:0] data;
  reg signed [127:0] idx;
  reg [7:0] selected;
  reg [7:0] negative;
  integer i;
  integer checksum;

  initial begin
    data = {32{8'hA5}};
    checksum = 0;
    for (i = 0; i < 100000; i = i + 1) begin
      idx = i % 249;
      selected = data[idx +: 8];
      checksum = checksum ^ selected;
    end
    idx = -128'sd1;
    selected = data[idx +: 8];
    negative = selected;
    idx = 0;
    idx[100] = 1'bx;
    selected = data[idx +: 8];
    if (selected !== 8'hxx)
      $fatal(1, "unknown wide index should produce X bits: %h", selected);
    $display("PASS wide converter screen checksum=%08x negative=%h xz=%h",
             checksum, negative, selected);
    $finish;
  end
endmodule
