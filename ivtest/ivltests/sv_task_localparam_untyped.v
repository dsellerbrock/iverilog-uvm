module top;
  task static check_localparam;
    bit [15:0] data;
    int index;
    localparam NUM_BYTES = 5;
    data = NUM_BYTES;
    index = data;
    if (index != 5) $fatal(1, "task localparam mismatch");
  endtask

  initial begin
    check_localparam();
    $display("PASSED");
  end
endmodule
