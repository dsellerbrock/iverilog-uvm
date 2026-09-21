module test;
  reg [1:0] value = 2'b01;
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
      $fatal(1, "late fanout parent atomicity failed, hits=%0d", hits);
    $display("PASSED late fanout parent atomicity with nested callback writes");
  end

  wire tap = value[0];
endmodule
