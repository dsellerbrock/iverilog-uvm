module top;
  reg signal = 0;
  initial begin
    $setup_callbacks;
    #1 signal = 1;
    #3 $check_callbacks;
    $finish;
  end
endmodule
