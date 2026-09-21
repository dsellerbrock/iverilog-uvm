module test;
  reg [1:0] value = 2'b01;
  wire tap = value[0];
  int hits;

  initial begin
    #1;
    fork begin
      @(posedge (value[0] && value[1]));
      hits++;
    end join_none
    #1;
    $arm_atomic_callback;
    value = 2'b10;
    #1;
    if (hits != 1)
      $fatal(1, "parent atomicity or callback pulse failed, hits=%0d", hits);
    $display("PASSED parent atomicity with nested callback writes");
  end
endmodule
