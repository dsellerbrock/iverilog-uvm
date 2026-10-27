`timescale 1ns/1ns
module p32_check_cell(input d, input clk);
  reg notifier = 0;
  specify
    $setup(d, posedge clk, 1, notifier);
  endspecify
endmodule

module p32_tchk;
  reg d = 0, clk = 0;
  p32_check_cell u1(.d(d), .clk(clk));
  initial begin
`ifndef NO_SDF
    $sdf_annotate("p32_tchk.sdf", p32_tchk);
`endif
    #7 d = 1;
    #3 clk = 1;
    #1 $finish;
  end
endmodule
