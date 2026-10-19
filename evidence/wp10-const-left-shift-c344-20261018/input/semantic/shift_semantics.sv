module shift_semantics;
  reg [31:0] din;
  wire [31:0] shifted = din << 5;
  wire [31:0] concat_shifted = {din[26:0], 5'b0};
  wire [26:0] visible_part = din[26:0];
  wire [31:0] visible_result = {visible_part, 5'b0};

  initial begin
    din = 32'h0000_0000; #1 $display("%b %b %b", shifted, concat_shifted, visible_result);
    din = 32'h8000_0001; #1 $display("%b %b %b", shifted, concat_shifted, visible_result);
    din = 32'h0x00_z00f; #1 $display("%b %b %b", shifted, concat_shifted, visible_result);
    din = 32'hzzzz_zzzz; #1 $display("%b %b %b", shifted, concat_shifted, visible_result);
    $finish;
  end
endmodule
