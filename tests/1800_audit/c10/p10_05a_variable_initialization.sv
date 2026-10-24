module top;
  logic source = 0;
  logic variable_init = source;
  wire net_init = source;
  initial begin
    #1 source = 1;
    #1;
    if (variable_init !== 0 || net_init !== 1)
      $fatal(1, "FAIL variable=%b net=%b", variable_init, net_init);
    $display("PASS variable=%b net=%b", variable_init, net_init);
  end
endmodule
