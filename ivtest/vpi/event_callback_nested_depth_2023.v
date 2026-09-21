module test;
  reg trigger = 0;
  wire tap = trigger;
  reg [1:0] value = 2;
  int hits;

  initial begin
    #1;
    fork begin
      @(posedge (value[0] && value[1]));
      hits++;
    end join_none
    #1;
    $arm_nested_callback;
    trigger = 1;
    #1;
    $check_nested_callback;
    if (value != 2 || hits != 1)
      $fatal(1, "nested callback replay failed: value=%0d hits=%0d",
             value, hits);
    $display("PASSED nested callback publication order");
  end
endmodule
