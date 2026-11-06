`timescale 1ns/1ns
module issue829_event_formal_task;
  event done, blast, wait_for;
  bit done_seen, blast_seen, wait_seen;

  task trigger(event ev);
    -> ev;
  endtask

  task automatic trigger_inner(event ev);
    -> ev;
  endtask

  task automatic relay(event ev);
    trigger_inner(ev);
  endtask

  task automatic wait_inner(event ev);
    @ev;
    wait_seen = 1;
  endtask

  initial begin
    fork
      begin
        @done;
        done_seen = 1;
        $display("E2 %0t", $time);
      end
      begin
        @blast;
        blast_seen = 1;
      end
      begin
        #1 trigger(done);
      end
      begin
        #2 relay(blast);
      end
      begin
        wait_inner(wait_for);
      end
      begin
        #3 -> wait_for;
      end
    join

    if (!done_seen || !blast_seen || !wait_seen)
      $fatal(1, "event formal selected the wrong synchronization object");
    $display("PASSED");
  end
endmodule
