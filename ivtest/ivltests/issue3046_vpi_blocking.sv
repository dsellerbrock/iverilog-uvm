module top;
  event evt;
  task automatic inspect_me;
    -> evt;
    ->> evt;
    -> evt;
    ->> evt;
  endtask
  initial begin
    $check_event_blocking;
    $finish;
  end
endmodule
