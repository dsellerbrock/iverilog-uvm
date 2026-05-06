module top;
  event e;
  int hits;

  initial begin
    fork
      begin
        wait (e.triggered);
        hits++;
        $display("wait-triggered woke at %0t", $time);
      end
      begin
        @(e);
        hits++;
        $display("event-control woke at %0t", $time);
      end
    join_none

    #1;
    -> e;
    #1;

    if (hits != 2) begin
      $display("FAIL hits=%0d expected=2", hits);
      $finish;
    end

    -> e;
    if (!e.triggered) begin
      $display("FAIL event.triggered was not set in trigger timeslot");
      $finish;
    end
    #0;
    if (!e.triggered) begin
      $display("FAIL event.triggered did not persist through timeslot");
      $finish;
    end
    #1;
    if (e.triggered) begin
      $display("FAIL event.triggered did not clear after timeslot");
      $finish;
    end

    $display("PASS event_triggered hits=%0d", hits);
    $finish;
  end
endmodule
