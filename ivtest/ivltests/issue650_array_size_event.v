module top;
  int unsigned AOR[];
  byte stream[$];
  int array_events = 0;
  int queue_events = 0;

  initial begin
    AOR = new[1];
    AOR[0] = 1;
    stream.push_back(8'h01);

    fork
      begin
        @(AOR.size());
        array_events++;
      end
      begin
        @(stream.size());
        queue_events++;
      end
    join_none

    #1;
    AOR[0] = 2;
    stream[0] = 8'h02;
    AOR = new[1];
    #1;
    if (array_events !== 0 || queue_events !== 0)
      $fatal(1, "same-size mutation fired size event: array=%0d queue=%0d",
             array_events, queue_events);

    AOR = new[3];
    stream.push_back(8'h03);
    #1;
    if (array_events !== 1 || queue_events !== 1)
      $fatal(1, "resize did not fire size event once: array=%0d queue=%0d",
             array_events, queue_events);

    $display("PASSED");
    $finish;
  end
endmodule
