module unpacked_array_runtime_conditional_test;
  logic select_b;
  wire [7:0] a [2];
  wire [7:0] b [2];
  wire [7:0] result [2];

  assign a = '{8'h12, 8'h34};
  assign b = '{8'hab, 8'hcd};
  assign result = select_b ? b : a;

  initial begin
    select_b = 1'b0;
    #1;
    if (result[0] !== 8'h12 || result[1] !== 8'h34)
      $fatal(1, "false arm of unpacked-array conditional failed");
    select_b = 1'b1;
    #1;
    if (result[0] !== 8'hab || result[1] !== 8'hcd)
      $fatal(1, "true arm of unpacked-array conditional failed");
    $display("PASS: unpacked-array runtime conditional");
  end
endmodule
