module top;
  event evs [3:1];

  initial begin
    @evs[2];
    $display("EVENT_WAIT_PASSED");
  end

  initial begin
    #2 -> evs[2];
  end
endmodule
